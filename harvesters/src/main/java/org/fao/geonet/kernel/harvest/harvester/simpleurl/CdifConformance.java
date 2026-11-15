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

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Reads the conformance classes a CDIF record declares, and picks a conversion from them.
 *
 * <p>This lets one harvester take a mixed feed: the stylesheet comes from what the record
 * says it conforms to, rather than from a single value configured for the whole feed.
 *
 * <p>Finding the declaration is narrower than it looks. {@code dcterms:conformsTo} is legal
 * in four places in a CDIF v1.1 record -- on a distribution, on a distribution's
 * {@code potentialAction} result, and twice under {@code schema:subjectOf} -- so a matcher
 * that searched for any {@code conformsTo} could dispatch a record on the format conformance
 * of one of its <em>data files</em>. Only the catalog record's own declaration counts, and
 * the catalog record is identified by {@code dcat:CatalogRecord} appearing in its
 * {@code schema:additionalType}: its {@code @type} is {@code ["schema:Dataset"]}, the same
 * as the resource it describes, so an {@code @type} test never fires.
 *
 * <p>Read from the <strong>unframed</strong> record. Framing rewrites structure, which is
 * the reason {@code recoverDroppedFields()} exists in the harvester.
 */
final class CdifConformance {

    /**
     * Property names accepted for one CDIF term: compact with prefix, bare, and expanded.
     * A harvested record may use any of the three, since JSON-LD leaves the choice to the
     * publisher and this runs before framing would have normalised it.
     */
    private static final String[] SUBJECT_OF = {
        "schema:subjectOf", "subjectOf", "http://schema.org/subjectOf",
        "https://schema.org/subjectOf"
    };
    private static final String[] ADDITIONAL_TYPE = {
        "schema:additionalType", "additionalType", "http://schema.org/additionalType",
        "https://schema.org/additionalType"
    };
    private static final String[] CONFORMS_TO = {
        "dcterms:conformsTo", "conformsTo", "http://purl.org/dc/terms/conformsTo",
        "dct:conformsTo"
    };
    private static final String[] CATALOG_RECORD = {
        "dcat:CatalogRecord", "http://www.w3.org/ns/dcat#CatalogRecord",
        "https://www.w3.org/ns/dcat#CatalogRecord"
    };

    private CdifConformance() {
    }

    /**
     * One dispatch rule: a conformance URI to look for, and the conversion to use when the
     * record declares it. A trailing {@code *} makes the URI a prefix, which is how a family
     * of profile URIs is covered by one rule.
     */
    static final class Rule {
        final String uri;
        final boolean prefix;
        final String conversion;

        Rule(String uri, String conversion) {
            this.prefix = uri.endsWith("*");
            this.uri = this.prefix ? uri.substring(0, uri.length() - 1) : uri;
            this.conversion = conversion;
        }

        boolean matches(String declared) {
            return prefix ? declared.startsWith(uri) : declared.equals(uri);
        }

        @Override
        public String toString() {
            return (prefix ? uri + "*" : uri) + "=" + conversion;
        }
    }

    /**
     * The conformance URIs the record's catalog record declares, in document order.
     *
     * @return the declared URIs, or an empty list when the record has no catalog record
     *         carrying {@code dcat:CatalogRecord}. Empty means "do not dispatch", never
     *         "dispatch on whatever conformsTo turns up elsewhere".
     */
    static List<String> conformsTo(JsonNode record) {
        if (record == null || !record.isObject()) {
            return Collections.emptyList();
        }
        JsonNode subjectOf = firstPresent(record, SUBJECT_OF);
        if (subjectOf == null) {
            return Collections.emptyList();
        }
        for (JsonNode candidate : each(subjectOf)) {
            if (isCatalogRecord(candidate)) {
                return readIris(firstPresent(candidate, CONFORMS_TO));
            }
        }
        return Collections.emptyList();
    }

    /**
     * Parse a rule list. One rule per line or per semicolon, {@code uri=conversion}, blank
     * lines and {@code #} comments ignored.
     *
     * <p>Order is significant and is preserved: every CDIF record asserts several classes at
     * once -- a profile alongside {@code cdif/core/1.1} -- so a rule for the shared base
     * class placed first would swallow every record. Most specific first.
     */
    static List<Rule> parseRules(String spec) {
        List<Rule> rules = new ArrayList<>();
        if (spec == null || spec.trim().isEmpty()) {
            return rules;
        }
        for (String line : spec.split("[\\r\\n;]+")) {
            String trimmed = line.trim();
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                continue;
            }
            int eq = trimmed.indexOf('=');
            if (eq <= 0 || eq == trimmed.length() - 1) {
                continue;
            }
            String uri = trimmed.substring(0, eq).trim();
            String conversion = trimmed.substring(eq + 1).trim();
            if (!uri.isEmpty() && !conversion.isEmpty()) {
                rules.add(new Rule(uri, conversion));
            }
        }
        return rules;
    }

    /**
     * The conversion for the first rule matching any declared URI, or null when none does.
     *
     * <p>Rules are tried in order, and for each rule every declared URI, so the rule order
     * decides -- not the order the record happens to list its classes in.
     */
    static String select(List<Rule> rules, List<String> declared) {
        if (rules == null || declared == null || declared.isEmpty()) {
            return null;
        }
        for (Rule rule : rules) {
            for (String uri : declared) {
                if (rule.matches(uri)) {
                    return rule.conversion;
                }
            }
        }
        return null;
    }

    /**
     * Whether this node is the catalog record, by {@code dcat:CatalogRecord} in its
     * {@code schema:additionalType}. Not by {@code @type}: see the class comment.
     */
    private static boolean isCatalogRecord(JsonNode node) {
        if (node == null || !node.isObject()) {
            return false;
        }
        for (String iri : readIris(firstPresent(node, ADDITIONAL_TYPE))) {
            if (Arrays.asList(CATALOG_RECORD).contains(iri)) {
                return true;
            }
        }
        return false;
    }

    /**
     * IRIs from a value that may be a single item or an array, each item either a plain
     * string or an object carrying {@code @id}.
     */
    private static List<String> readIris(JsonNode value) {
        List<String> iris = new ArrayList<>();
        for (JsonNode item : each(value)) {
            if (item.isTextual()) {
                add(iris, item.asText());
            } else if (item.isObject()) {
                JsonNode id = item.get("@id");
                if (id == null) {
                    id = item.get("id");
                }
                if (id != null && id.isTextual()) {
                    add(iris, id.asText());
                }
            }
        }
        return iris;
    }

    private static void add(List<String> iris, String raw) {
        String trimmed = raw == null ? "" : raw.trim();
        if (!trimmed.isEmpty()) {
            iris.add(trimmed);
        }
    }

    /** The first of these property names that the node actually carries. */
    private static JsonNode firstPresent(JsonNode node, String[] names) {
        for (String name : names) {
            JsonNode value = node.get(name);
            if (value != null && !value.isNull()) {
                return value;
            }
        }
        return null;
    }

    /** Iterate a value whether it is an array or a single item. */
    private static Iterable<JsonNode> each(JsonNode value) {
        if (value == null || value.isNull()) {
            return Collections.emptyList();
        }
        if (value.isArray()) {
            List<JsonNode> items = new ArrayList<>();
            value.forEach(items::add);
            return items;
        }
        return Collections.singletonList(value);
    }
}
