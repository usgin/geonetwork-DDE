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

import java.util.Arrays;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/**
 * Reading the catalog record's conformance classes, and dispatching on them.
 *
 * <p>Most of these tests exist because of a specific way of getting it wrong, named in each
 * test. The two that matter most: a matcher keyed on {@code @type} never fires, and a
 * matcher that searches for any {@code conformsTo} dispatches on a data file's format.
 */
public class CdifConformanceTest {

    private final ObjectMapper mapper = new ObjectMapper();

    private JsonNode json(String s) {
        try {
            return mapper.readTree(s);
        } catch (Exception e) {
            throw new IllegalArgumentException(e);
        }
    }

    /** A record whose catalog record declares the given conformsTo array body. */
    private JsonNode record(String conformsToBody) {
        return json("{"
            + "\"@id\": \"ex:ds\","
            + "\"@type\": [\"schema:Dataset\"],"
            + "\"schema:name\": \"a dataset\","
            + "\"schema:subjectOf\": {"
            + "  \"@id\": \"ex:ds#record\","
            + "  \"@type\": [\"schema:Dataset\"],"
            + "  \"schema:additionalType\": [{\"@id\": \"dcat:CatalogRecord\"}],"
            + "  \"schema:about\": {\"@id\": \"ex:ds\"},"
            + "  \"dcterms:conformsTo\": " + conformsToBody
            + "}}");
    }

    // ---- reading the declaration -------------------------------------------------

    @Test
    public void readsConformsToFromTheCatalogRecord() {
        List<String> uris = CdifConformance.conformsTo(record(
            "[{\"@id\": \"https://w3id.org/cdif/core/1.1\"},"
                + "{\"@id\": \"https://w3id.org/cdif/dde/1.0/DDEDataset\"}]"));
        assertEquals(Arrays.asList(
            "https://w3id.org/cdif/core/1.1",
            "https://w3id.org/cdif/dde/1.0/DDEDataset"), uris);
    }

    @Test
    public void acceptsASingleConformsToObjectRatherThanAnArray() {
        assertEquals(Arrays.asList("https://w3id.org/cdif/core/1.1"),
            CdifConformance.conformsTo(record("{\"@id\": \"https://w3id.org/cdif/core/1.1\"}")));
    }

    @Test
    public void acceptsConformsToEntriesGivenAsPlainStrings() {
        assertEquals(Arrays.asList("https://w3id.org/cdif/core/1.1"),
            CdifConformance.conformsTo(record("[\"https://w3id.org/cdif/core/1.1\"]")));
    }

    @Test
    public void acceptsSubjectOfAsAnArrayAndPicksTheCatalogRecord() {
        JsonNode r = json("{"
            + "\"@type\": [\"schema:Dataset\"],"
            + "\"schema:subjectOf\": ["
            + "  {\"@type\": [\"schema:CreativeWork\"],"
            + "   \"schema:name\": \"a paper about this dataset\","
            + "   \"dcterms:conformsTo\": [{\"@id\": \"https://example.org/NOT-THIS\"}]},"
            + "  {\"schema:additionalType\": [{\"@id\": \"dcat:CatalogRecord\"}],"
            + "   \"dcterms:conformsTo\": [{\"@id\": \"https://w3id.org/cdif/core/1.1\"}]}"
            + "]}");
        assertEquals(Arrays.asList("https://w3id.org/cdif/core/1.1"),
            CdifConformance.conformsTo(r));
    }

    @Test
    public void acceptsUnprefixedAndExpandedPropertyNames() {
        JsonNode bare = json("{\"subjectOf\": {"
            + "\"additionalType\": \"dcat:CatalogRecord\","
            + "\"conformsTo\": \"https://w3id.org/cdif/core/1.1\"}}");
        assertEquals(Arrays.asList("https://w3id.org/cdif/core/1.1"),
            CdifConformance.conformsTo(bare));

        JsonNode expanded = json("{\"http://schema.org/subjectOf\": {"
            + "\"http://schema.org/additionalType\": "
            + "    [{\"@id\": \"http://www.w3.org/ns/dcat#CatalogRecord\"}],"
            + "\"http://purl.org/dc/terms/conformsTo\": "
            + "    [{\"@id\": \"https://w3id.org/cdif/core/1.1\"}]}}");
        assertEquals(Arrays.asList("https://w3id.org/cdif/core/1.1"),
            CdifConformance.conformsTo(expanded));
    }

    // ---- the two traps the spec names --------------------------------------------

    @Test
    public void doesNotDispatchOnADistributionsFormatConformance() {
        // dcterms:conformsTo is legal on a distribution. A "find any conformsTo" matcher
        // would dispatch this record on the format of its data file.
        JsonNode r = json("{"
            + "\"@type\": [\"schema:Dataset\"],"
            + "\"schema:distribution\": [{"
            + "  \"@type\": [\"schema:DataDownload\"],"
            + "  \"schema:contentUrl\": \"https://example.org/d.csv\","
            + "  \"dcterms:conformsTo\": [{\"@id\": \"https://example.org/csv-profile\"}]"
            + "}]}");
        assertTrue(CdifConformance.conformsTo(r).isEmpty());
    }

    @Test
    public void doesNotTreatASubjectOfNodeAsTheCatalogRecordOnTypeAlone() {
        // The catalog record's @type is ["schema:Dataset"], the same as the resource it
        // describes, so @type cannot identify it -- and a node without
        // dcat:CatalogRecord in additionalType is not it, whatever its @type says.
        JsonNode r = json("{"
            + "\"@type\": [\"schema:Dataset\"],"
            + "\"schema:subjectOf\": {"
            + "  \"@type\": [\"schema:Dataset\"],"
            + "  \"dcterms:conformsTo\": [{\"@id\": \"https://example.org/NOT-THIS\"}]"
            + "}}");
        assertTrue(CdifConformance.conformsTo(r).isEmpty());
    }

    @Test
    public void emptyWhenThereIsNoSubjectOfAtAll() {
        assertTrue(CdifConformance.conformsTo(
            json("{\"@type\": [\"schema:Dataset\"], \"schema:name\": \"x\"}")).isEmpty());
    }

    @Test
    public void emptyWhenTheCatalogRecordDeclaresNothing() {
        JsonNode r = json("{\"schema:subjectOf\": {"
            + "\"schema:additionalType\": [{\"@id\": \"dcat:CatalogRecord\"}]}}");
        assertTrue(CdifConformance.conformsTo(r).isEmpty());
    }

    @Test
    public void toleratesNullAndNonObjectInput() {
        assertTrue(CdifConformance.conformsTo(null).isEmpty());
        assertTrue(CdifConformance.conformsTo(json("[1,2,3]")).isEmpty());
        assertTrue(CdifConformance.conformsTo(json("\"a string\"")).isEmpty());
    }

    // ---- rule parsing ------------------------------------------------------------

    @Test
    public void parsesRulesOnePerLineIgnoringBlanksAndComments() {
        List<CdifConformance.Rule> rules = CdifConformance.parseRules(
            "# DDE profiles first\n"
                + "https://w3id.org/cdif/dde/1.0/*=schema:iso19115-3.2018:convert/fromDde\n"
                + "\n"
                + "https://w3id.org/cdif/core/1.1=schema:iso19115-3.2018:convert/fromJsonCdif\n");
        assertEquals(2, rules.size());
        assertEquals("schema:iso19115-3.2018:convert/fromDde", rules.get(0).conversion);
        assertEquals("schema:iso19115-3.2018:convert/fromJsonCdif", rules.get(1).conversion);
    }

    @Test
    public void parsesSemicolonSeparatedRules() {
        assertEquals(2, CdifConformance.parseRules("a=one;b=two").size());
    }

    @Test
    public void skipsMalformedRulesRatherThanFailing() {
        // A typo in one rule must not take the whole harvester down.
        List<CdifConformance.Rule> rules = CdifConformance.parseRules(
            "no-equals-sign\n=missing-uri\nmissing-conversion=\nok=fine");
        assertEquals(1, rules.size());
        assertEquals("fine", rules.get(0).conversion);
    }

    @Test
    public void emptyRuleSpecGivesNoRules() {
        assertTrue(CdifConformance.parseRules(null).isEmpty());
        assertTrue(CdifConformance.parseRules("   \n  ").isEmpty());
    }

    // ---- selection ---------------------------------------------------------------

    @Test
    public void ruleOrderDecidesNotTheOrderTheRecordListsItsClasses() {
        // Every CDIF record declares core/1.1 alongside its specific profile, and here the
        // record lists core first. A base-class rule placed last must still lose.
        List<CdifConformance.Rule> rules = CdifConformance.parseRules(
            "https://w3id.org/cdif/dde/1.0/*=fromDde\n"
                + "https://w3id.org/cdif/core/1.1=fromJsonCdif");
        List<String> declared = Arrays.asList(
            "https://w3id.org/cdif/core/1.1",
            "https://w3id.org/cdif/discovery/1.1",
            "https://w3id.org/cdif/dde/1.0/DDEImage");
        assertEquals("fromDde", CdifConformance.select(rules, declared));
    }

    @Test
    public void aBaseClassRulePlacedFirstSwallowsEverything() {
        // The failure mode the ordering requirement exists for, asserted so the cost of
        // getting the order wrong is visible rather than folklore.
        List<CdifConformance.Rule> rules = CdifConformance.parseRules(
            "https://w3id.org/cdif/core/1.1=fromJsonCdif\n"
                + "https://w3id.org/cdif/dde/1.0/*=fromDde");
        assertEquals("fromJsonCdif", CdifConformance.select(rules,
            Arrays.asList("https://w3id.org/cdif/core/1.1",
                "https://w3id.org/cdif/dde/1.0/DDEImage")));
    }

    @Test
    public void prefixRuleCoversAFamilyOfProfileUris() {
        List<CdifConformance.Rule> rules =
            CdifConformance.parseRules("https://w3id.org/cdif/dde/1.0/*=fromDde");
        for (String profile : new String[]{"DDEDataset", "DDEImage", "DDEWebAPI"}) {
            assertEquals("fromDde", CdifConformance.select(rules,
                Arrays.asList("https://w3id.org/cdif/dde/1.0/" + profile)));
        }
        assertNull(CdifConformance.select(rules,
            Arrays.asList("https://w3id.org/cdif/dde/2.0/DDEDataset")));
    }

    @Test
    public void exactRuleDoesNotMatchAProfileUnderIt() {
        List<CdifConformance.Rule> rules =
            CdifConformance.parseRules("https://w3id.org/cdif/core/1.1=fromJsonCdif");
        assertNull(CdifConformance.select(rules,
            Arrays.asList("https://w3id.org/cdif/core/1.1/schema")));
    }

    @Test
    public void nullWhenNothingMatchesSoTheCallerCanFallBack() {
        assertNull(CdifConformance.select(
            CdifConformance.parseRules("a=one"), Arrays.asList("b", "c")));
        assertNull(CdifConformance.select(
            CdifConformance.parseRules("a=one"), java.util.Collections.emptyList()));
        assertNull(CdifConformance.select(null, Arrays.asList("a")));
    }

    // ---- end to end on a realistic record ----------------------------------------

    @Test
    public void dispatchesARealisticDdeRecordOnItsProfile() {
        JsonNode r = record(
            "[{\"@id\": \"https://w3id.org/cdif/core/1.1\"},"
                + "{\"@id\": \"https://w3id.org/cdif/discovery/1.1\"},"
                + "{\"@id\": \"https://w3id.org/cdif/dde/1.0/DDECollection\"},"
                + "{\"@id\": \"https://w3id.org/cdif/manifest/1.1\"}]");
        List<CdifConformance.Rule> rules = CdifConformance.parseRules(
            "https://w3id.org/cdif/dde/1.0/*=schema:iso19115-3.2018:convert/fromDde\n"
                + "https://w3id.org/cdif/core/2.0=schema:iso19115-3.2018:convert/fromJsonCdifV2\n"
                + "https://w3id.org/cdif/core/1.1=schema:iso19115-3.2018:convert/fromJsonCdif");
        assertEquals("schema:iso19115-3.2018:convert/fromDde",
            CdifConformance.select(rules, CdifConformance.conformsTo(r)));
    }

    @Test
    public void aPlainCdifRecordFallsThroughToTheBaseRule() {
        JsonNode r = record("[{\"@id\": \"https://w3id.org/cdif/core/1.1\"},"
            + "{\"@id\": \"https://w3id.org/cdif/discovery/1.1\"}]");
        List<CdifConformance.Rule> rules = CdifConformance.parseRules(
            "https://w3id.org/cdif/dde/1.0/*=fromDde\n"
                + "https://w3id.org/cdif/core/1.1=fromJsonCdif");
        assertEquals("fromJsonCdif", CdifConformance.select(rules, CdifConformance.conformsTo(r)));
    }
}
