/*
 * Copyright (C) 2001-2026 Food and Agriculture Organization of the
 * United Nations (FAO-UN), United Nations World Food Programme (WFP)
 * and United Nations Environment Programme (UNEP)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 *
 * Contact: Jeroen Ticheler - FAO - Viale delle Terme di Caracalla 2,
 * Rome - Italy. email: geonetwork@osgeo.org
 */
package org.fao.geonet.kernel.harvest.harvester.simpleurl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import org.fao.geonet.ApplicationContextHolder;
import org.fao.geonet.Logger;
import org.fao.geonet.kernel.GeonetworkDataDirectory;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mockito;
import org.springframework.context.support.GenericApplicationContext;

import java.nio.file.Path;
import java.nio.file.Paths;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/**
 * The two decisions that gate CDIF preparation. Both harvesters call these before
 * doing any work, and the Directory harvester passes a value that may be the
 * sentinel "none" rather than a conversion at all.
 */
public class CdifJsonPreparerTest {

    /** Where the preparer looks for cdif-frame.jsonld; surefire runs from the module. */
    private static final Path PLUGIN_DIR =
        Paths.get("..", "schemas", "iso19115-3.2018", "src", "main", "plugin");

    private final ObjectMapper mapper = new ObjectMapper();

    private Logger log;

    @Before
    public void setUpApplicationContext() {
        GeonetworkDataDirectory dataDirectory = Mockito.mock(GeonetworkDataDirectory.class);
        Mockito.when(dataDirectory.getSchemaPluginsDir()).thenReturn(PLUGIN_DIR);
        GenericApplicationContext context = new GenericApplicationContext();
        context.refresh();
        context.getBeanFactory().registerSingleton("gnDataDirectory", dataDirectory);
        ApplicationContextHolder.set(context);
        log = Mockito.mock(Logger.class);
    }

    @After
    public void clearApplicationContext() {
        ApplicationContextHolder.clear();
    }

    @Test
    public void recognisesTheFullConversionIdentifier() {
        assertTrue(CdifJsonPreparer.isCdifConversion(
            "schema:iso19115-3.2018:convert/fromJsonCdif"));
    }

    @Test
    public void recognisesTheBareStylesheetName() {
        assertTrue(CdifJsonPreparer.isCdifConversion("fromJsonCdif"));
    }

    @Test
    public void rejectsOtherConversions() {
        assertFalse(CdifJsonPreparer.isCdifConversion(
            "schema:iso19115-3.2018:convert/fromDDE-any"));
    }

    /**
     * The Directory harvester stores "none" when no import conversion is configured,
     * and passes it through unchanged.
     */
    @Test
    public void rejectsTheNoConversionSentinel() {
        assertFalse(CdifJsonPreparer.isCdifConversion("none"));
    }

    @Test
    public void rejectsNullAndEmpty() {
        assertFalse(CdifJsonPreparer.isCdifConversion(null));
        assertFalse(CdifJsonPreparer.isCdifConversion(""));
    }

    @Test
    public void treatsADocumentWithAContextAsJsonLd() throws Exception {
        assertTrue(CdifJsonPreparer.isJsonLd(mapper.readTree(
            "{\"@context\":\"https://schema.org/\",\"@type\":\"Dataset\"}")));
    }

    @Test
    public void treatsPlainJsonAsNotJsonLd() throws Exception {
        assertFalse(CdifJsonPreparer.isJsonLd(mapper.readTree(
            "{\"title\":\"a record that is not JSON-LD\"}")));
    }

    @Test
    public void treatsNullAsNotJsonLd() {
        assertFalse(CdifJsonPreparer.isJsonLd(null));
    }

    /**
     * Framing is lossy in a way that is invisible: jsonld-java drops a property whose
     * shape the frame does not anticipate, the record still imports, and the field is
     * simply absent. A Place carrying nothing but its geometry is such a shape, and it
     * cost every record using it its bounding box -- the stylesheet maps schema:box
     * correctly, it was never given one.
     */
    @Test
    public void recoversSpatialCoverageThatFramingDrops() throws Exception {
        JsonNode prepared = prepare("{"
            + "\"@context\": {\"schema\": \"http://schema.org/\"},"
            + "\"@type\": [\"schema:Dataset\"],"
            + "\"schema:name\": \"Test\","
            + "\"schema:spatialCoverage\": [{"
            + "  \"@type\": [\"schema:Place\"],"
            + "  \"schema:geo\": {\"@type\": [\"schema:GeoShape\"],"
            + "                   \"schema:box\": \"18.1609 73.499 53.5585 135.08\"}}]"
            + "}");

        assertTrue("spatialCoverage was dropped by framing and not recovered",
            prepared.has("schema:spatialCoverage"));
        assertEquals("18.1609 73.499 53.5585 135.08",
            prepared.at("/schema:spatialCoverage/0/schema:geo/schema:box").asText());
    }

    /**
     * The OWL-Time interval the DDE profiles use, dropped for the same reason.
     */
    @Test
    public void recoversTemporalCoverageThatFramingDrops() throws Exception {
        JsonNode prepared = prepare("{"
            + "\"@context\": {\"schema\": \"http://schema.org/\","
            + "               \"time\": \"http://www.w3.org/2006/time#\"},"
            + "\"@type\": [\"schema:Dataset\"],"
            + "\"schema:name\": \"Test\","
            + "\"schema:temporalCoverage\": [{"
            + "  \"@type\": [\"time:ProperInterval\"],"
            + "  \"time:hasBeginning\": {\"@type\": [\"time:Instant\"],"
            + "    \"time:inTimePosition\": {\"@type\": [\"time:TimePosition\"],"
            + "      \"time:numericPosition\": 2015}}}]"
            + "}");

        assertTrue("temporalCoverage was dropped by framing and not recovered",
            prepared.has("schema:temporalCoverage"));
    }

    private JsonNode prepare(String json) throws Exception {
        return new CdifJsonPreparer(log).prepare(mapper.readTree(json), "test-record");
    }
}
