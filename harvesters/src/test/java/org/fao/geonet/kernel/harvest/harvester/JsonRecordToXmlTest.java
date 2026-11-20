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
package org.fao.geonet.kernel.harvest.harvester;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import org.jdom.Element;
import org.jdom.JDOMException;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.fail;
import static org.junit.Assert.assertTrue;

/**
 * The three characters a JSON name can carry and an XML name cannot. Each one left in
 * place makes JDOM reject the whole document, so a single bad property name loses the
 * record rather than the field -- which is why these are worth pinning down.
 */
public class JsonRecordToXmlTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static JsonNode json(String s) throws Exception {
        return MAPPER.readTree(s);
    }

    @Test
    public void rewritesColonInAName() throws Exception {
        String xml = JsonRecordToXml.toXmlString(json("{\"schema:name\": \"Test\"}"));
        assertTrue(xml, xml.contains("<schema_name>Test</schema_name>"));
    }

    @Test
    public void rewritesPercentInAName() throws Exception {
        String xml = JsonRecordToXml.toXmlString(json("{\"pct%value\": \"40\"}"));
        assertTrue(xml, xml.contains("<pct_value>40</pct_value>"));
    }

    /**
     * The limit of the rewriting, pinned because it is easy to assume otherwise: a
     * property whose prefix the frame does not declare compacts to its full IRI, and
     * the slashes in that IRI are rewritten by nothing here. Declaring the prefix in
     * cdif-frame.jsonld is what keeps these out, not this class.
     */
    @Test
    public void cannotRescueAnIriUsedAsAName() throws Exception {
        String xml = JsonRecordToXml.toXmlString(
            json("{\"https://w3id.org/cdif/fileSize\": \"1\"}"));
        assertTrue(xml, xml.contains("<https_//w3id.org/cdif/fileSize>"));
        try {
            JsonRecordToXml.toElement(json("{\"https://w3id.org/cdif/fileSize\": \"1\"}"), "u");
            fail("expected JDOM to reject an element name containing slashes");
        } catch (JDOMException expected) {
            // the whole record is lost, not the one field
        }
    }

    @Test
    public void rewritesWhitespaceInAName() throws Exception {
        String xml = JsonRecordToXml.toXmlString(json("{\"file size\": \"4.6\"}"));
        assertTrue(xml, xml.contains("<file_size>4.6</file_size>"));
    }

    /**
     * The same three characters are ordinary in a value, and a CDIF record is full of
     * URLs. Rewriting them there would corrupt every identifier in the document.
     */
    @Test
    public void leavesTheSameCharactersAloneInAValue() throws Exception {
        String xml = JsonRecordToXml.toXmlString(
            json("{\"id\": \"https://example.org/a%20b?x=1\"}"));
        assertTrue(xml, xml.contains("https://example.org/a%20b?x=1"));
    }

    /**
     * org.json writes the JSON-LD keywords as {@code <@id>}; the import XSLTs read them
     * without the sigil.
     */
    @Test
    public void stripsTheJsonLdKeywordSigil() throws Exception {
        String xml = JsonRecordToXml.toXmlString(json("{\"@id\": \"urn:x\"}"));
        assertTrue(xml, xml.contains("<id>urn:x</id>"));
    }

    @Test
    public void rewritesNamesNestedInObjectsAndArrays() throws Exception {
        String xml = JsonRecordToXml.toXmlString(json(
            "{\"schema:distribution\": [{\"cdif:file size\": \"1\"}]}"));
        assertTrue(xml, xml.contains("<cdif_file_size>1</cdif_file_size>"));
    }

    @Test
    public void appendsTheUuidTheImportXsltReads() throws Exception {
        Element record = JsonRecordToXml.toElement(json("{\"schema:name\": \"Test\"}"), "abc-123");
        assertEquals("record", record.getName());
        assertNotNull(record.getChild("uuid"));
        assertEquals("abc-123", record.getChildText("uuid"));
    }
}
