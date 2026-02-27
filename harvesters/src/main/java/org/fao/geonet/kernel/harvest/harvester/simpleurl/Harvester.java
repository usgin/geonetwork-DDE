//=============================================================================
//===	Copyright (C) 2001-2025 Food and Agriculture Organization of the
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
import com.google.common.annotations.VisibleForTesting;
import com.google.common.io.CharStreams;
import jeeves.server.context.ServiceContext;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.http.client.methods.HttpGet;
import org.fao.geonet.ApplicationContextHolder;
import org.fao.geonet.Logger;
import org.fao.geonet.exceptions.BadParameterEx;
import org.fao.geonet.kernel.GeonetworkDataDirectory;
import org.fao.geonet.kernel.harvest.harvester.HarvestError;
import org.fao.geonet.kernel.harvest.harvester.HarvestResult;
import org.fao.geonet.kernel.harvest.harvester.IHarvester;
import org.fao.geonet.lib.Lib;
import org.fao.geonet.util.Sha1Encoder;
import org.fao.geonet.utils.GeonetHttpRequestFactory;
import org.fao.geonet.utils.Log;
import org.fao.geonet.utils.Xml;
import org.jdom.Attribute;
import org.jdom.Element;
import org.jdom.JDOMException;
import org.jdom.Text;
import org.json.JSONObject;
import org.json.XML;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.client.ClientHttpResponse;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.fao.geonet.utils.Xml.isRDFLike;
import static org.fao.geonet.utils.Xml.isXMLLike;

/**
 * Harvest metadata from a URL source.
 * <p>
 * The URL source can be a simple JSON, XML or RDF file or
 * an URL with indication on how to pass paging information.
 * <p>
 * This harvester has been tested with CKAN, OpenDataSoft,
 * OGC API Records, DCAT feeds.
 */
class Harvester implements IHarvester<HarvestResult> {
    public static final String LOGGER_NAME = "geonetwork.harvester.simpleurl";

    private final AtomicBoolean cancelMonitor;
    private Logger log;
    private final SimpleUrlParams params;
    private final ServiceContext context;

    @Autowired
    GeonetHttpRequestFactory requestFactory;

    /**
     * Contains a list of accumulated errors during the executing of this harvest.
     */
    private final List<HarvestError> errors;

    /**
     * Cached JSON-LD frame for CDIF record normalization.
     * Loaded on first use from the schema plugin's convert directory.
     */
    private volatile Object cdifFrame = null;

    public Harvester(AtomicBoolean cancelMonitor, Logger log, ServiceContext context, SimpleUrlParams params, List<HarvestError> errors) {
        this.cancelMonitor = cancelMonitor;
        this.log = log;
        this.context = context;
        this.params = params;
        this.errors = errors;
    }

    public HarvestResult harvest(Logger log) throws Exception {
        this.log = log;
        log.debug("Retrieving from harvester: " + params.getName());

        requestFactory = context.getBean(GeonetHttpRequestFactory.class);

        String[] urlList = params.url.split("\n");
        boolean error = false;
        Aligner aligner = new Aligner(cancelMonitor, context, params, log);
        Set<String> listOfUuids = new HashSet<>();

        for (String url : urlList) {
            log.debug("Loading URL: " + url);
            String content = retrieveUrl(url);
            if (cancelMonitor.get()) {
                return new HarvestResult();
            }
            log.debug("Response is: " + content);

            int numberOfRecordsToHarvest = -1;

            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode jsonObj = null;
            Element xmlObj = null;
            SimpleUrlResourceType type;

            if (isRDFLike(content)) type = SimpleUrlResourceType.RDFXML;
            else if (isXMLLike(content)) type = SimpleUrlResourceType.XML;
            else type = SimpleUrlResourceType.JSON;

            // Sitemap processing: if isSitemap is explicitly enabled,
            // parse the sitemap and fetch each URL as an individual record.
            if ("true".equals(params.isSitemap)) {
                log.info("Processing URL as sitemap: " + url);
                try {
                    // Auto-detect: if content is JSON (not XML), treat as single record
                    if (!isXMLLike(content)) {
                        log.info("URL returned JSON content — processing as single CDIF record: " + url);
                        Map<String, Element> singleRecord = new HashMap<>();
                        JsonNode recordJson = objectMapper.readTree(content);
                        collectSingleJsonRecord(recordJson, singleRecord, url);
                        aligner.align(singleRecord, errors);
                        listOfUuids.addAll(singleRecord.keySet());
                        log.info("Processed single JSON-LD record from: " + url);
                        continue;
                    }
                    // Otherwise process as sitemap XML
                    List<String> sitemapUrls = extractUrlsFromSitemap(content);
                    log.info("Found " + sitemapUrls.size() + " URLs in sitemap.");
                    Map<String, Element> allSitemapUuids = new HashMap<>();

                    for (String recordUrl : sitemapUrls) {
                        if (cancelMonitor.get()) {
                            return new HarvestResult();
                        }
                        try {
                            log.debug("Fetching sitemap entry: " + recordUrl);
                            String recordContent = retrieveUrl(recordUrl);
                            JsonNode recordJson = objectMapper.readTree(recordContent);
                            collectSingleJsonRecord(recordJson, allSitemapUuids, recordUrl);
                        } catch (Exception e) {
                            errors.add(new HarvestError(this.context, e));
                            log.error(String.format("Failed to process sitemap entry %s. Error is: %s",
                                recordUrl, e.getMessage()));
                        }
                    }

                    aligner.align(allSitemapUuids, errors);
                    aligner.cleanupRemovedRecords(allSitemapUuids.keySet());
                    log.info("Total records processed from sitemap: " + allSitemapUuids.size());
                } catch (Exception e) {
                    error = true;
                    errors.add(new HarvestError(context, e));
                    log.error("Failed to process sitemap: " + e.getMessage());
                }
                continue;
            }

            if (type == SimpleUrlResourceType.XML
                || type == SimpleUrlResourceType.RDFXML) {
                xmlObj = Xml.loadString(content, false);
            } else {
                jsonObj = objectMapper.readTree(content);
            }

            // TODO: Add page support for Hydra in RDFXML feeds ?
            if (StringUtils.isNotEmpty(params.numberOfRecordPath)) {
                try {
                    if (type == SimpleUrlResourceType.XML) {
                        Object element = Xml.selectSingle(xmlObj, params.numberOfRecordPath, xmlObj.getAdditionalNamespaces());
                        if (element != null) {
                            String s = getXmlElementTextValue(element);
                            numberOfRecordsToHarvest = Integer.parseInt(s);
                        }
                    } else if (type == SimpleUrlResourceType.JSON) {
                        numberOfRecordsToHarvest = jsonObj.at(params.numberOfRecordPath).asInt();
                    }
                    log.debug("Number of records to harvest: " + numberOfRecordsToHarvest);
                } catch (Exception e) {
                    errors.add(new HarvestError(context, e));
                    log.error(String.format("Failed to extract total in response at path %s. Error is: %s",
                        params.numberOfRecordPath, e.getMessage()));
                }
            }
            try {
                List<String> listOfUrlForPages = buildListOfUrl(params, numberOfRecordsToHarvest);
                for (int i = 0; i < listOfUrlForPages.size(); i++) {
                    if (i != 0) {
                        content = retrieveUrl(listOfUrlForPages.get(i));
                        if (type == SimpleUrlResourceType.XML) {
                            xmlObj = Xml.loadString(content, false);
                        } else {
                            jsonObj = objectMapper.readTree(content);
                        }
                    }
                    if (StringUtils.isNotEmpty(params.loopElement)
                        || type == SimpleUrlResourceType.RDFXML) {
                        Map<String, Element> uuids = new HashMap<>();
                        try {
                            if (type == SimpleUrlResourceType.XML) {
                                collectRecordsFromXml(xmlObj, uuids, aligner);
                            } else if (type == SimpleUrlResourceType.RDFXML) {
                                collectRecordsFromRdf(xmlObj, uuids, aligner);
                            } else if (type == SimpleUrlResourceType.JSON) {
                                collectRecordsFromJson(jsonObj, uuids, aligner);
                            }
                            aligner.align(uuids, errors);
                            listOfUuids.addAll(uuids.keySet());
                        } catch (Exception e) {
                            errors.add(new HarvestError(this.context, e));
                            log.error(String.format("Failed to collect record in response at path %s. Error is: %s",
                                params.loopElement, e.getMessage()));
                        }
                    }
                }
            } catch (Exception t) {
                error = true;
                log.error("Unknown error trying to harvest");
                log.error(t.getMessage());
                log.error(t);
                errors.add(new HarvestError(context, t));
            } catch (Throwable t) {
                error = true;
                log.fatal("Something unknown and terrible happened while harvesting");
                log.fatal(t.getMessage());
                errors.add(new HarvestError(context, t));
            }

            log.info("Total records processed in all searches :" + listOfUuids.size());
            if (error) {
                log.warning("Due to previous errors the align process has not been called");
            }
        }
        aligner.cleanupRemovedRecords(listOfUuids);
        return aligner.getResult();
    }

    private void collectRecordsFromJson(JsonNode jsonObj,
                                        Map<String, Element> uuids,
                                        Aligner aligner) {
        JsonNode nodes = jsonObj.at(params.loopElement);
        log.debug(String.format("%d records found in JSON response.", nodes.size()));

        nodes.forEach(jsonRecord -> {
            String uuid = null;
            try {
                uuid = this.extractUuidFromIdentifier(jsonRecord.at(params.recordIdPath).asText());
            } catch (Exception e) {
                log.error(String.format("Failed to collect record UUID at path %s. Error is: %s",
                    params.recordIdPath, e.getMessage()));
            }
            String apiUrlPath = params.url.split("\\?")[0];
            try {
                URL apiUrl = new URL(apiUrlPath);
                String nodeUrl = new StringBuilder(apiUrl.getProtocol()).append("://").append(apiUrl.getAuthority()).toString();
                Element xml = convertJsonRecordToXml(jsonRecord, uuid, apiUrlPath, nodeUrl);
                uuids.put(uuid, xml);
            } catch (MalformedURLException e) {
                errors.add(new HarvestError(this.context, e));
                log.warning(String.format("Failed to parse JSON source URL. Error is: %s", e.getMessage()));
            }
        });
    }

    private void collectRecordsFromRdf(Element xmlObj,
                                       Map<String, Element> uuids,
                                       Aligner aligner) {
        Map<String, Element> rdfNodes = null;
        try {
            rdfNodes = RDFUtils.getAllUuids(xmlObj);
        } catch (Exception e) {
            errors.add(new HarvestError(this.context, e));
            log.error(String.format("Failed to find records in RDF graph. Error is: %s",
                e.getMessage()));
        }
        if (rdfNodes != null) {
            log.debug(String.format("%d records found in RDFXML response.", rdfNodes.size()));

            // TODO: Add param
            boolean hashUuid = true;
            rdfNodes.forEach((uuid, xml) -> {
                if (hashUuid) {
                    uuid = Sha1Encoder.encodeString(uuid);
                }
                Element output = applyConversion(xml, uuid);
                if (output != null) {
                    uuids.put(uuid, output);
                }
            });
        }
    }

    private void collectRecordsFromXml(Element xmlObj,
                                       Map<String, Element> uuids,
                                       Aligner aligner) {
        List<Element> xmlNodes = null;
        try {
            xmlNodes = Xml.selectNodes(xmlObj, params.loopElement, xmlObj.getAdditionalNamespaces());
        } catch (JDOMException e) {
            log.error(String.format("Failed to query records using %s. Error is: %s",
                params.loopElement, e.getMessage()));
        }

        if (xmlNodes != null) {
            log.debug(String.format("%d records found in XML response.", xmlNodes.size()));

            xmlNodes.forEach(element -> {
                try {
                    String uuid = getXmlElementTextValue(Xml.selectSingle(element, params.recordIdPath, element.getAdditionalNamespaces()));
                    uuids.put(uuid, applyConversion(element, null));
                } catch (JDOMException e) {
                    log.error(String.format("Failed to extract UUID for record. Error is %s.",
                        e.getMessage()));
                    aligner.getResult().badFormat++;
                    aligner.getResult().totalMetadata++;
                }
            });
        }
    }

    private String getXmlElementTextValue(Object element) {
        String s = null;
        if (element instanceof Text) {
            s = ((Text) element).getTextNormalize();
        } else if (element instanceof Attribute) {
            s = ((Attribute) element).getValue();
        } else if (element instanceof String) {
            s = (String) element;
        }
        return s;
    }

    private String extractUuidFromIdentifier(final String identifier) {
        String uuid = identifier;
        if (Lib.net.isUrlValid(uuid)) {
            uuid = uuid.replaceFirst(".*/([^/?]+).*", "$1");
        }
        return uuid;
    }

    @VisibleForTesting
    protected List<String> buildListOfUrl(SimpleUrlParams params, int numberOfRecordsToHarvest) {
        List<String> urlList = new ArrayList<>();
        if (StringUtils.isEmpty(params.pageSizeParam)) {
            urlList.add(params.url);
            return urlList;
        }

        int numberOfRecordsPerPage = -1;
        final String pageSizeParamValue = params.url.replaceAll(".*[?&]" + params.pageSizeParam + "=([0-9]+).*", "$1");
        if (StringUtils.isNumeric(pageSizeParamValue)) {
            numberOfRecordsPerPage = Integer.parseInt(pageSizeParamValue);
        } else {
            log.warning(String.format(
                "Page size param '%s' not found or is not a numeric in URL '%s'. Can't build a list of pages.",
                params.pageSizeParam, params.url));
            urlList.add(params.url);
            return urlList;
        }

        final String pageFromParamValue = params.url.replaceAll(".*[?&]" + params.pageFromParam + "=([0-9]+).*", "$1");
        boolean startAtZero;
        if (StringUtils.isNumeric(pageFromParamValue)) {
            startAtZero = Integer.parseInt(pageFromParamValue) == 0;
        } else {
            log.warning(String.format(
                "Page from param '%s' not found or is not a numeric in URL '%s'. Can't build a list of pages.",
                params.pageFromParam, params.url));
            urlList.add(params.url);
            return urlList;
        }


        int numberOfPages = Math.abs((numberOfRecordsToHarvest + (startAtZero ? -1 : 0)) / numberOfRecordsPerPage) + 1;

        for (int i = 0; i < numberOfPages; i++) {
            int from = i * numberOfRecordsPerPage + (startAtZero ? 0 : 1);
            int size = i == numberOfPages - 1 ? // Last page
                numberOfRecordsToHarvest - from + (startAtZero ? 0 : 1) :
                numberOfRecordsPerPage;
            String url = params.url
                .replaceAll(params.pageFromParam + "=[0-9]+", params.pageFromParam + "=" + from)
                .replaceAll(params.pageSizeParam + "=[0-9]+", params.pageSizeParam + "=" + size);
            urlList.add(url);
        }

        return urlList;
    }

    private Element convertJsonRecordToXml(JsonNode jsonRecord, String uuid, String apiUrl, String nodeUrl) {
        ObjectMapper objectMapper = new ObjectMapper();
        try {
            // Apply JSON-LD framing for CDIF records to normalize structure
            if (isCdifConversion() && jsonRecord.has("@context")) {
                jsonRecord = frameJsonLd(jsonRecord, uuid);
            }

            String recordAsXml = XML.toString(
                new JSONObject(
                    objectMapper.writeValueAsString(jsonRecord)), "record");
            recordAsXml = Xml.stripNonValidXMLCharacters(recordAsXml)
                .replace("<@", "<")
                .replace("</@", "</")
                .replaceAll("(:|%)(?![^<>]*<)", "_"); // this removes colon and % from property names
            Element recordAsElement = Xml.loadString(recordAsXml, false);
            recordAsElement.addContent(new Element("uuid").setText(uuid));
            recordAsElement.addContent(new Element("apiUrl").setText(apiUrl));
            recordAsElement.addContent(new Element("nodeUrl").setText(nodeUrl));
            return applyConversion(recordAsElement, uuid);
        } catch (Exception e) {
            log.error(String.format("Failed to convert JSON record %s to XML. Error is: %s",
                uuid, e.getMessage()));
        }
        return null;
    }

    /**
     * Check if the harvester is configured for CDIF JSON-LD conversion.
     */
    private boolean isCdifConversion() {
        return StringUtils.isNotEmpty(params.toISOConversion)
            && params.toISOConversion.contains("fromJsonCdif");
    }

    /**
     * Apply JSON-LD framing to normalize a CDIF JSON-LD document.
     * Framing resolves @list wrappers, embeds referenced objects inline,
     * and ensures a consistent structure regardless of the input JSON-LD form
     * (compact, expanded, flattened). This makes the downstream org.json.XML
     * conversion produce predictable XML for the fromJsonCdif.xsl XSLT.
     *
     * @param jsonRecord the JSON-LD document as a Jackson JsonNode
     * @param uuid       the record identifier (for logging)
     * @return the framed document, or the original if framing fails
     */
    @SuppressWarnings("unchecked")
    private JsonNode frameJsonLd(JsonNode jsonRecord, String uuid) {
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

            // The framing API wraps results in @graph. Extract the main object.
            Object graph = framed.get("@graph");
            if (graph instanceof List) {
                List<?> graphList = (List<?>) graph;
                if (graphList.isEmpty()) {
                    log.warning(String.format(
                        "JSON-LD framing produced empty @graph for record %s — "
                        + "document may not match frame @type. Using unframed document.", uuid));
                    return jsonRecord;
                }
                Object mainObj = graphList.get(0);
                if (mainObj instanceof Map) {
                    Map<String, Object> mainMap = (Map<String, Object>) mainObj;
                    // Preserve @context from the framed output for downstream processing
                    if (framed.containsKey("@context")) {
                        mainMap.put("@context", framed.get("@context"));
                    }
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

    private Element applyConversion(Element input, String uuid) {
        if (StringUtils.isNotEmpty(params.toISOConversion)) {
            Path xslPath = ApplicationContextHolder.get().getBean(GeonetworkDataDirectory.class)
                .getXsltConversion(params.toISOConversion);
            try {
                HashMap<String, Object> xslParams = new HashMap<>();
                if (uuid != null) {
                    xslParams.put("uuid", uuid);
                }
                return Xml.transform(input, xslPath, xslParams);
            } catch (Exception e) {
                errors.add(new HarvestError(this.context, e));
                log.error(String.format("Failed to apply conversion %s to record %s. Error is: %s",
                    params.toISOConversion, uuid, e.getMessage()));
                return null;
            }
        } else {
            return input;
        }
    }

    /**
     * Read the response of the URL.
     */
    private String retrieveUrl(String url) throws Exception {
        if (!Lib.net.isUrlValid(url))
            throw new BadParameterEx("Invalid URL", url);
        HttpGet httpMethod = null;
        ClientHttpResponse httpResponse = null;

        try {
            httpMethod = new HttpGet(createUrl(url));
            httpResponse = requestFactory.execute(httpMethod);
            int status = httpResponse.getRawStatusCode();
            Log.debug(LOGGER_NAME, "Request status code: " + status);
            return CharStreams.toString(new InputStreamReader(httpResponse.getBody()));
        } finally {
            if (httpMethod != null) {
                httpMethod.releaseConnection();
            }
            IOUtils.closeQuietly(httpResponse);
        }
    }

    private URI createUrl(String jsonUrl) throws URISyntaxException {
        return new URI(jsonUrl);
    }

    /**
     * Check if the content looks like a sitemap XML document.
     */
    private boolean isSitemapContent(String content) {
        if (content == null) return false;
        String trimmed = content.trim();
        return trimmed.contains("<urlset") || trimmed.contains("<sitemapindex");
    }

    /**
     * Extract all loc URLs from a sitemap XML document.
     */
    private List<String> extractUrlsFromSitemap(String content) throws Exception {
        List<String> urls = new ArrayList<>();
        Element sitemapRoot = Xml.loadString(content, false);

        // Direct JDOM child traversal — avoids XPath issues with detached elements.
        // Sitemap elements may be in namespace http://www.sitemaps.org/schemas/sitemap/0.9
        // or in no namespace, so we check children by local name.
        for (Object child : sitemapRoot.getChildren()) {
            if (child instanceof Element) {
                Element urlElement = (Element) child;
                if ("url".equals(urlElement.getName())) {
                    for (Object locChild : urlElement.getChildren()) {
                        if (locChild instanceof Element) {
                            Element locElement = (Element) locChild;
                            if ("loc".equals(locElement.getName())) {
                                String locText = locElement.getTextTrim();
                                if (StringUtils.isNotEmpty(locText)) {
                                    urls.add(locText);
                                }
                            }
                        }
                    }
                }
            }
        }
        return urls;
    }

    /**
     * Process a single JSON object as one record (not an array).
     * Used for sitemap harvesting where each URL returns a single JSON-LD document.
     */
    private void collectSingleJsonRecord(JsonNode jsonRecord,
                                          Map<String, Element> uuids,
                                          String sourceUrl) {
        String uuid = null;
        try {
            if (StringUtils.isNotEmpty(params.recordIdPath)) {
                JsonNode idNode = jsonRecord.at(params.recordIdPath);
                if (!idNode.isMissingNode() && !idNode.isNull()) {
                    uuid = this.extractUuidFromIdentifier(idNode.asText());
                }
            }
            if (StringUtils.isEmpty(uuid)) {
                uuid = Sha1Encoder.encodeString(sourceUrl);
            }

            URL apiUrl = new URL(sourceUrl);
            String nodeUrl = apiUrl.getProtocol() + "://" + apiUrl.getAuthority();
            Element xml = convertJsonRecordToXml(jsonRecord, uuid, sourceUrl, nodeUrl);
            if (xml != null) {
                uuids.put(uuid, xml);
            }
        } catch (Exception e) {
            errors.add(new HarvestError(this.context, e));
            log.error(String.format("Failed to process single JSON record from %s. Error is: %s",
                sourceUrl, e.getMessage()));
        }
    }

    public List<HarvestError> getErrors() {
        return errors;
    }
}
