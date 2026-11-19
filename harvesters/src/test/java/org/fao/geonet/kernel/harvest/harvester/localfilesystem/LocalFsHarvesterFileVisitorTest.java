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
package org.fao.geonet.kernel.harvest.harvester.localfilesystem;

import org.junit.Test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/**
 * Which file names the Directory harvester reads as JSON. A name rejected here is
 * skipped before anything counts or logs it, so the whole folder harvests as zero
 * files with nothing to explain why -- which is what used to happen to CDIF records
 * stored with the ordinary JSON-LD extension.
 */
public class LocalFsHarvesterFileVisitorTest {

    @Test
    public void readsPlainJson() {
        assertTrue(LocalFsHarvesterFileVisitor.isJsonExtension("record.json"));
    }

    @Test
    public void readsJsonLd() {
        assertTrue(LocalFsHarvesterFileVisitor.isJsonExtension("record.jsonld"));
    }

    /**
     * The CDIF examples are stored this way, which is why case is ignored.
     */
    @Test
    public void ignoresExtensionCase() {
        assertTrue(LocalFsHarvesterFileVisitor.isJsonExtension("cdif_se_na2so4-xdi.jsonLD"));
        assertTrue(LocalFsHarvesterFileVisitor.isJsonExtension("record.JSON"));
        assertTrue(LocalFsHarvesterFileVisitor.isJsonExtension("record.JsonLd"));
    }

    @Test
    public void readsNamesWithSeveralDots() {
        assertTrue(LocalFsHarvesterFileVisitor.isJsonExtension(
            "sftlf_fx_AWI-CM-1-1-MR_ssp370_r1i1p1f1_gn.jsonld"));
        assertTrue(LocalFsHarvesterFileVisitor.isJsonExtension("cdif.v1.2.jsonld"));
    }

    @Test
    public void rejectsOtherExtensions() {
        assertFalse(LocalFsHarvesterFileVisitor.isJsonExtension("record.xml"));
        assertFalse(LocalFsHarvesterFileVisitor.isJsonExtension("record.mef"));
        assertFalse(LocalFsHarvesterFileVisitor.isJsonExtension("notes.txt"));
    }

    /**
     * The extension has to end the name: a directory called {@code exports.json} or a
     * half-written {@code record.jsonld.tmp} is not a record.
     */
    @Test
    public void rejectsNamesThatOnlyContainTheExtension() {
        assertFalse(LocalFsHarvesterFileVisitor.isJsonExtension("record.jsonld.tmp"));
        assertFalse(LocalFsHarvesterFileVisitor.isJsonExtension("record.json.bak"));
        assertFalse(LocalFsHarvesterFileVisitor.isJsonExtension("json"));
        assertFalse(LocalFsHarvesterFileVisitor.isJsonExtension("jsonld"));
    }
}
