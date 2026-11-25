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

package org.fao.geonet.api.site;

import org.fao.geonet.kernel.SchemaManager;
import org.jdom.Element;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.mockito.Mockito;

import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.Assert.assertEquals;

/**
 * The sitemap's format parameter decides which serialisation the URLs in it
 * point at, so an unrecognised value must not quietly become a sitemap of
 * something else.
 */
public class SitemapApiFormatTest {

    @Test
    public void cdifIsAccepted() {
        assertEquals("cdif", SitemapApi.normalizeFormat("cdif"));
    }

    @Test
    public void ddeIsAccepted() {
        assertEquals("dde", SitemapApi.normalizeFormat("dde"));
    }

    @Test
    public void xmlIsStillAccepted() {
        assertEquals("xml", SitemapApi.normalizeFormat("xml"));
    }

    @Test
    public void caseIsIgnored() {
        // The stylesheet compares the value literally, so without lower-casing
        // an uppercase request would fall through to the html sitemap.
        assertEquals("cdif", SitemapApi.normalizeFormat("CDIF"));
        assertEquals("xml", SitemapApi.normalizeFormat("Xml"));
    }

    @Test
    public void anythingElseFallsBackToHtml() {
        assertEquals("html", SitemapApi.normalizeFormat("html"));
        assertEquals("html", SitemapApi.normalizeFormat(null));
        assertEquals("html", SitemapApi.normalizeFormat(""));
        assertEquals("html", SitemapApi.normalizeFormat("iso19139"));
        // robots.txt advertises format=rdf, which has never been implemented in
        // the controller. It coerces to html, as it did before this change.
        assertEquals("html", SitemapApi.normalizeFormat("rdf"));
    }

    @Rule
    public TemporaryFolder schemaPlugins = new TemporaryFolder();

    private SitemapApi api;

    /**
     * iso19115-3.2018 gets a cdif formatter directory, iso19139 does not --
     * which is the real arrangement in this catalogue.
     */
    @Before
    public void setUpSchemas() throws Exception {
        Path withCdif = schemaPlugins.newFolder("iso19115-3.2018").toPath();
        Files.createDirectories(withCdif.resolve("formatter").resolve("cdif"));
        Path withoutCdif = schemaPlugins.newFolder("iso19139").toPath();
        Files.createDirectories(withoutCdif.resolve("formatter").resolve("dcat"));

        SchemaManager schemaManager = Mockito.mock(SchemaManager.class);
        Mockito.when(schemaManager.getSchemaDir("iso19115-3.2018")).thenReturn(withCdif);
        Mockito.when(schemaManager.getSchemaDir("iso19139")).thenReturn(withoutCdif);
        Mockito.when(schemaManager.getSchemaDir("dublin-core"))
            .thenThrow(new IllegalArgumentException("Schema not registered : dublin-core"));

        api = new SitemapApi();
        Field field = SitemapApi.class.getDeclaredField("schemaManager");
        field.setAccessible(true);
        field.set(api, schemaManager);
    }

    @Test
    public void aRecordWhoseSchemaLacksTheFormatterIsNotListed() throws Exception {
        Element records = new Element("metadata");
        records.addContent(record("has-cdif", "iso19115-3.2018"));
        records.addContent(record("no-cdif", "iso19139"));
        records.addContent(record("also-has-cdif", "iso19115-3.2018"));

        invokeDrop(records, "cdif");

        List<?> remaining = records.getChildren("record");
        assertEquals(2, remaining.size());
        assertEquals("has-cdif", ((Element) remaining.get(0)).getChildText("uuid"));
        assertEquals("also-has-cdif", ((Element) remaining.get(1)).getChildText("uuid"));
    }

    @Test
    public void aRecordOfAnUninstalledSchemaIsNotListed() throws Exception {
        // getSchemaDir throws for a schema that is no longer registered, which
        // must not propagate out of the sitemap request.
        Element records = new Element("metadata");
        records.addContent(record("orphan", "dublin-core"));
        records.addContent(record("fine", "iso19115-3.2018"));

        invokeDrop(records, "cdif");

        assertEquals(1, records.getChildren("record").size());
        assertEquals("fine",
            ((Element) records.getChildren("record").get(0)).getChildText("uuid"));
    }

    @Test
    public void siblingsOfTheRecordsAreLeftAlone() throws Exception {
        // The controller appends a <format> element beside the records.
        Element records = new Element("metadata");
        records.addContent(record("no-cdif", "iso19139"));
        records.addContent(new Element("format").setText("cdif"));

        invokeDrop(records, "cdif");

        assertEquals(0, records.getChildren("record").size());
        assertEquals("cdif", records.getChildText("format"));
    }

    private void invokeDrop(Element records, String format) throws Exception {
        java.lang.reflect.Method drop = SitemapApi.class.getDeclaredMethod(
            "dropRecordsWithoutFormatter", Element.class, String.class);
        drop.setAccessible(true);
        drop.invoke(api, records, format);
    }

    private Element record(String uuid, String schemaId) {
        return new Element("record")
            .addContent(new Element("uuid").setText(uuid))
            .addContent(new Element("changedate").setText("2026-11-25T09:30:00"))
            .addContent(new Element("schemaid").setText(schemaId));
    }
}
