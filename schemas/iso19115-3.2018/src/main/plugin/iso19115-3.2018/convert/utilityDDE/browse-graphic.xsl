<?xml version="1.0" encoding="UTF-8"?>
<!--
  Reading a thumbnail URL out of mcc:MD_BrowseGraphic.

  ISO 19115-3 offers four places a browse graphic's location can end up, and
  real records use all of them:

    mcc:linkage/cit:CI_OnlineResource/cit:linkage/gco:CharacterString
        The correct one. cit:linkage is a URL by definition.

    mcc:fileName/gcx:FileName/@src
        Correct for gcx:FileName, whose text content is the human-readable
        label and whose @src is the URI of the actual file.

    mcc:fileName/gcx:FileName
        Bad practice: the URL written as the label, leaving @src absent.

    mcc:fileName/gco:CharacterString
        Also bad practice, and the most common of the four. fileName is
        documented as "name or URI", so a URL here is tolerated rather than
        wrong, but it conflates the file's name with its location.

  So a reader cannot pick one location: it has to look in all of them for
  something that is actually a URL. That is what went wrong before this file
  existed. index-fields/index.xsl read fileName unconditionally and treated
  whatever it found as a URL, so a record whose fileName holds a caption, with
  the real URL sitting in mcc:linkage, indexed the caption. The browser then
  resolved it against the page, giving requests like

    https://host/geonetwork/srv/eng/Quick%20view%20lithostratigraphic%20map%20of%20Arizona

  and a card with an empty image box. Meanwhile formatter/cdif and the DDE
  converter each had their own partial version of the same logic, agreeing with
  neither the indexer nor each other. Hence one implementation, shared.

  A value counts as a URL only when it carries a scheme, matching the test
  formatter/cdif already used. Root-relative paths are deliberately not
  accepted: nothing in the corpus uses them, and "/images/map.png" is not
  reliably distinguishable from a caption that happens to start with a slash.
  A graphic that yields no URL yields the empty string, and every caller skips
  it rather than emitting a link it knows is broken.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:gco="http://standards.iso.org/iso/19115/-3/gco/1.0"
                xmlns:gcx="http://standards.iso.org/iso/19115/-3/gcx/1.0"
                xmlns:cit="http://standards.iso.org/iso/19115/-3/cit/2.0"
                xmlns:mcc="http://standards.iso.org/iso/19115/-3/mcc/1.0"
                xmlns:dde-bg="https://www.ddeworld.org/xslt/browse-graphic"
                exclude-result-prefixes="#all">

  <!-- Scheme-qualified, e.g. http://host/x.png or ftp://host/x.png. -->
  <xsl:function name="dde-bg:is-url" as="xs:boolean">
    <xsl:param name="candidate" as="xs:string?"/>
    <xsl:sequence
      select="matches(normalize-space($candidate), '^[a-zA-Z][a-zA-Z0-9+.-]*://.+')"/>
  </xsl:function>

  <!--
    The graphic's URL, or '' when none of the four locations holds one.
    Ordered most to least authoritative, so a record carrying both a proper
    linkage and a legacy URL in fileName uses the linkage.
  -->
  <xsl:function name="dde-bg:url" as="xs:string">
    <xsl:param name="graphic" as="element()?"/>
    <xsl:variable name="candidates" as="xs:string*"
                  select="(normalize-space($graphic/mcc:linkage/*/cit:linkage/gco:CharacterString),
                           normalize-space($graphic/mcc:fileName/gcx:FileName/@src),
                           normalize-space($graphic/mcc:fileName/gcx:FileName),
                           normalize-space($graphic/mcc:fileName/gco:CharacterString))"/>
    <xsl:sequence select="($candidates[dde-bg:is-url(.)], '')[1]"/>
  </xsl:function>

  <!--
    The graphic's caption: the fileName text when it is a label rather than a
    URL. Returns '' when fileName holds the URL, since repeating the URL as a
    caption tells a reader nothing. fileDescription is a separate element and
    callers read it directly.
  -->
  <xsl:function name="dde-bg:label" as="xs:string">
    <xsl:param name="graphic" as="element()?"/>
    <xsl:variable name="candidates" as="xs:string*"
                  select="(normalize-space($graphic/mcc:fileName/gcx:FileName),
                           normalize-space($graphic/mcc:fileName/gco:CharacterString))"/>
    <xsl:sequence select="($candidates[. != '' and not(dde-bg:is-url(.))], '')[1]"/>
  </xsl:function>

</xsl:stylesheet>
