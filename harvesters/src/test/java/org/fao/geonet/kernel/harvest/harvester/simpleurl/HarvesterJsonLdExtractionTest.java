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
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/**
 * Extraction of embedded JSON-LD from HTML landing pages.
 *
 * <p>A CDIF sitemap commonly lists landing pages that carry their metadata in a
 * script block rather than listing .json documents, so the harvester has to find it.
 */
public class HarvesterJsonLdExtractionTest {

    private final ObjectMapper mapper = new ObjectMapper();

    private static String page(String... scripts) {
        StringBuilder sb = new StringBuilder("<!DOCTYPE html><html><head><title>t</title>");
        for (String s : scripts) {
            sb.append(s);
        }
        return sb.append("</head><body><h1>Landing page</h1></body></html>").toString();
    }

    private static String ld(String json) {
        return "<script type=\"application/ld+json\">" + json + "</script>";
    }

    @Test
    public void extractsASingleDatasetBlock() {
        String html = page(ld("{\"@context\":\"https://schema.org/\","
            + "\"@type\":\"Dataset\",\"name\":\"Arizona Lithostratigraphy\"}"));

        JsonNode out = Harvester.extractJsonLdFromHtml(html, mapper);

        assertNotNull(out);
        assertEquals("Arizona Lithostratigraphy", out.get("name").asText());
    }

    @Test
    public void keepsTheContextSoFramingStillRuns() {
        // frameJsonLd is only reached when the record has an @context, so returning
        // the whole script block rather than the matched node is load-bearing.
        String html = page(ld("{\"@context\":{\"schema\":\"https://schema.org/\"},"
            + "\"@type\":\"schema:Dataset\",\"schema:name\":\"x\"}"));

        JsonNode out = Harvester.extractJsonLdFromHtml(html, mapper);

        assertNotNull(out);
        assertTrue("@context must survive extraction", out.has("@context"));
    }

    @Test
    public void prefersTheDatasetWhenSeveralBlocksArePresent() {
        // The common science-on-schema.org shape: navigation markup beside the Dataset.
        String html = page(
            ld("{\"@context\":\"https://schema.org/\",\"@type\":\"BreadcrumbList\"}"),
            ld("{\"@context\":\"https://schema.org/\",\"@type\":\"Organization\",\"name\":\"AZGS\"}"),
            ld("{\"@context\":\"https://schema.org/\",\"@type\":\"Dataset\",\"name\":\"the one\"}"));

        JsonNode out = Harvester.extractJsonLdFromHtml(html, mapper);

        assertNotNull(out);
        assertEquals("the one", out.get("name").asText());
    }

    @Test
    public void findsADatasetInsideAnAtGraph() {
        String html = page(ld("{\"@context\":\"https://schema.org/\",\"@graph\":["
            + "{\"@type\":\"Organization\",\"name\":\"AZGS\"},"
            + "{\"@type\":\"Dataset\",\"name\":\"graphed\"}]}"));

        JsonNode out = Harvester.extractJsonLdFromHtml(html, mapper);

        assertNotNull(out);
        assertTrue(out.has("@graph"));
    }

    @Test
    public void findsADatasetInATypeArray() {
        String html = page(ld("{\"@context\":\"https://schema.org/\","
            + "\"@type\":[\"Dataset\",\"Product\"],\"name\":\"multi\"}"));

        assertNotNull(Harvester.extractJsonLdFromHtml(html, mapper));
    }

    @Test
    public void matchesAFullyQualifiedTypeIri() {
        String html = page(ld("{\"@context\":\"https://schema.org/\","
            + "\"@type\":\"https://schema.org/Dataset\",\"name\":\"iri\"}"));

        assertNotNull(Harvester.extractJsonLdFromHtml(html, mapper));
    }

    @Test
    public void fallsBackToTheFirstParseableBlockWhenNoDatasetIsPresent() {
        String html = page(ld("{\"@context\":\"https://schema.org/\","
            + "\"@type\":\"Organization\",\"name\":\"only org\"}"));

        JsonNode out = Harvester.extractJsonLdFromHtml(html, mapper);

        assertNotNull(out);
        assertEquals("only org", out.get("name").asText());
    }

    @Test
    public void skipsMalformedBlocksRatherThanFailingTheRecord() {
        String html = page(
            ld("{ this is not json"),
            ld("{\"@context\":\"https://schema.org/\",\"@type\":\"Dataset\",\"name\":\"survivor\"}"));

        JsonNode out = Harvester.extractJsonLdFromHtml(html, mapper);

        assertNotNull(out);
        assertEquals("survivor", out.get("name").asText());
    }

    @Test
    public void returnsNullForAPageWithNoJsonLd() {
        assertNull(Harvester.extractJsonLdFromHtml(page(), mapper));
    }

    @Test
    public void ignoresScriptBlocksOfOtherTypes() {
        String html = "<html><head><script type=\"text/javascript\">var x = {\"@type\":\"Dataset\"};"
            + "</script></head><body></body></html>";

        assertNull(Harvester.extractJsonLdFromHtml(html, mapper));
    }
}
