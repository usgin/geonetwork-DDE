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

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.Test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/**
 * The two decisions that gate CDIF preparation. Both harvesters call these before
 * doing any work, and the Directory harvester passes a value that may be the
 * sentinel "none" rather than a conversion at all.
 */
public class CdifJsonPreparerTest {

    private final ObjectMapper mapper = new ObjectMapper();

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
}
