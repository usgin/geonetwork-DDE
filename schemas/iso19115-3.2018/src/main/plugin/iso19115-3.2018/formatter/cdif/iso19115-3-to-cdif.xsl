<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:cat="http://standards.iso.org/iso/19115/-3/cat/1.0"
                xmlns:cit="http://standards.iso.org/iso/19115/-3/cit/2.0"
                xmlns:gcx="http://standards.iso.org/iso/19115/-3/gcx/1.0"
                xmlns:gex="http://standards.iso.org/iso/19115/-3/gex/1.0"
                xmlns:lan="http://standards.iso.org/iso/19115/-3/lan/1.0"
                xmlns:srv="http://standards.iso.org/iso/19115/-3/srv/2.0"
                xmlns:mcc="http://standards.iso.org/iso/19115/-3/mcc/1.0"
                xmlns:mco="http://standards.iso.org/iso/19115/-3/mco/1.0"
                xmlns:mdb="http://standards.iso.org/iso/19115/-3/mdb/2.0"
                xmlns:mrd="http://standards.iso.org/iso/19115/-3/mrd/1.0"
                xmlns:mri="http://standards.iso.org/iso/19115/-3/mri/1.0"
                xmlns:mrl="http://standards.iso.org/iso/19115/-3/mrl/2.0"
                xmlns:mrc="http://standards.iso.org/iso/19115/-3/mrc/2.0"
                xmlns:mdq="http://standards.iso.org/iso/19157/-2/mdq/1.0"
                xmlns:gco="http://standards.iso.org/iso/19115/-3/gco/1.0"
                xmlns:gfc="http://standards.iso.org/iso/19110/gfc/1.1"
                xmlns:gml="http://www.opengis.net/gml/3.2"
                xmlns:xlink="http://www.w3.org/1999/xlink"
                xmlns:util="java:org.fao.geonet.util.XslUtil"
                xmlns:gn="http://www.fao.org/geonetwork"
                exclude-result-prefixes="#all">
  <!--
    Convert ISO 19115-3:2018 metadata to CDIF-compliant JSON-LD.

    This is the reverse of convert/fromJsonCdif.xsl. It produces expanded
    JSON-LD text which is then framed via util:frameCdifJsonLd() using the
    same cdif-frame.jsonld that the harvester uses.

    The text-mode JSON generation pattern follows the existing
    formatter/jsonld/iso19115-3.2018-to-jsonld.xsl.
  -->

  <xsl:output method="text"/>

  <xsl:param name="baseUrl" select="util:getSettingValue('nodeUrl')"/>

  <!-- ================================================================
       Main entry template
       ================================================================ -->
  <xsl:template name="toCdifJsonLd"
                mode="toCdifJsonLd" match="mdb:MD_Metadata">

    <xsl:variable name="uuid"
                  select="mdb:metadataIdentifier[1]/*/mcc:code/gco:CharacterString/text()"/>
    <xsl:variable name="recordUrl"
                  select="concat($baseUrl, 'api/records/', $uuid)"/>

    <!-- Build the flat/expanded JSON-LD as a string -->
    <xsl:variable name="flatJsonLd">
{
  <xsl:call-template name="cdif-context"/>

  "@type": ["schema:Dataset"],
  "@id": "<xsl:value-of select="util:escapeForJson($recordUrl)"/>",

  <xsl:call-template name="cdif-basic-properties">
    <xsl:with-param name="recordUrl" select="$recordUrl"/>
  </xsl:call-template>

  <xsl:call-template name="cdif-agents"/>

  <xsl:call-template name="cdif-keywords"/>

  <xsl:call-template name="cdif-constraints"/>

  <xsl:call-template name="cdif-spatial"/>

  <xsl:call-template name="cdif-temporal"/>

  <xsl:call-template name="cdif-distribution"/>

  <xsl:call-template name="cdif-variables"/>

  <xsl:call-template name="cdif-provenance"/>

  <xsl:call-template name="cdif-quality"/>

  <xsl:call-template name="cdif-supplemental"/>

  <xsl:call-template name="cdif-related"/>

  <xsl:call-template name="cdif-subjectOf">
    <xsl:with-param name="recordUrl" select="$recordUrl"/>
  </xsl:call-template>

  "schema:url": "<xsl:value-of select="util:escapeForJson($recordUrl)"/>"
}
    </xsl:variable>

    <!-- Frame using Java utility, or return flat JSON-LD on failure -->
    <xsl:value-of select="util:frameCdifJsonLd($flatJsonLd)"/>
  </xsl:template>


  <!-- ================================================================
       @context block (same prefixes as cdif-frame.jsonld)
       ================================================================ -->
  <xsl:template name="cdif-context">
  "@context": {
    "schema": "http://schema.org/",
    "dcterms": "http://purl.org/dc/terms/",
    "prov": "http://www.w3.org/ns/prov#",
    "dqv": "http://www.w3.org/ns/dqv#",
    "geosparql": "http://www.opengis.net/ont/geosparql#",
    "spdx": "http://spdx.org/rdf/terms#",
    "time": "http://www.w3.org/2006/time#",
    "sf": "http://www.opengis.net/ont/sf#",
    "cdi": "http://ddialliance.org/Specification/DDI-CDI/1.0/RDF/",
    "csvw": "http://www.w3.org/ns/csvw#",
    "ada": "https://ada.astromat.org/metadata/",
    "xas": "https://ada.astromat.org/metadata/xas/",
    "nxs": "https://manual.nexusformat.org/classes/"
  },
  </xsl:template>


  <!-- ================================================================
       Basic properties: name, description, identifier, sameAs, dates,
       version, language
       ================================================================ -->
  <xsl:template name="cdif-basic-properties">
    <xsl:param name="recordUrl"/>

    <xsl:variable name="identInfo" select="mdb:identificationInfo[1]/*"/>
    <xsl:variable name="citation" select="$identInfo/mri:citation/*"/>

    <!-- name -->
    <xsl:if test="$citation/cit:title/gco:CharacterString[normalize-space() != '']">
  "schema:name": "<xsl:value-of select="util:escapeForJson($citation/cit:title/gco:CharacterString)"/>",
    </xsl:if>

    <!-- description -->
    <xsl:if test="$identInfo/mri:abstract/gco:CharacterString[normalize-space() != '']">
  "schema:description": "<xsl:value-of select="util:escapeForJson($identInfo/mri:abstract/gco:CharacterString)"/>",
    </xsl:if>

    <!-- identifier (first non-sameAs) -->
    <xsl:variable name="primaryId"
                  select="$citation/cit:identifier/mcc:MD_Identifier[not(mcc:codeSpace/gco:CharacterString = 'sameAs')][1]"/>
    <xsl:if test="$primaryId/mcc:code/gco:CharacterString[normalize-space() != '']">
      <xsl:choose>
        <xsl:when test="$primaryId/mcc:codeSpace/gco:CharacterString[normalize-space() != '']">
  "schema:identifier": {
    "@type": "schema:PropertyValue",
    "schema:propertyID": "<xsl:value-of select="util:escapeForJson($primaryId/mcc:codeSpace/gco:CharacterString)"/>",
    "schema:value": "<xsl:value-of select="util:escapeForJson($primaryId/mcc:code/gco:CharacterString)"/>"
  },
        </xsl:when>
        <xsl:otherwise>
  "schema:identifier": "<xsl:value-of select="util:escapeForJson($primaryId/mcc:code/gco:CharacterString)"/>",
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>

    <!-- sameAs -->
    <xsl:variable name="sameAsIds"
                  select="$citation/cit:identifier/mcc:MD_Identifier[mcc:codeSpace/gco:CharacterString = 'sameAs']"/>
    <xsl:if test="$sameAsIds">
  "schema:sameAs": [<xsl:for-each select="$sameAsIds">
    {"@id": "<xsl:value-of select="util:escapeForJson(mcc:code/gco:CharacterString)"/>"}<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>

    <!-- datePublished (resource publication date) -->
    <xsl:variable name="pubDate"
                  select="$citation/cit:date[*/cit:dateType/*/@codeListValue='publication'][1]/*/cit:date/(gco:Date|gco:DateTime)"/>
    <xsl:if test="$pubDate[normalize-space() != '']">
  "schema:datePublished": "<xsl:value-of select="$pubDate"/>",
    </xsl:if>

    <!-- dateModified (required by CDIF schema; use revision date, fallback to creation or publication) -->
    <xsl:variable name="revDate"
                  select="mdb:dateInfo[*/cit:dateType/*/@codeListValue='revision'][1]/*/cit:date/(gco:Date|gco:DateTime)"/>
    <xsl:variable name="createDate"
                  select="mdb:dateInfo[*/cit:dateType/*/@codeListValue='creation'][1]/*/cit:date/(gco:Date|gco:DateTime)"/>
    <xsl:variable name="dateModified">
      <xsl:choose>
        <xsl:when test="$revDate[normalize-space() != '']"><xsl:value-of select="$revDate"/></xsl:when>
        <xsl:when test="$pubDate[normalize-space() != '']"><xsl:value-of select="$pubDate"/></xsl:when>
        <xsl:when test="$createDate[normalize-space() != '']"><xsl:value-of select="$createDate"/></xsl:when>
        <xsl:otherwise>unknown</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
  "schema:dateModified": "<xsl:value-of select="$dateModified"/>",

    <!-- version -->
    <xsl:if test="$citation/cit:edition/gco:CharacterString[normalize-space() != '']">
  "schema:version": "<xsl:value-of select="util:escapeForJson($citation/cit:edition/gco:CharacterString)"/>",
    </xsl:if>

    <!-- inLanguage -->
    <xsl:variable name="langCode3"
                  select="mdb:defaultLocale/*/lan:language/*/@codeListValue"/>
    <xsl:if test="$langCode3 != ''">
      <xsl:variable name="langCode2">
        <xsl:call-template name="reverseLanguageCode">
          <xsl:with-param name="code3" select="$langCode3"/>
        </xsl:call-template>
      </xsl:variable>
  "schema:inLanguage": "<xsl:value-of select="$langCode2"/>",
    </xsl:if>

  </xsl:template>


  <!-- ================================================================
       Agents: creator, publisher, contributor, provider
       ================================================================ -->
  <xsl:template name="cdif-agents">
    <xsl:variable name="citation" select="mdb:identificationInfo[1]/*/mri:citation/*"/>

    <!-- Creator (authors) -->
    <xsl:variable name="authors"
                  select="$citation/cit:citedResponsibleParty[*/cit:role/*/@codeListValue='author']"/>
    <xsl:if test="$authors">
  "schema:creator": {"@list": [<xsl:for-each select="$authors">
    <xsl:call-template name="buildAgentJsonLd">
      <xsl:with-param name="resp" select="*"/>
      <xsl:with-param name="agentIndex" select="concat('creator-', position())"/>
    </xsl:call-template><xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>]},
    </xsl:if>

    <!-- Publisher -->
    <xsl:variable name="publishers"
                  select="$citation/cit:citedResponsibleParty[*/cit:role/*/@codeListValue='publisher']"/>
    <xsl:if test="$publishers">
  "schema:publisher": <xsl:call-template name="buildAgentJsonLd">
      <xsl:with-param name="resp" select="$publishers[1]/*"/>
      <xsl:with-param name="agentIndex" select="'publisher'"/>
    </xsl:call-template>,
    </xsl:if>

    <!-- Contributors (all cited roles except author and publisher) -->
    <xsl:variable name="contributors"
                  select="$citation/cit:citedResponsibleParty[*/cit:role/*/@codeListValue != 'author'
                          and */cit:role/*/@codeListValue != 'publisher']"/>
    <xsl:if test="$contributors">
  "schema:contributor": [<xsl:for-each select="$contributors">
    <xsl:variable name="roleCode" select="*/cit:role/*/@codeListValue"/>
    <xsl:variable name="roleName">
      <xsl:call-template name="reverseRoleCode">
        <xsl:with-param name="code" select="$roleCode"/>
      </xsl:call-template>
    </xsl:variable>
    {
      "@type": "schema:Role",
      "schema:roleName": "<xsl:value-of select="$roleName"/>",
      "schema:contributor": <xsl:call-template name="buildAgentJsonLd">
        <xsl:with-param name="resp" select="*"/>
        <xsl:with-param name="agentIndex" select="concat('contributor-', position())"/>
      </xsl:call-template>
    }<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>

    <!-- Provider (from mdb:contact with role=distributor) -->
    <xsl:variable name="providers"
                  select="mdb:contact[*/cit:role/*/@codeListValue='distributor']"/>
    <xsl:if test="$providers">
  "schema:provider": [<xsl:call-template name="buildAgentJsonLd">
      <xsl:with-param name="resp" select="$providers[1]/*"/>
      <xsl:with-param name="agentIndex" select="'provider'"/>
    </xsl:call-template>],
    </xsl:if>

  </xsl:template>


  <!-- ================================================================
       Keywords
       ================================================================ -->
  <xsl:template name="cdif-keywords">
    <xsl:variable name="allKeywords"
                  select="mdb:identificationInfo/*/mri:descriptiveKeywords/*/mri:keyword/gco:CharacterString[normalize-space() != '']"/>
    <xsl:if test="$allKeywords">
  "schema:keywords": [<xsl:for-each select="$allKeywords">
    "<xsl:value-of select="util:escapeForJson(.)"/>"<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Constraints: license, conditionsOfAccess
       ================================================================ -->
  <xsl:template name="cdif-constraints">
    <xsl:variable name="legalConstraints"
                  select="mdb:identificationInfo/*/mri:resourceConstraints/mco:MD_LegalConstraints"/>

    <!-- License from mco:reference -->
    <xsl:variable name="licRef" select="$legalConstraints/mco:reference/cit:CI_Citation"/>
    <xsl:if test="$licRef">
      <xsl:variable name="licName" select="$licRef[1]/cit:title/gco:CharacterString"/>
      <xsl:variable name="licUrl" select="$licRef[1]/cit:onlineResource/*/cit:linkage/gco:CharacterString"/>
      <xsl:choose>
        <xsl:when test="$licUrl[normalize-space() != ''] and $licName[normalize-space() != '']">
  "schema:license": [{
    "@type": "schema:CreativeWork",
    "schema:name": "<xsl:value-of select="util:escapeForJson($licName)"/>",
    "schema:url": "<xsl:value-of select="util:escapeForJson($licUrl)"/>"
  }],
        </xsl:when>
        <xsl:when test="$licUrl[normalize-space() != '']">
  "schema:license": ["<xsl:value-of select="util:escapeForJson($licUrl)"/>"],
        </xsl:when>
        <xsl:when test="$licName[normalize-space() != '']">
  "schema:license": ["<xsl:value-of select="util:escapeForJson($licName)"/>"],
        </xsl:when>
      </xsl:choose>
    </xsl:if>

    <!-- conditionsOfAccess from otherConstraints (when no reference) -->
    <xsl:if test="not($licRef) and $legalConstraints/mco:otherConstraints/gco:CharacterString[normalize-space() != '']">
  "schema:conditionsOfAccess": ["<xsl:value-of select="util:escapeForJson($legalConstraints[1]/mco:otherConstraints/gco:CharacterString)"/>"],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Spatial coverage
       ================================================================ -->
  <xsl:template name="cdif-spatial">
    <xsl:variable name="bboxes"
                  select="mdb:identificationInfo/*/mri:extent/*/gex:geographicElement/gex:EX_GeographicBoundingBox"/>
    <xsl:if test="$bboxes">
  "schema:spatialCoverage": [<xsl:for-each select="$bboxes">
    {
      "@type": "schema:Place",
      "schema:geo": {
        "@type": "schema:GeoShape",
        "schema:box": "<xsl:value-of select="string-join((
          gex:southBoundLatitude/gco:Decimal,
          gex:westBoundLongitude/gco:Decimal,
          gex:northBoundLatitude/gco:Decimal,
          gex:eastBoundLongitude/gco:Decimal), ' ')"/>"
      }
    }<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Temporal coverage
       ================================================================ -->
  <xsl:template name="cdif-temporal">
    <xsl:variable name="temporals"
                  select="mdb:identificationInfo/*/mri:extent/*/gex:temporalElement/*/gex:extent"/>
    <xsl:if test="$temporals">
  "schema:temporalCoverage": [<xsl:for-each select="$temporals">
      <xsl:choose>
        <!-- Geologic time: gml:TimeInstant with frame attribute -->
        <xsl:when test=".//gml:timePosition[@frame]">
          <xsl:variable name="beginVal" select="(.//gml:timePosition[@frame])[1]"/>
          <xsl:variable name="endVal" select="(.//gml:timePosition[@frame])[2]"/>
          <xsl:variable name="trs" select="(.//gml:timePosition/@frame)[1]"/>
    {
      "@type": "time:ProperInterval",
      <xsl:if test="$beginVal[normalize-space() != '']">
      "time:hasBeginning": {
        "@type": "time:Instant",
        "time:inTimePosition": {
          "@type": "time:TimePosition",
          "time:hasTRS": {"@id": "<xsl:value-of select="util:escapeForJson(string($trs))"/>"},
          "schema:value": <xsl:value-of select="$beginVal"/>
        }
      },
      </xsl:if>
      <xsl:if test="$endVal[normalize-space() != '']">
      "time:hasEnd": {
        "@type": "time:Instant",
        "time:inTimePosition": {
          "@type": "time:TimePosition",
          "time:hasTRS": {"@id": "<xsl:value-of select="util:escapeForJson(string($trs))"/>"},
          "schema:value": <xsl:value-of select="$endVal"/>
        }
      },
      </xsl:if>
      "@id": "_:temporal-<xsl:value-of select="position()"/>"
    }</xsl:when>
        <!-- ISO dates: TimePeriod with begin/end -->
        <xsl:when test="gml:TimePeriod">
          <xsl:variable name="begin" select="gml:TimePeriod/gml:beginPosition"/>
          <xsl:variable name="end" select="gml:TimePeriod/gml:endPosition"/>
    "<xsl:value-of select="concat($begin, '/', $end)"/>"</xsl:when>
        <xsl:otherwise>
    "<xsl:value-of select="normalize-space(.)"/>"</xsl:otherwise>
      </xsl:choose>
      <xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Distribution
       ================================================================ -->
  <xsl:template name="cdif-distribution">
    <xsl:variable name="transferOpts"
                  select="mdb:distributionInfo/*/mrd:transferOptions/mrd:MD_DigitalTransferOptions"/>
    <xsl:if test="$transferOpts/mrd:onLine/cit:CI_OnlineResource[cit:linkage/gco:CharacterString[normalize-space() != '']]">
  "schema:distribution": [<xsl:for-each select="$transferOpts">
      <!-- Primary resource (first onLine that is NOT an archive member) -->
      <xsl:variable name="primary"
                    select="mrd:onLine/cit:CI_OnlineResource[
                      not(contains(cit:linkage/gco:CharacterString, 'opengis.net/def/nil'))]"/>
      <xsl:variable name="archiveMembers"
                    select="mrd:onLine/cit:CI_OnlineResource[
                      contains(cit:linkage/gco:CharacterString, 'opengis.net/def/nil')]"/>
      <xsl:for-each select="$primary">
    {
      "@type": ["schema:DataDownload"],
      "schema:contentUrl": "<xsl:value-of select="util:escapeForJson(cit:linkage/gco:CharacterString)"/>"
        <xsl:if test="cit:name/gco:CharacterString[normalize-space() != '']">
      ,"schema:name": "<xsl:value-of select="util:escapeForJson(cit:name/gco:CharacterString)"/>"
        </xsl:if>
        <xsl:if test="cit:description/gco:CharacterString[normalize-space() != '']">
      ,"schema:description": "<xsl:value-of select="util:escapeForJson(cit:description/gco:CharacterString)"/>"
        </xsl:if>
        <xsl:if test="cit:protocol/gco:CharacterString[normalize-space() != '']">
      ,"schema:encodingFormat": ["<xsl:value-of select="util:escapeForJson(cit:protocol/gco:CharacterString)"/>"]
        </xsl:if>
        <xsl:if test="../../mrd:transferSize/gco:Real[normalize-space() != '']">
      ,"schema:contentSize": "<xsl:value-of select="../../mrd:transferSize/gco:Real"/> MB"
        </xsl:if>
        <!-- Archive members as hasPart -->
        <xsl:if test="$archiveMembers">
      ,"schema:hasPart": [<xsl:for-each select="$archiveMembers">
        {
          "@type": ["schema:DataDownload"]
          <xsl:if test="cit:name/gco:CharacterString[normalize-space() != '']">
          ,"schema:name": "<xsl:value-of select="util:escapeForJson(cit:name/gco:CharacterString)"/>"
          </xsl:if>
          <xsl:if test="cit:description/gco:CharacterString[normalize-space() != '']">
          ,"schema:description": "<xsl:value-of select="util:escapeForJson(cit:description/gco:CharacterString)"/>"
          </xsl:if>
          <xsl:if test="cit:protocol/gco:CharacterString[normalize-space() != '']">
          ,"schema:encodingFormat": ["<xsl:value-of select="util:escapeForJson(cit:protocol/gco:CharacterString)"/>"]
          </xsl:if>
        }<xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>]
        </xsl:if>
    }<xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>
      <xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Variables measured (Feature Catalogue)
       ================================================================ -->
  <xsl:template name="cdif-variables">
    <xsl:variable name="attrs"
                  select="mdb:contentInfo/mrc:MD_FeatureCatalogue/mrc:featureCatalogue/
                          gfc:FC_FeatureCatalogue/gfc:featureType/gfc:FC_FeatureType/
                          gfc:carrierOfCharacteristics/gfc:FC_FeatureAttribute"/>
    <xsl:if test="$attrs">
  "schema:variableMeasured": [<xsl:for-each select="$attrs">
    {
      "@type": ["schema:PropertyValue"],
      "schema:name": "<xsl:value-of select="util:escapeForJson(gfc:memberName)"/>"
      <xsl:if test="gfc:definition/gco:CharacterString[normalize-space() != '']">
      ,"schema:description": "<xsl:value-of select="util:escapeForJson(gfc:definition/gco:CharacterString)"/>"
      </xsl:if>
      <xsl:if test="gfc:code/gco:CharacterString[normalize-space() != '']">
      ,"schema:propertyID": ["<xsl:value-of select="util:escapeForJson(gfc:code/gco:CharacterString)"/>"]
      </xsl:if>
      <xsl:if test="gfc:valueType/gco:TypeName/gco:aName/gco:CharacterString[normalize-space() != '']">
      ,"cdi:intendedDataType": "<xsl:value-of select="util:escapeForJson(gfc:valueType/gco:TypeName/gco:aName/gco:CharacterString)"/>"
      </xsl:if>
      <xsl:if test="gfc:valueMeasurementUnit/gco:UomIdentifier[normalize-space() != '']">
      ,"schema:unitText": "<xsl:value-of select="util:escapeForJson(gfc:valueMeasurementUnit/gco:UomIdentifier)"/>"
      </xsl:if>
    }<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Provenance (wasGeneratedBy, wasDerivedFrom)
       ================================================================ -->
  <xsl:template name="cdif-provenance">
    <!-- prov:wasGeneratedBy from processStep -->
    <xsl:variable name="processSteps"
                  select="mdb:resourceLineage/mrl:LI_Lineage/mrl:processStep/mrl:LI_ProcessStep"/>
    <xsl:if test="$processSteps">
  "prov:wasGeneratedBy": [<xsl:for-each select="$processSteps">
    {
      "@type": ["prov:Activity", "schema:Action"]
      <xsl:if test="mrl:description/gco:CharacterString[normalize-space() != '']">
      ,"schema:description": "<xsl:value-of select="util:escapeForJson(mrl:description/gco:CharacterString)"/>"
      </xsl:if>
      <xsl:if test="mrl:source/mrl:LI_Source">
      ,"prov:used": [<xsl:for-each select="mrl:source/mrl:LI_Source">
        {
          "@type": "prov:Entity"
          <xsl:if test="mrl:description/gco:CharacterString[normalize-space() != '']">
          ,"schema:description": "<xsl:value-of select="util:escapeForJson(mrl:description/gco:CharacterString)"/>"
          </xsl:if>
        }<xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>]
      </xsl:if>
    }<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>

    <!-- prov:wasDerivedFrom from lineage source -->
    <xsl:variable name="sources"
                  select="mdb:resourceLineage/mrl:LI_Lineage/mrl:source/mrl:LI_Source"/>
    <xsl:if test="$sources">
  "prov:wasDerivedFrom": [<xsl:for-each select="$sources">
    {
      "@type": "prov:Entity"
      <xsl:if test="mrl:description/gco:CharacterString[normalize-space() != '']">
      ,"schema:description": "<xsl:value-of select="util:escapeForJson(mrl:description/gco:CharacterString)"/>"
      </xsl:if>
      <xsl:if test="mrl:sourceCitation/cit:CI_Citation/cit:title/gco:CharacterString[normalize-space() != '']">
      ,"schema:name": "<xsl:value-of select="util:escapeForJson(mrl:sourceCitation/cit:CI_Citation/cit:title/gco:CharacterString)"/>"
      </xsl:if>
      <xsl:if test="mrl:sourceCitation/cit:CI_Citation/cit:onlineResource/*/cit:linkage/gco:CharacterString[normalize-space() != '']">
      ,"schema:url": "<xsl:value-of select="util:escapeForJson(mrl:sourceCitation/cit:CI_Citation/cit:onlineResource/*/cit:linkage/gco:CharacterString)"/>"
      </xsl:if>
    }<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Data Quality
       ================================================================ -->
  <xsl:template name="cdif-quality">
    <xsl:variable name="measurements"
                  select="mdb:dataQualityInfo/mdq:DQ_DataQuality/mdq:report/mdq:DQ_UsabilityElement"/>
    <xsl:if test="$measurements">
  "dqv:hasQualityMeasurement": [<xsl:for-each select="$measurements">
    {
      "@type": "dqv:QualityMeasurement"
      <xsl:if test="mdq:measure/mdq:DQ_MeasureReference/mdq:nameOfMeasure/gco:CharacterString[normalize-space() != '']">
      ,"dqv:isMeasurementOf": "<xsl:value-of select="util:escapeForJson(mdq:measure/mdq:DQ_MeasureReference/mdq:nameOfMeasure/gco:CharacterString)"/>"
      </xsl:if>
      <xsl:if test="mdq:result/mdq:DQ_DescriptiveResult/mdq:statement/gco:CharacterString[normalize-space() != '']">
      ,"dqv:value": "<xsl:value-of select="util:escapeForJson(mdq:result/mdq:DQ_DescriptiveResult/mdq:statement/gco:CharacterString)"/>"
      </xsl:if>
    }<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Supplemental Information parsing (funding, measurementTechnique,
       publishingPrinciples)
       ================================================================ -->
  <xsl:template name="cdif-supplemental">
    <xsl:variable name="suppText"
                  select="mdb:identificationInfo/*/mri:supplementalInformation/gco:CharacterString"/>
    <xsl:if test="normalize-space($suppText) != ''">

      <!-- FUNDING parsing: extract text after "FUNDING: " up to next newline.
           Only use fallback (everything after label) if there is no newline,
           meaning FUNDING is the last section in the string. -->
      <xsl:if test="contains($suppText, 'FUNDING:')">
        <xsl:variable name="afterFunding" select="substring-after($suppText, 'FUNDING:')"/>
        <xsl:variable name="afterFundingTrimmed" select="if (starts-with($afterFunding, ' ')) then substring($afterFunding, 2) else $afterFunding"/>
        <xsl:variable name="fundingText"
                      select="if (contains($afterFundingTrimmed, '&#10;'))
                              then substring-before($afterFundingTrimmed, '&#10;')
                              else $afterFundingTrimmed"/>
        <xsl:if test="normalize-space($fundingText) != ''">
  "schema:funding": [<xsl:call-template name="parseFundingEntries">
            <xsl:with-param name="text" select="$fundingText"/>
          </xsl:call-template>],
        </xsl:if>
      </xsl:if>

      <!-- MEASUREMENT TECHNIQUE parsing -->
      <xsl:if test="contains($suppText, 'MEASUREMENT TECHNIQUE:')">
        <xsl:variable name="afterMT" select="substring-after($suppText, 'MEASUREMENT TECHNIQUE:')"/>
        <xsl:variable name="afterMTTrimmed" select="if (starts-with($afterMT, ' ')) then substring($afterMT, 2) else $afterMT"/>
        <xsl:variable name="mtText"
                      select="if (contains($afterMTTrimmed, '&#10;'))
                              then substring-before($afterMTTrimmed, '&#10;')
                              else $afterMTTrimmed"/>
        <xsl:if test="normalize-space($mtText) != ''">
  "schema:measurementTechnique": "<xsl:value-of select="util:escapeForJson(normalize-space($mtText))"/>",
        </xsl:if>
      </xsl:if>

      <!-- PUBLISHING PRINCIPLES parsing -->
      <xsl:if test="contains($suppText, 'PUBLISHING PRINCIPLES:')">
        <xsl:variable name="afterPP" select="substring-after($suppText, 'PUBLISHING PRINCIPLES:')"/>
        <xsl:variable name="afterPPTrimmed" select="if (starts-with($afterPP, ' ')) then substring($afterPP, 2) else $afterPP"/>
        <xsl:variable name="ppText"
                      select="if (contains($afterPPTrimmed, '&#10;'))
                              then substring-before($afterPPTrimmed, '&#10;')
                              else $afterPPTrimmed"/>
        <xsl:if test="normalize-space($ppText) != ''">
  "schema:publishingPrinciples": ["<xsl:value-of select="util:escapeForJson(normalize-space($ppText))"/>"],
        </xsl:if>
      </xsl:if>

    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Related Links (from associatedResource)
       ================================================================ -->
  <xsl:template name="cdif-related">
    <xsl:variable name="assocResources"
                  select="mdb:identificationInfo/*/mri:associatedResource/mri:MD_AssociatedResource"/>
    <xsl:if test="$assocResources">
  "schema:relatedLink": [<xsl:for-each select="$assocResources">
    <xsl:variable name="assocCode" select="mri:associationType/*/@codeListValue"/>
    <xsl:variable name="relName">
      <xsl:call-template name="reverseAssociationType">
        <xsl:with-param name="code" select="$assocCode"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="targetTitle"
                  select="mri:metadataReference/cit:CI_Citation/cit:title/gco:CharacterString"/>
    <xsl:variable name="targetUrl"
                  select="mri:metadataReference/cit:CI_Citation/cit:onlineResource/*/cit:linkage/gco:CharacterString"/>
    {
      "@type": "schema:LinkRole"
      ,"schema:linkRelationship": "<xsl:value-of select="util:escapeForJson($relName)"/>"
      <xsl:if test="$targetUrl[normalize-space() != ''] or $targetTitle[normalize-space() != '']">
      ,"schema:target": {
        "@type": "schema:EntryPoint"
        <xsl:if test="$targetUrl[normalize-space() != '']">
        ,"schema:url": "<xsl:value-of select="util:escapeForJson($targetUrl)"/>"
        </xsl:if>
        <xsl:if test="$targetTitle[normalize-space() != '']">
        ,"schema:name": "<xsl:value-of select="util:escapeForJson($targetTitle)"/>"
        </xsl:if>
      }
      </xsl:if>
    }<xsl:if test="position() != last()">,</xsl:if>
  </xsl:for-each>],
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       subjectOf (metadata record information)
       ================================================================ -->
  <xsl:template name="cdif-subjectOf">
    <xsl:param name="recordUrl"/>

    <xsl:variable name="creationDate"
                  select="mdb:dateInfo[*/cit:dateType/*/@codeListValue='creation'][1]/*/cit:date/(gco:Date|gco:DateTime)"/>
    <xsl:variable name="revisionDate"
                  select="mdb:dateInfo[*/cit:dateType/*/@codeListValue='revision'][1]/*/cit:date/(gco:Date|gco:DateTime)"/>
    <xsl:variable name="profiles" select="mdb:metadataProfile/cit:CI_Citation"/>
    <xsl:variable name="maintainer"
                  select="mdb:contact[*/cit:role/*/@codeListValue='pointOfContact'][1]/*"/>
    <xsl:variable name="catalogs" select="mdb:metadataLinkage/cit:CI_OnlineResource"/>

  "schema:subjectOf": {
    "@type": ["schema:Dataset"],
    "@id": "<xsl:value-of select="util:escapeForJson(concat($recordUrl, '/metadata'))"/>",
    "schema:additionalType": ["dcat:CatalogRecord"],
    "schema:about": {"@id": "<xsl:value-of select="util:escapeForJson($recordUrl)"/>"}
    <xsl:if test="$creationDate[normalize-space() != '']">
    ,"schema:sdDatePublished": "<xsl:value-of select="$creationDate"/>"
    </xsl:if>
    <xsl:if test="$revisionDate[normalize-space() != '']">
    ,"schema:dateModified": "<xsl:value-of select="$revisionDate"/>"
    </xsl:if>
    <xsl:if test="$profiles">
    ,"dcterms:conformsTo": [<xsl:for-each select="$profiles">
      <xsl:variable name="profName" select="cit:title/gco:CharacterString"/>
      <xsl:variable name="profUrl" select="cit:onlineResource/*/cit:linkage/gco:CharacterString"/>
      {
        "@type": "schema:CreativeWork"
        <xsl:if test="$profName[normalize-space() != '']">
        ,"schema:name": "<xsl:value-of select="util:escapeForJson($profName)"/>"
        </xsl:if>
        <xsl:if test="$profUrl[normalize-space() != '']">
        ,"schema:url": "<xsl:value-of select="util:escapeForJson($profUrl)"/>"
        </xsl:if>
      }<xsl:if test="position() != last()">,</xsl:if>
    </xsl:for-each>]
    </xsl:if>
    <xsl:if test="$maintainer">
    ,"schema:maintainer": <xsl:call-template name="buildAgentJsonLd">
        <xsl:with-param name="resp" select="$maintainer"/>
        <xsl:with-param name="agentIndex" select="'maintainer'"/>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="$catalogs">
    <xsl:variable name="firstCatalog" select="$catalogs[1]"/>
    ,"schema:includedInDataCatalog": {
        "@type": "schema:DataCatalog"
        <xsl:if test="$firstCatalog/cit:linkage/gco:CharacterString[normalize-space() != '']">
        ,"schema:url": "<xsl:value-of select="util:escapeForJson($firstCatalog/cit:linkage/gco:CharacterString)"/>"
        </xsl:if>
        <xsl:if test="$firstCatalog/cit:name/gco:CharacterString[normalize-space() != '']">
        ,"schema:name": "<xsl:value-of select="util:escapeForJson($firstCatalog/cit:name/gco:CharacterString)"/>"
        </xsl:if>
      }
    </xsl:if>
  },
  </xsl:template>


  <!-- ================================================================
       Helper: Build agent JSON-LD from CI_Responsibility
       ================================================================ -->
  <xsl:template name="buildAgentJsonLd">
    <xsl:param name="resp"/>
    <xsl:param name="agentIndex" select="'0'"/>

    <xsl:variable name="party" select="$resp/cit:party"/>
    <xsl:variable name="org" select="$party/cit:CI_Organisation"/>
    <xsl:variable name="individual" select="$org/cit:individual/cit:CI_Individual"/>
    <xsl:variable name="orgName" select="$org/cit:name/gco:CharacterString"/>
    <xsl:variable name="indivName" select="$individual/cit:name/gco:CharacterString"/>
    <xsl:variable name="email" select="($org/cit:contactInfo/*/cit:address/*/cit:electronicMailAddress/gco:CharacterString)[1]"/>
    <xsl:variable name="indivId" select="$individual/cit:partyIdentifier/mcc:MD_Identifier/mcc:code/gco:CharacterString"/>
    <xsl:variable name="orgId" select="$org/cit:partyIdentifier/mcc:MD_Identifier/mcc:code/gco:CharacterString"/>

    <!-- Use identifier as @id if available, otherwise generate a blank node ID.
         Explicit @id helps JSON-LD framing preserve nodes inside @list. -->
    <xsl:variable name="agentId">
      <xsl:choose>
        <xsl:when test="$indivId[normalize-space() != '']"><xsl:value-of select="$indivId"/></xsl:when>
        <xsl:when test="$orgId[normalize-space() != '']"><xsl:value-of select="$orgId"/></xsl:when>
        <xsl:otherwise>_:agent-<xsl:value-of select="$agentIndex"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:choose>
      <!-- Person: has CI_Individual with a name (fromJsonCdif.xsl sets org name =
           individual name for persons without a separate affiliation) -->
      <xsl:when test="$individual and $indivName[normalize-space() != '']">
    {
      "@id": "<xsl:value-of select="util:escapeForJson($agentId)"/>",
      "@type": "schema:Person",
      "schema:name": "<xsl:value-of select="util:escapeForJson($indivName)"/>"
        <xsl:if test="$email[normalize-space() != '']">
      ,"schema:email": "<xsl:value-of select="util:escapeForJson($email)"/>"
        </xsl:if>
        <xsl:if test="$indivId[normalize-space() != '']">
      ,"schema:identifier": "<xsl:value-of select="util:escapeForJson($indivId)"/>"
        </xsl:if>
        <xsl:if test="$orgName[normalize-space() != ''] and $orgName != $indivName">
      ,"schema:affiliation": {
        "@type": "schema:Organization",
        "schema:name": "<xsl:value-of select="util:escapeForJson($orgName)"/>"
        <xsl:if test="$orgId[normalize-space() != '']">
        ,"schema:identifier": "<xsl:value-of select="util:escapeForJson($orgId)"/>"
        </xsl:if>
      }
        </xsl:if>
    }</xsl:when>
      <!-- Organization (no individual) -->
      <xsl:otherwise>
    {
      "@id": "<xsl:value-of select="util:escapeForJson($agentId)"/>",
      "@type": "schema:Organization",
      "schema:name": "<xsl:value-of select="util:escapeForJson(if ($orgName[normalize-space() != '']) then $orgName else $indivName)"/>"
        <xsl:if test="$email[normalize-space() != '']">
      ,"schema:email": "<xsl:value-of select="util:escapeForJson($email)"/>"
        </xsl:if>
        <xsl:if test="$orgId[normalize-space() != '']">
      ,"schema:identifier": "<xsl:value-of select="util:escapeForJson($orgId)"/>"
        </xsl:if>
    }</xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- ================================================================
       Helper: Reverse language code (3-letter → 2-letter)
       ================================================================ -->
  <xsl:template name="reverseLanguageCode">
    <xsl:param name="code3"/>
    <xsl:variable name="lc" select="lower-case(normalize-space($code3))"/>
    <xsl:choose>
      <xsl:when test="$lc = 'eng'">en</xsl:when>
      <xsl:when test="$lc = 'fra'">fr</xsl:when>
      <xsl:when test="$lc = 'deu'">de</xsl:when>
      <xsl:when test="$lc = 'spa'">es</xsl:when>
      <xsl:when test="$lc = 'ita'">it</xsl:when>
      <xsl:when test="$lc = 'por'">pt</xsl:when>
      <xsl:when test="$lc = 'nld'">nl</xsl:when>
      <xsl:when test="$lc = 'rus'">ru</xsl:when>
      <xsl:when test="$lc = 'zho'">zh</xsl:when>
      <xsl:when test="$lc = 'jpn'">ja</xsl:when>
      <xsl:when test="$lc = 'kor'">ko</xsl:when>
      <xsl:when test="$lc = 'ara'">ar</xsl:when>
      <xsl:when test="$lc = 'pol'">pl</xsl:when>
      <xsl:when test="$lc = 'swe'">sv</xsl:when>
      <xsl:when test="$lc = 'nor'">no</xsl:when>
      <xsl:when test="$lc = 'dan'">da</xsl:when>
      <xsl:when test="$lc = 'fin'">fi</xsl:when>
      <xsl:when test="$lc = 'gre'">el</xsl:when>
      <xsl:when test="$lc = 'cze'">cs</xsl:when>
      <xsl:when test="$lc = 'tur'">tr</xsl:when>
      <xsl:when test="$lc = 'hun'">hu</xsl:when>
      <xsl:when test="$lc = 'rum'">ro</xsl:when>
      <xsl:when test="$lc = 'ukr'">uk</xsl:when>
      <xsl:when test="$lc = 'vie'">vi</xsl:when>
      <xsl:when test="$lc = 'tha'">th</xsl:when>
      <xsl:when test="$lc = 'hin'">hi</xsl:when>
      <xsl:otherwise><xsl:value-of select="$lc"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- ================================================================
       Helper: Reverse CI_RoleCode → CDIF role name
       ================================================================ -->
  <xsl:template name="reverseRoleCode">
    <xsl:param name="code"/>
    <xsl:variable name="lc" select="lower-case(normalize-space($code))"/>
    <xsl:choose>
      <xsl:when test="$lc = 'contributor'">contributor</xsl:when>
      <xsl:when test="$lc = 'editor'">editor</xsl:when>
      <xsl:when test="$lc = 'funder'">funder</xsl:when>
      <xsl:when test="$lc = 'principalinvestigator'">principal investigator</xsl:when>
      <xsl:when test="$lc = 'custodian'">custodian</xsl:when>
      <xsl:when test="$lc = 'originator'">originator</xsl:when>
      <xsl:when test="$lc = 'processor'">processor</xsl:when>
      <xsl:when test="$lc = 'resourceprovider'">resource provider</xsl:when>
      <xsl:when test="$lc = 'user'">user</xsl:when>
      <xsl:when test="$lc = 'sponsor'">sponsor</xsl:when>
      <xsl:when test="$lc = 'collaborator'">collaborator</xsl:when>
      <xsl:when test="$lc = 'stakeholder'">stakeholder</xsl:when>
      <xsl:when test="$lc = 'coauthor'">co-author</xsl:when>
      <xsl:when test="$lc = 'rightsholder'">rights holder</xsl:when>
      <xsl:when test="$lc = 'mediator'">mediator</xsl:when>
      <xsl:otherwise><xsl:value-of select="$code"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- ================================================================
       Helper: Reverse DS_AssociationTypeCode → relationship name
       ================================================================ -->
  <xsl:template name="reverseAssociationType">
    <xsl:param name="code"/>
    <xsl:variable name="lc" select="lower-case(normalize-space($code))"/>
    <xsl:choose>
      <xsl:when test="$lc = 'largerworkcitation'">isPartOf</xsl:when>
      <xsl:when test="$lc = 'partofseamlessdatabase'">hasPart</xsl:when>
      <xsl:when test="$lc = 'crossreference'">references</xsl:when>
      <xsl:when test="$lc = 'dependency'">isBasedOn</xsl:when>
      <xsl:when test="$lc = 'revisionof'">isBasisFor</xsl:when>
      <xsl:when test="$lc = 'iscomposedof'">isSupplementTo</xsl:when>
      <xsl:when test="$lc = 'stereomate'">stereoMate</xsl:when>
      <xsl:otherwise><xsl:value-of select="$code"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- ================================================================
       Helper: Parse semicolon-separated funding entries
       Format: "Name (funder: X) [id]; Name2 (funder: Y) [id2]"
       ================================================================ -->
  <xsl:template name="parseFundingEntries">
    <xsl:param name="text"/>

    <xsl:variable name="entries" select="tokenize($text, ';\s*')"/>
    <xsl:for-each select="$entries[normalize-space(.) != '']">
      <xsl:variable name="entry" select="normalize-space(.)"/>
      <!-- Extract grant name (before first parenthesis or bracket) -->
      <xsl:variable name="grantName">
        <xsl:choose>
          <xsl:when test="contains($entry, ' (funder:')">
            <xsl:value-of select="normalize-space(substring-before($entry, ' (funder:'))"/>
          </xsl:when>
          <xsl:when test="contains($entry, ' [')">
            <xsl:value-of select="normalize-space(substring-before($entry, ' ['))"/>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="$entry"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- Extract funder name -->
      <xsl:variable name="funderName">
        <xsl:if test="contains($entry, '(funder: ')">
          <xsl:value-of select="normalize-space(substring-before(
            substring-after($entry, '(funder: '), ')'))"/>
        </xsl:if>
      </xsl:variable>
      <!-- Extract identifier in brackets -->
      <xsl:variable name="grantId">
        <xsl:if test="contains($entry, '[') and contains($entry, ']')">
          <xsl:value-of select="normalize-space(substring-before(
            substring-after($entry, '['), ']'))"/>
        </xsl:if>
      </xsl:variable>
    {
      "@type": "schema:MonetaryGrant"
      <xsl:if test="$grantName != ''">
      ,"schema:name": "<xsl:value-of select="util:escapeForJson($grantName)"/>"
      </xsl:if>
      <xsl:if test="$funderName != ''">
      ,"schema:funder": {
        "@type": "schema:Organization",
        "schema:name": "<xsl:value-of select="util:escapeForJson($funderName)"/>"
      }
      </xsl:if>
      <xsl:if test="$grantId != ''">
      ,"schema:identifier": {
        "@type": "schema:PropertyValue",
        "schema:value": "<xsl:value-of select="util:escapeForJson($grantId)"/>"
      }
      </xsl:if>
    }<xsl:if test="position() != last()">,</xsl:if>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
