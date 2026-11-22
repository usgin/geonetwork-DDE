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
package org.fao.geonet.util;

import org.fao.geonet.ApplicationContextHolder;
import org.fao.geonet.SystemInfo;
import org.fao.geonet.domain.HarvestHistory;
import org.fao.geonet.domain.ISODate;
import org.fao.geonet.domain.Metadata;
import org.fao.geonet.kernel.datamanager.IMetadataUtils;
import org.fao.geonet.repository.HarvestHistoryRepository;
import org.jdom.Element;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mockito;
import org.springframework.context.support.GenericApplicationContext;

import java.util.Arrays;
import java.util.Collections;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * The provenance sentence is composed per request from the harvest database and never
 * stored, because a harvest replaces the record XML and would erase a stored note.
 * These pin what it says, and equally that it stays quiet rather than failing when the
 * harvest rows are absent: a formatter has to produce a record either way.
 */
public class XslUtilHarvestProvenanceTest {

    /** What the formatter passes in from its own stylesheetUpdated variable. */
    private static final String FORMATTER_VERSION = "2026-11-22";

    private IMetadataUtils metadataUtils;
    private HarvestHistoryRepository historyRepository;

    @Before
    public void setUpApplicationContext() {
        metadataUtils = Mockito.mock(IMetadataUtils.class);
        historyRepository = Mockito.mock(HarvestHistoryRepository.class);
        SystemInfo systemInfo = Mockito.mock(SystemInfo.class);
        Mockito.when(systemInfo.getScmRevision()).thenReturn("abc1234");

        GenericApplicationContext context = new GenericApplicationContext();
        context.refresh();
        context.getBeanFactory().registerSingleton("metadataUtils", metadataUtils);
        context.getBeanFactory().registerSingleton("harvestHistoryRepository", historyRepository);
        context.getBeanFactory().registerSingleton("systemInfo", systemInfo);
        ApplicationContextHolder.set(context);
    }

    @After
    public void clearApplicationContext() {
        ApplicationContextHolder.clear();
    }

    private Metadata harvestedRecord(String uri, String harvesterUuid) {
        Metadata record = new Metadata();
        record.getHarvestInfo().setHarvested(true).setUri(uri).setUuid(harvesterUuid);
        return record;
    }

    private HarvestHistory run(String name, String type, String conversionElement, String conversion) {
        Element params = new Element("node");
        Element content = new Element("content");
        content.addContent(new Element(conversionElement).setText(conversion));
        params.addContent(content);
        return new HarvestHistory()
            .setHarvesterUuid("h-1")
            .setHarvesterName(name)
            .setHarvesterType(type)
            .setHarvestDate(new ISODate("2026-11-20T10:11:12"))
            .setParams(params);
    }

    @Test
    public void saysNothingForARecordThatWasNotHarvested() {
        Metadata record = new Metadata();
        record.getHarvestInfo().setHarvested(false);
        Mockito.when(metadataUtils.findOneByUuid("r-1")).thenReturn(record);

        assertEquals("", XslUtil.getHarvestProvenance("r-1", FORMATTER_VERSION));
    }

    @Test
    public void saysNothingForAnUnknownRecord() {
        Mockito.when(metadataUtils.findOneByUuid("missing")).thenReturn(null);

        assertEquals("", XslUtil.getHarvestProvenance("missing", FORMATTER_VERSION));
        assertEquals("", XslUtil.getHarvestProvenance(null, FORMATTER_VERSION));
        assertEquals("", XslUtil.getHarvestProvenance("", FORMATTER_VERSION));
    }

    @Test
    public void namesTheSourceHarvesterTypeDateAndConversion() {
        Mockito.when(metadataUtils.findOneByUuid("r-1"))
            .thenReturn(harvestedRecord("https://example.org/sitemap.xml", "h-1"));
        Mockito.when(historyRepository.findAllByHarvesterUuid("h-1")).thenReturn(
            Collections.singletonList(run("GA catalogue", "filesystem",
                "importxslt", "schema:iso19115-3.2018:convert/fromDDE-any")));

        String note = XslUtil.getHarvestProvenance("r-1", FORMATTER_VERSION);
        assertTrue(note, note.contains("https://example.org/sitemap.xml"));
        assertTrue(note, note.contains("GA catalogue"));
        assertTrue(note, note.contains("type filesystem"));
        // ISODate normalises to UTC, so the clock time depends on the build machine.
        // That this test does not care about; that the harvest date is reported, it does.
        assertTrue(note, note.contains("2026-11-20T"));
        assertTrue(note, note.contains("convert/fromDDE-any"));
        assertTrue(note, note.contains("iso19115-3-to-cdif.xsl (last updated 2026-11-22)"));
        assertTrue(note, note.contains("Catalogue build abc1234"));
    }

    /**
     * The SimpleUrl harvester stores the same setting under a different name.
     */
    @Test
    public void readsTheSimpleUrlConversionParameterToo() {
        Mockito.when(metadataUtils.findOneByUuid("r-1"))
            .thenReturn(harvestedRecord("https://example.org/record.json", "h-1"));
        Mockito.when(historyRepository.findAllByHarvesterUuid("h-1")).thenReturn(
            Collections.singletonList(run("CDIF sitemap", "simpleurl",
                "toISOConversion", "schema:iso19115-3.2018:convert/fromJsonCdif")));

        String note = XslUtil.getHarvestProvenance("r-1", FORMATTER_VERSION);
        assertTrue(note, note.contains("convert/fromJsonCdif"));
        assertTrue(note, note.contains("JSON-LD framed"));
        assertTrue(note, note.contains("restored from the source"));
    }

    @Test
    public void saysSoWhenNoConversionWasApplied() {
        Mockito.when(metadataUtils.findOneByUuid("r-1"))
            .thenReturn(harvestedRecord("https://example.org/csw", "h-1"));
        Mockito.when(historyRepository.findAllByHarvesterUuid("h-1")).thenReturn(
            Collections.singletonList(run("Some CSW", "csw", "importxslt", "none")));

        String note = XslUtil.getHarvestProvenance("r-1", FORMATTER_VERSION);
        assertTrue(note, note.contains("no conversion applied"));
    }

    /**
     * Only the latest run describes the configuration the record was last processed
     * with, and the rows come back in no particular order.
     */
    @Test
    public void usesTheMostRecentRun() {
        Mockito.when(metadataUtils.findOneByUuid("r-1"))
            .thenReturn(harvestedRecord("https://example.org/x", "h-1"));
        HarvestHistory older = run("Old name", "filesystem", "importxslt", "convert/old")
            .setHarvestDate(new ISODate("2020-01-01T00:00:00"));
        HarvestHistory newer = run("New name", "simpleurl", "toISOConversion", "convert/new");
        Mockito.when(historyRepository.findAllByHarvesterUuid("h-1"))
            .thenReturn(Arrays.asList(newer, older));

        String note = XslUtil.getHarvestProvenance("r-1", FORMATTER_VERSION);
        assertTrue(note, note.contains("New name"));
        assertTrue(note, note.contains("convert/new"));
    }

    /**
     * A harvester with no history rows still has a source worth reporting.
     */
    @Test
    public void stillNamesTheSourceWithNoHistoryRows() {
        Mockito.when(metadataUtils.findOneByUuid("r-1"))
            .thenReturn(harvestedRecord("https://example.org/only", "h-1"));
        Mockito.when(historyRepository.findAllByHarvesterUuid("h-1"))
            .thenReturn(Collections.emptyList());

        String note = XslUtil.getHarvestProvenance("r-1", FORMATTER_VERSION);
        assertTrue(note, note.contains("https://example.org/only"));
    }
}
