//=============================================================================
//===	Copyright (C) 2001-2026 Food and Agriculture Organization of the
//===	United Nations (FAO-UN), United Nations World Food Programme (WFP)
//===	and United Nations Environment Programme (UNEP)
//===
//===	This program is free software; you can redistribute it and/or modify
//===	it under the terms of the GNU General Public License as published by
//===	the Free Software Foundation; either version 2 of the License, or (at
//===	your option) any later version.
//===
//===	This program is distributed in the hope that it will be useful, but
//===	WITHOUT ANY WARRANTY; without even the implied warranty of
//===	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//===	General Public License for more details.
//===
//===	You should have received a copy of the GNU General Public License
//===	along with this program; if not, write to the Free Software
//===	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
//===
//===	Contact: Jeroen Ticheler - FAO - Viale delle Terme di Caracalla 2,
//===	Rome - Italy. email: geonetwork@osgeo.org
//==============================================================================
package org.fao.geonet.kernel.harvest.harvester.simpleurl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.jsonldjava.core.JsonLdOptions;
import com.github.jsonldjava.core.JsonLdProcessor;
import com.github.jsonldjava.utils.JsonUtils;
import org.apache.commons.lang.StringUtils;
import org.fao.geonet.ApplicationContextHolder;
import org.fao.geonet.Logger;
import org.fao.geonet.kernel.GeonetworkDataDirectory;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Prepares a CDIF JSON-LD document for the {@code fromJsonCdif.xsl} conversion.
 *
 * <p>A CDIF record cannot be handed to the XSLT as it arrives. JSON-LD has several
 * equivalent serialisations -- compact, expanded, flattened -- and the downstream
 * {@code org.json.XML} conversion turns each into different XML, so the stylesheet
 * would have to anticipate all of them. Framing against {@code cdif-frame.jsonld}
 * collapses them into one predictable shape; the two repairs afterwards undo damage
 * framing itself causes.
 *
 * <p>This is shared because the preparation, not the transport, is what makes a CDIF
 * record usable: the SimpleUrl harvester fetches records over HTTP and the Directory
 * harvester reads them from disk, but both need the identical three steps before the
 * XSLT sees anything.
 *
 * <p>Every failure mode returns the input unchanged rather than throwing. A record that
 * cannot be framed still converts -- less well -- and that is preferable to dropping it.
 */
public class CdifJsonPreparer {

    /**
     * Substring identifying the CDIF conversion. Both harvesters name their conversion
     * with a full identifier such as {@code schema:iso19115-3.2018:convert/fromJsonCdif},
     * so matching on the stylesheet name covers the variants without enumerating them.
     */
    private static final String CDIF_CONVERSION_MARKER = "fromJsonCdif";

    /**
     * Fields jsonld-java drops during framing even though the frame declares them,
     * generally because of {@code @list} wrappers or type mismatches.
     */
    private static final String[] FIELDS_TO_RECOVER = {
        "schema:creator", "schema:contributor", "schema:publisher",
        "schema:provider", "schema:funding", "schema:distribution",
        "schema:variableMeasured", "schema:dateModified",
        "schema:spatialCoverage", "schema:temporalCoverage"
    };

    private final Logger log;
    private volatile Object cdifFrame = null;

    public CdifJsonPreparer(Logger log) {
        this.log = log;
    }

    /**
     * Whether a conversion identifier names the CDIF JSON-LD conversion, which is what
     * decides if framing runs.
     *
     * <p>Takes the conversion actually selected for the record rather than the harvester's
     * configured one: once a record can be dispatched to a different conversion than the
     * configured one, testing the configured value would frame -- or fail to frame -- on
     * the wrong basis.
     */
    public static boolean isCdifConversion(String conversion) {
        return StringUtils.isNotEmpty(conversion)
            && conversion.contains(CDIF_CONVERSION_MARKER);
    }

    /**
     * Whether a record is worth framing: it must be JSON-LD at all.
     */
    public static boolean isJsonLd(JsonNode record) {
        return record != null && record.has("@context");
    }

    /**
     * Frame a CDIF JSON-LD document, then repair what framing breaks.
     *
     * <p>Framing resolves {@code @list} wrappers, embeds referenced objects inline and
     * produces one consistent structure regardless of the input form. It then introduces
     * nulls for frame properties absent from the source -- which {@code org.json.XML}
     * serialises as the literal string {@code "null"}, breaking things like ISODate
     * parsing downstream -- and silently drops several complex properties, which are
     * copied back from the unframed input.
     *
     * @param jsonRecord the JSON-LD document
     * @param uuid       record identifier, for logging only
     * @return the prepared document, or {@code jsonRecord} unchanged if anything fails
     */
    @SuppressWarnings("unchecked")
    public JsonNode prepare(JsonNode jsonRecord, String uuid) {
        ObjectMapper objectMapper = new ObjectMapper();
        try {
            Object frame = loadCdifFrame();
            if (frame == null) {
                return jsonRecord;
            }

            String jsonString = objectMapper.writeValueAsString(jsonRecord);
            Object input = JsonUtils.fromString(jsonString);

            JsonLdOptions options = new JsonLdOptions();
            Map<String, Object> framed = JsonLdProcessor.frame(input, frame, options);

            // The framing API wraps results in @graph. Extract the main dataset
            // object — not the schema:subjectOf catalog record, which also has
            // @type schema:Dataset and may appear first in the @graph array.
            Object graph = framed.get("@graph");
            if (graph instanceof List) {
                List<?> graphList = (List<?>) graph;
                if (graphList.isEmpty()) {
                    log.warning(String.format(
                        "JSON-LD framing produced empty @graph for record %s — "
                        + "document may not match frame @type. Using unframed document.", uuid));
                    return jsonRecord;
                }

                // Pick the object that has schema:name (the real dataset),
                // not the subjectOf metadata record which lacks it.
                Map<String, Object> mainMap = null;
                for (Object item : graphList) {
                    if (item instanceof Map) {
                        Map<String, Object> candidate = (Map<String, Object>) item;
                        Object name = candidate.get("schema:name");
                        if (name != null && !"".equals(name)) {
                            mainMap = candidate;
                            break;
                        }
                    }
                }
                // Fallback: take the last entry (dataset is typically after subjectOf)
                if (mainMap == null) {
                    Object last = graphList.get(graphList.size() - 1);
                    if (last instanceof Map) {
                        mainMap = (Map<String, Object>) last;
                    }
                }

                if (mainMap != null) {
                    // Preserve @context from the framed output for downstream processing
                    if (framed.containsKey("@context")) {
                        mainMap.put("@context", framed.get("@context"));
                    }
                    removeNulls(mainMap);
                    recoverDroppedFields(mainMap, input, uuid);

                    String result = JsonUtils.toString(mainMap);
                    log.debug("JSON-LD framing applied for CDIF record: " + uuid);
                    return objectMapper.readTree(result);
                }
            }

            // No @graph — properties at top level (single match, older API behavior)
            String result = JsonUtils.toString(framed);
            log.debug("JSON-LD framing applied for CDIF record: " + uuid);
            return objectMapper.readTree(result);
        } catch (Exception e) {
            log.warning(String.format(
                "JSON-LD framing failed for record %s, proceeding with unframed document: %s",
                uuid, e.getMessage()));
            return jsonRecord;
        }
    }

    /**
     * Recursively remove null-valued entries from a Map (and nested Maps/Lists).
     * JSON-LD framing introduces null values for properties declared in the frame
     * but absent in the source data.  org.json.XML.toString() serializes these as
     * the literal string "null", which causes downstream failures such as ISODate
     * parsing errors.
     */
    @SuppressWarnings("unchecked")
    private void removeNulls(Map<String, Object> map) {
        Iterator<Map.Entry<String, Object>> it = map.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<String, Object> entry = it.next();
            Object value = entry.getValue();
            if (value == null) {
                it.remove();
            } else if (value instanceof Map) {
                removeNulls((Map<String, Object>) value);
                if (((Map<String, Object>) value).isEmpty()) {
                    it.remove();
                }
            } else if (value instanceof List) {
                removeNullsFromList((List<Object>) value);
                if (((List<Object>) value).isEmpty()) {
                    it.remove();
                }
            }
        }
    }

    @SuppressWarnings("unchecked")
    private void removeNullsFromList(List<Object> list) {
        Iterator<Object> it = list.iterator();
        while (it.hasNext()) {
            Object item = it.next();
            if (item == null) {
                it.remove();
            } else if (item instanceof Map) {
                removeNulls((Map<String, Object>) item);
                if (((Map<String, Object>) item).isEmpty()) {
                    it.remove();
                }
            } else if (item instanceof List) {
                removeNullsFromList((List<Object>) item);
                if (((List<Object>) item).isEmpty()) {
                    it.remove();
                }
            }
        }
    }

    /**
     * Recover fields that jsonld-java framing drops from the source document.
     * The jsonld-java library sometimes fails to preserve complex properties
     * like schema:creator (which uses @list), schema:distribution, schema:funding,
     * and schema:contributor, even though the frame defines them.
     * This method copies those fields from the original unframed input when
     * they are missing from the framed result.
     */
    @SuppressWarnings("unchecked")
    private void recoverDroppedFields(Map<String, Object> framed, Object originalInput, String uuid) {
        // The originalInput is the parsed JSON-LD — it may be a Map (single object)
        // or a Map with nested structure. Extract the source properties.
        Map<String, Object> source;
        if (originalInput instanceof Map) {
            source = (Map<String, Object>) originalInput;
        } else {
            return;
        }

        for (String field : FIELDS_TO_RECOVER) {
            if (!framed.containsKey(field) || framed.get(field) == null) {
                Object sourceValue = source.get(field);
                if (sourceValue != null) {
                    framed.put(field, sourceValue);
                    log.debug(String.format(
                        "Recovered field '%s' from unframed source for record %s", field, uuid));
                }
            }
        }
    }

    /**
     * Load the CDIF JSON-LD frame document from the schema plugin's convert directory.
     * The frame is cached after first load.
     */
    private Object loadCdifFrame() throws Exception {
        if (cdifFrame != null) {
            return cdifFrame;
        }
        synchronized (this) {
            if (cdifFrame != null) {
                return cdifFrame;
            }
            // Resolve frame file from the schema plugin directory
            Path schemaPluginsDir = ApplicationContextHolder.get()
                .getBean(GeonetworkDataDirectory.class)
                .getSchemaPluginsDir();
            Path framePath = schemaPluginsDir
                .resolve("iso19115-3.2018")
                .resolve("convert")
                .resolve("cdif-frame.jsonld");

            if (!Files.exists(framePath)) {
                log.warning("CDIF frame file not found at " + framePath
                    + " — JSON-LD framing will be skipped.");
                return null;
            }

            try (InputStream is = Files.newInputStream(framePath)) {
                cdifFrame = JsonUtils.fromInputStream(is);
                log.info("Loaded CDIF JSON-LD frame from " + framePath);
            }
            return cdifFrame;
        }
    }
}
