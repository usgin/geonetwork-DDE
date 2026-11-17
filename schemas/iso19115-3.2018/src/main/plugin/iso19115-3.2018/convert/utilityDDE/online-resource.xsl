<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:cit="http://standards.iso.org/iso/19115/-3/cit/2.0"
                xmlns:gco="http://standards.iso.org/iso/19115/-3/gco/1.0"
                xmlns:dde-or="https://www.ddeworld.org/xslt/online-resource"
                exclude-result-prefixes="#all">

  <!--
    Classify a cit:CI_OnlineResource by what a consumer can actually do with it.

    ISO 19115-3 has no element that says "this link is a service endpoint" or "this link
    is one member of a package". cit:protocol is supposed to carry the first, but in
    harvested data it very often does not: every link in the Geoscience Australia
    Thin Sections Collection is tagged as an ordinary web link, including a WFS
    GetFeature request. cit:function is no better. It is absent on that whole record,
    set to download on a collection of reports, and set to information on a data
    package whose members are separate datasets, so it orders links by neither kind
    nor role.

    What does survive harvesting is the URL and the link name, so that is what these
    functions read. They are deliberately only two tests, applied in a fixed order by
    the caller: a service endpoint first, then a member of a package. Anything matching
    neither is a page for a human to open, which is the common case.
  -->

  <!--
    The service type, as an OGC: token, or '' when this is not a service endpoint.

    Returning the type rather than a boolean is what lets the caller fill
    schema:serviceType, which CDIF requires on every schema:WebAPI distribution.
  -->
  <xsl:function name="dde-or:service-type" as="xs:string">
    <xsl:param name="ol" as="element()?"/>
    <xsl:variable name="url" select="string(($ol/cit:linkage/gco:CharacterString)[1])"/>
    <xsl:variable name="protocol" select="string(($ol/cit:protocol/gco:CharacterString)[1])"/>
    <xsl:variable name="name" select="string(($ol/cit:name/gco:CharacterString)[1])"/>
    <xsl:variable name="type">
      <xsl:choose>
        <!-- A protocol that names the service outright is believed. -->
        <xsl:when test="starts-with(upper-case(normalize-space($protocol)), 'OGC:')">
          <xsl:value-of select="upper-case(normalize-space($protocol))"/>
        </xsl:when>
        <!--
          Otherwise look for an OGC service= parameter in the query string, then for the
          service named in the link label. The label is what identifies the two
          Thin Sections endpoints, whose URLs are opaque persistent identifiers.
        -->
        <xsl:when test="matches($url, '[?&amp;]service=wfs([&amp;]|$)', 'i')
                        or matches($name, 'web\s+feature\s+service', 'i')">OGC:WFS</xsl:when>
        <xsl:when test="matches($url, '[?&amp;]service=wms([&amp;]|$)', 'i')
                        or matches($name, 'web\s+map\s+service', 'i')">OGC:WMS</xsl:when>
        <xsl:when test="matches($url, '[?&amp;]service=wmts([&amp;]|$)', 'i')
                        or matches($name, 'web\s+map\s+tile\s+service', 'i')">OGC:WMTS</xsl:when>
        <xsl:when test="matches($url, '[?&amp;]service=wcs([&amp;]|$)', 'i')
                        or matches($name, 'web\s+coverage\s+service', 'i')">OGC:WCS</xsl:when>
        <xsl:when test="matches($url, '[?&amp;]service=csw([&amp;]|$)', 'i')
                        or matches($name, 'catalogue?\s+service', 'i')">OGC:CSW</xsl:when>
        <xsl:when test="matches($name, 'web\s+processing\s+service', 'i')">OGC:WPS</xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="normalize-space($type)"/>
  </xsl:function>

  <xsl:function name="dde-or:is-service" as="xs:boolean">
    <xsl:param name="ol" as="element()?"/>
    <xsl:sequence select="dde-or:service-type($ol) != ''"/>
  </xsl:function>

  <!--
    Whether the link addresses one resource by a persistent identifier, which is what
    distinguishes a member of a package from a page to browse. On the collections in
    this catalogue the members resolve through pid.geoscience.gov.au/dataset/..., while
    the browse links go to portals, THREDDS catalog.html pages and catalogue searches.

    This is a heuristic and the only one here that looks at a host, so it is worth being
    explicit about why: CDIF distinguishes a part of a package from an access point, and
    nothing in ISO 19115-3 as harvested marks the difference. The caller confines it to
    records whose resourceScope is collection, because a /dataset/ link on an ordinary
    dataset record is one of its distributions, not a part of it.
  -->
  <xsl:function name="dde-or:is-persistent-id" as="xs:boolean">
    <xsl:param name="ol" as="element()?"/>
    <xsl:variable name="url" select="normalize-space(string(($ol/cit:linkage/gco:CharacterString)[1]))"/>
    <xsl:sequence select="$url != ''
                          and (matches($url, '^https?://pid\.', 'i')
                               or contains($url, '/dataset/')
                               or matches($url, '^https?://(dx\.)?doi\.org/', 'i')
                               or matches($url, '^https?://hdl\.handle\.net/', 'i')
                               or matches($url, '^https?://w3id\.org/', 'i')
                               or matches($url, '^https?://purl\.org/', 'i'))"/>
  </xsl:function>

</xsl:stylesheet>
