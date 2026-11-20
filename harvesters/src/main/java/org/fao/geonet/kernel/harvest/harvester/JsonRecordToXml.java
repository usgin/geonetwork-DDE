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

import org.fao.geonet.utils.Xml;
import org.jdom.Element;
import org.jdom.JDOMException;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.XML;

import java.io.IOException;

/**
 * Turns a JSON record into the XML an import XSLT is written against.
 *
 * <p>JSON permits names an XML element cannot carry, so the conversion is not
 * mechanical: three kinds of character have to be rewritten first, and a name that
 * keeps any of them produces XML that JDOM rejects outright -- failing the whole
 * record, not the one field.
 *
 * <ul>
 *   <li>a colon, which XML reads as a namespace separator. Every prefixed JSON-LD
 *       property has one.</li>
 *   <li>a percent sign, which an XML name cannot contain.</li>
 *   <li>whitespace, which ends the name and makes whatever follows look like an
 *       attribute.</li>
 * </ul>
 *
 * <p>Rewriting these does not make every JSON name usable. A property whose prefix the
 * JSON-LD frame does not declare compacts to its full IRI, and the slashes in that IRI
 * are rewritten by nothing here, so {@code https://w3id.org/cdif/fileSize} still arrives
 * as {@code <https_//w3id.org/cdif/fileSize>} and JDOM still rejects it. What prevents
 * that is declaring the prefix in the frame, not anything in this class.
 *
 * <p>This lives here because the SimpleUrl and Directory harvesters both need it and
 * previously carried separate copies that had drifted: the first replaced colons and
 * percent signs but not whitespace, the second whitespace and colons but not percent
 * signs. The same record could therefore import over HTTP and fail from disk, or the
 * reverse, according to which character its property names happened to contain.
 */
public final class JsonRecordToXml {

    /**
     * A colon or percent sign that is inside a tag rather than in text content.
     *
     * <p>The lookahead is what distinguishes the two: from inside a tag the next
     * angle bracket encountered is this tag's own {@code >}, so {@code [^<>]*<}
     * cannot match and the character is rewritten. From text content the next
     * bracket is the following tag's {@code <}, the lookahead matches, and the
     * character is left alone -- which matters, since URLs in the content are full
     * of both.
     */
    private static final String IN_NAME = "(:|%)(?![^<>]*<)";

    private JsonRecordToXml() {
    }

    /**
     * @param record the JSON record, already framed if it is CDIF
     * @param uuid   appended as a {@code uuid} child, which the import XSLTs read
     */
    public static Element toElement(JsonNode record, String uuid)
        throws IOException, JDOMException, JSONException {
        Element element = Xml.loadString(toXmlString(record), false);
        element.addContent(new Element("uuid").setText(uuid));
        return element;
    }

    /**
     * Exposed separately so the rewriting can be tested without a JDOM parse.
     */
    static String toXmlString(JsonNode record) throws JSONException {
        String xml = XML.toString(sanitize(new JSONObject(record.toString())), "record")
            // org.json writes a JSON-LD keyword such as @id as <@id>; the XSLTs read
            // the name without it.
            .replace("<@", "<")
            .replace("</@", "</")
            .replaceAll(IN_NAME, "_");
        return Xml.stripNonValidXMLCharacters(xml);
    }

    /**
     * Replace whitespace in keys with an underscore (mutates the object).
     */
    public static JSONObject sanitize(JSONObject json) throws JSONException {
        JSONArray names = json.names();
        if (names != null) {
            for (int i = 0; i < names.length(); i++) {
                String key = names.getString(i);
                if (key.contains(" ")) {
                    String oldKey = key;
                    key = key.replace(" ", "_");
                    json.put(key, json.get(oldKey));
                    json.remove(oldKey);
                }
                Object value = json.opt(key);
                if (value instanceof JSONObject) {
                    sanitize((JSONObject) value);
                } else if (value instanceof JSONArray) {
                    sanitize((JSONArray) value);
                }
            }
        }
        return json;
    }

    public static JSONArray sanitize(JSONArray array) throws JSONException {
        for (int i = 0; i < array.length(); i++) {
            Object value = array.get(i);
            if (value instanceof JSONObject) {
                sanitize((JSONObject) value);
            } else if (value instanceof JSONArray) {
                sanitize((JSONArray) value);
            }
        }
        return array;
    }
}
