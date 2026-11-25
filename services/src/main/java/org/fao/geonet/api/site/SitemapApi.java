/*
 * Copyright (C) 2001-2023 Food and Agriculture Organization of the
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

import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.fao.geonet.NodeInfo;
import org.fao.geonet.api.ApiParams;
import org.fao.geonet.domain.*;
import org.fao.geonet.exceptions.SitemapDocumentNotFoundEx;
import org.fao.geonet.kernel.GeonetworkDataDirectory;
import org.fao.geonet.kernel.SchemaManager;
import org.fao.geonet.kernel.setting.SettingManager;
import org.fao.geonet.repository.MetadataRepository;
import org.fao.geonet.repository.OperationAllowedRepository;
import org.fao.geonet.repository.specification.MetadataSpecs;
import org.fao.geonet.repository.specification.OperationAllowedSpecs;
import org.fao.geonet.utils.Xml;
import org.jdom.Element;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.fao.geonet.api.ApiParams.API_CLASS_CATALOG_TAG;
import static org.fao.geonet.api.records.formatters.FormatterConstants.SCHEMA_PLUGIN_FORMATTER_DIR;
import static org.fao.geonet.api.records.formatters.FormatterConstants.VIEW_XSL_FILENAME;

@RequestMapping(value = {
    "/{portal}/api"
})
@Tag(name = API_CLASS_CATALOG_TAG,
    description = ApiParams.API_CLASS_CATALOG_OPS)
@Controller("sitemap")
public class SitemapApi {
    private static final String FORMAT_XML = "xml";
    private static final String FORMAT_HTML = "html";
    private static final String FORMAT_CDIF = "cdif";
    private static final String FORMAT_DDE = "dde";

    // One sitemap is one serialisation. The sitemaps.org 0.9 schema allows only
    // loc, lastmod, changefreq and priority inside <url>, with no element for
    // the format of what loc points at, so a catalogue offering several
    // serialisations publishes one sitemap per format rather than annotating a
    // single one. Every value here other than html names a formatter, and the
    // stylesheet builds .../formatters/<format> from it.
    private static final Set<String> SUPPORTED_FORMATS =
        Collections.unmodifiableSet(new LinkedHashSet<>(
            Arrays.asList(FORMAT_HTML, FORMAT_XML, FORMAT_CDIF, FORMAT_DDE)));

    // Of those, the ones served by a schema plugin's formatter directory, so
    // they exist only for the schemas that provide them. xml is not one: it is
    // served by the records API itself and works for every schema.
    private static final Set<String> SCHEMA_FORMATTER_FORMATS =
        Collections.unmodifiableSet(new LinkedHashSet<>(
            Arrays.asList(FORMAT_CDIF, FORMAT_DDE)));

    // Max. items in page defined in spec
    private static final int MAX_ITEMS_PER_PAGE = 2500;

    @Autowired
    SettingManager settingManager;

    @Autowired
    NodeInfo node;

    @Autowired
    OperationAllowedRepository operationAllowedRepository;

    @Autowired
    MetadataRepository metadataRepository;

    @Autowired
    GeonetworkDataDirectory dataDirectory;

    @Autowired
    SchemaManager schemaManager;


    @io.swagger.v3.oas.annotations.Operation(
        summary = "robots.txt",
        description = "")
    @RequestMapping(
        path = "/robots.txt",
        method = RequestMethod.GET)
    @ResponseStatus(HttpStatus.OK)
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "robots.txt file for SEO.")
    })
    public void getRobotsText(HttpServletRequest request, HttpServletResponse response) throws IOException {
        StringBuilder content = new StringBuilder(256);
        String contextPath = request.getContextPath();
        content.append("User-agent: *\n");
        content.append("Disallow: ").append(contextPath).append("/catalog/\n");
        content.append("Disallow: ").append(contextPath).append("/static/\n");
        content.append("Sitemap: ").append(settingManager.getNodeURL()).append("api/sitemap\n");
        content.append("Sitemap: ").append(settingManager.getNodeURL()).append("api/sitemap?format=rdf");
        response.setHeader(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_PLAIN_VALUE);
        response.getWriter().append(content);
    }

    @io.swagger.v3.oas.annotations.Operation(
        summary = "Get sitemap",
        description = "")
    @RequestMapping(
        path = "/sitemap",
        method = RequestMethod.GET)
    @ResponseStatus(HttpStatus.OK)
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Site map.")
    })
    public void getSitemap(
        @Parameter(
            description = "Format (xml or html).",
            required = false
        )
        @RequestParam(
            required = false,
            defaultValue = FORMAT_HTML
        )
        String format,
        @Parameter(
            description = "page.",
            required = false
        )
        @RequestParam(
            required = false,
            defaultValue = "0"
        )
        Integer doc,
        @Parameter(hidden = true)
        HttpServletResponse response
    ) throws Exception {
        format = normalizeFormat(format);

        int allGroup = 1;

        Specification<OperationAllowed> spec = Specification.where(
            OperationAllowedSpecs.hasOperation(ReservedOperation.view));
        spec = spec.and(OperationAllowedSpecs.hasGroupId(allGroup));

        final List<Integer> list = operationAllowedRepository.findAllIds(
            spec,
            OperationAllowedId_.metadataId);

        Sort sortByChangeDateDesc = Sort.by(
            Sort.Direction.DESC,
            Metadata_.dataInfo.getName() + "." + MetadataDataInfo_.changeDate.getName());

        long metadataCount = metadataRepository.count((Specification<Metadata>) MetadataSpecs.hasMetadataIdIn(list));
        long pages = (long) Math.ceil((double) metadataCount / MAX_ITEMS_PER_PAGE);

        Element result;

        if (doc > 0) {
            // Requesting a sitemap specific document
            if (doc <= pages) {
                final PageRequest pageRequest = PageRequest.of(doc - 1, MAX_ITEMS_PER_PAGE, sortByChangeDateDesc);
                result = metadataRepository.findUuidsAndChangeDatesAndSchemaId(list, pageRequest);

                Element formatEl = new Element("format");
                formatEl.setText(format.toLowerCase());
                result.addContent(formatEl);
            } else {
                throw new SitemapDocumentNotFoundEx(doc);
            }
        } else {
            // Request the sitemap (no specific document)
            if (metadataCount <= MAX_ITEMS_PER_PAGE) {
                // Request the full sitemap
                result = metadataRepository.findUuidsAndChangeDatesAndSchemaId(list);

                Element formatEl = new Element("format");
                formatEl.setText(format.toLowerCase());
                result.addContent(formatEl);
            } else {
                // Request the index
                result = new Element("response");

                Element indexDocs = new Element("indexDocs");
                indexDocs.setText(pages + "");
                result.addContent(indexDocs);

                Element changeDate = new Element("changeDate");
                changeDate.setText(new ISODate().toString());
                result.addContent(changeDate);
            }
        }
        if (SCHEMA_FORMATTER_FORMATS.contains(format)) {
            dropRecordsWithoutFormatter(result, format);
        }

        Path xslt = dataDirectory.getWebappDir()
            .resolve("xslt/services/sitemap/sitemap.xsl");
        Element root = new Element("root");
        Element requestElt = new Element("request");
        requestElt.addContent(new Element("format").setText(format));
        root.addContent(requestElt);
        root.addContent(result);

        response.setHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_XML_VALUE);
        Xml.transform(root, xslt, response.getOutputStream());
    }

    /**
     * Drops the records whose schema has no formatter of this name. A
     * catalogue normally holds a mixture -- iso19115-3.2018 provides cdif and
     * dde, iso19139 provides neither -- and a URL the formatter cannot render
     * answers with an error that a harvester walking the sitemap cannot tell
     * from a real failure. Omitting the record says truthfully that it is not
     * available in that serialisation.
     *
     * <p>Paging happens before this, so a page can come back shorter than
     * MAX_ITEMS_PER_PAGE and the index's page count is of unfiltered records.
     * The index stays an upper bound, which a sitemap index is allowed to be.
     */
    private void dropRecordsWithoutFormatter(Element records, String format) {
        Map<String, Boolean> schemaHasFormatter = new HashMap<>();
        List<Element> unavailable = new ArrayList<>();

        for (Object child : records.getChildren("record")) {
            Element record = (Element) child;
            String schema = record.getChildText("schemaid");
            if (!schemaHasFormatter.computeIfAbsent(
                schema, s -> hasFormatter(s, format))) {
                unavailable.add(record);
            }
        }

        unavailable.forEach(records::removeContent);
    }

    /**
     * Mirrors how AbstractFormatService.getAndVerifyFormatDir resolves a
     * formatter: the schema plugin's own formatter directory first, then the
     * catalogue-wide one in the data directory, which applies to every schema.
     * A directory counts only when it holds view.xsl, which is what makes it a
     * format bundle rather than an empty or half-removed folder.
     */
    private boolean hasFormatter(String schema, String format) {
        if (schema != null) {
            try {
                Path schemaFormatter = schemaManager.getSchemaDir(schema)
                    .resolve(SCHEMA_PLUGIN_FORMATTER_DIR)
                    .resolve(format);
                if (isFormatBundle(schemaFormatter)) {
                    return true;
                }
            } catch (IllegalArgumentException schemaNotRegistered) {
                // A record whose schema plugin is no longer installed. The
                // shared formatter below may still render it.
            }
        }
        return isFormatBundle(dataDirectory.getFormatterDir().resolve(format));
    }

    private boolean isFormatBundle(Path candidate) {
        return Files.isDirectory(candidate)
            && Files.exists(candidate.resolve(VIEW_XSL_FILENAME));
    }

    /**
     * An unsupported or absent format falls back to html, as it always has.
     * Lower-cased because the stylesheet compares the value literally, so an
     * uppercase request would otherwise silently fall through to html.
     */
    static String normalizeFormat(String format) {
        if (format == null) {
            return FORMAT_HTML;
        }
        String requested = format.toLowerCase();
        return SUPPORTED_FORMATS.contains(requested) ? requested : FORMAT_HTML;
    }
}
