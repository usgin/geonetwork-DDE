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

package org.fao.geonet.xslt.services;

import org.fao.geonet.ApplicationContextHolder;
import org.fao.geonet.kernel.setting.SettingManager;
import org.fao.geonet.utils.TransformerFactoryFactory;
import org.fao.geonet.utils.Xml;
import org.jdom.Element;
import org.jdom.Namespace;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.springframework.context.support.GenericApplicationContext;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * Runs the real sitemap stylesheet, because the format a sitemap advertises is
 * only visible in the URLs it emits. The stylesheet is driven from the document
 * SitemapApi builds, so the input here mirrors
 * MetadataRepositoryCustomImpl.findUuidsAndChangeDatesAndSchemaId.
 */
public class SitemapXslTest {

    private static final Namespace SITEMAP =
        Namespace.getNamespace("http://www.sitemaps.org/schemas/sitemap/0.9");

    private static final String NODE_URL = "http://localhost:8080/geonetwork/srv/";

    private static final Path SITEMAP_XSL =
        Paths.get("src/main/webapp/xslt/services/sitemap/sitemap.xsl");

    @Before
    public void setUp() throws Exception {
        TransformerFactoryFactory.init("net.sf.saxon.TransformerFactoryImpl");

        // base-variables.xsl resolves $nodeUrl through XslUtil.getSettingValue,
        // which reaches for the SettingManager bean. Overriding the one method
        // the stylesheet needs avoids standing up a catalogue.
        SettingManager settingManager = new SettingManager() {
            @Override
            public String getNodeURL() {
                return NODE_URL;
            }
        };

        GenericApplicationContext context = new GenericApplicationContext();
        context.refresh();
        context.getBeanFactory().registerSingleton("settingManager", settingManager);
        ApplicationContextHolder.set(context);
    }

    @After
    public void tearDown() {
        ApplicationContextHolder.clear();
    }

    @Test
    public void cdifPointsAtTheCdifFormatter() throws Exception {
        assertEquals(NODE_URL + "api/records/" + "e2f1c3a4-0000-4000-8000-000000000001"
                + "/formatters/cdif",
            firstLocation(sitemapFor("cdif")));
    }

    @Test
    public void ddePointsAtTheDdeFormatter() throws Exception {
        assertEquals(NODE_URL + "api/records/" + "e2f1c3a4-0000-4000-8000-000000000001"
                + "/formatters/dde",
            firstLocation(sitemapFor("dde")));
    }

    @Test
    public void xmlStillPointsAtTheXmlFormatter() throws Exception {
        assertEquals(NODE_URL + "api/records/" + "e2f1c3a4-0000-4000-8000-000000000001"
                + "/formatters/xml",
            firstLocation(sitemapFor("xml")));
    }

    @Test
    public void everyRecordIsListedOnceWithItsChangeDate() throws Exception {
        Element urlset = sitemapFor("cdif");
        List<?> urls = urlset.getChildren("url", SITEMAP);

        assertEquals(2, urls.size());
        assertEquals("2026-11-25",
            ((Element) urls.get(0)).getChildText("lastmod", SITEMAP));
    }

    @Test
    public void theIndexCarriesTheFormatToEachPage() throws Exception {
        // Above 2500 records the API answers with an index instead of a flat
        // list, which is what this catalogue's size means in practice. Each
        // entry has to keep the format or page 2 reverts to html.
        Element root = new Element("root");
        root.addContent(new Element("request")
            .addContent(new Element("format").setText("cdif")));
        root.addContent(new Element("response")
            .addContent(new Element("indexDocs").setText("2"))
            .addContent(new Element("changeDate").setText("2026-11-25T12:00:00")));

        Element index = Xml.transform(root, SITEMAP_XSL);
        List<?> pages = index.getChildren("sitemap", SITEMAP);

        assertEquals(2, pages.size());
        for (int page = 1; page <= pages.size(); page++) {
            String location = ((Element) pages.get(page - 1)).getChildText("loc", SITEMAP);
            assertEquals(NODE_URL + "api/sitemap?format=cdif&doc=" + page, location);
            assertTrue("the index must name a page, not the index itself",
                location.contains("doc="));
        }
    }

    private Element sitemapFor(String format) throws Exception {
        Element root = new Element("root");
        root.addContent(new Element("request")
            .addContent(new Element("format").setText(format)));

        Element metadata = new Element("metadata");
        metadata.addContent(record("e2f1c3a4-0000-4000-8000-000000000001", "2026-11-25T09:30:00"));
        metadata.addContent(record("e2f1c3a4-0000-4000-8000-000000000002", "2026-11-24T18:05:00"));
        root.addContent(metadata);

        return Xml.transform(root, SITEMAP_XSL);
    }

    private Element record(String uuid, String changeDate) {
        return new Element("record")
            .addContent(new Element("uuid").setText(uuid))
            .addContent(new Element("changedate").setText(changeDate))
            .addContent(new Element("schemaid").setText("iso19115-3.2018"));
    }

    private String firstLocation(Element urlset) {
        return ((Element) urlset.getChildren("url", SITEMAP).get(0))
            .getChildText("loc", SITEMAP);
    }
}
