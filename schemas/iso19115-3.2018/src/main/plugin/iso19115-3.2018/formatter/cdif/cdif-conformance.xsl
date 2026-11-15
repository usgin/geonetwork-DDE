<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="#all">
  <!--
    Which CDIF conformance classes a record should declare, decided from the body the
    formatter actually emitted.

    Kept in its own file, free of the util: extension functions, for two reasons: the
    rule is the kind that goes stale silently, and here it can be driven directly by a
    test stylesheet under plain Saxon. iso19115-3-to-cdif.xsl includes it.

    The principle is CDIF's own, from validation/detect_conformance.py: a class is
    declared when the record uses the elements that class introduces beyond its base,
    rather than from a fixed list, which over-declares. That script decides it with a
    SPARQL ASK over the RDF graph; here the same question is asked of the emitted JSON
    text, which is equivalent for these markers and needs no graph.

    Testing the emitted text, rather than re-deriving the ISO-side conditions, is
    deliberate: the declaration then cannot drift from the content. Re-deriving would
    leave two expressions of one rule, free to disagree, which is how a record ends up
    declaring a class it does not satisfy.

    Searching for the key with its trailing colon is safe against a description that
    happens to contain the same words: util:escapeForJson would have turned the quotes
    into \" , so "schema:hasPart": cannot occur inside a string value.
  -->

  <!--
    The markers for each declarable class. cdifCore needs none: it is the baseline, and
    the formatter always emits a schema:Dataset with a name and an identifier.
  -->
  <xsl:variable name="cdif-discovery-markers" as="xs:string*"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                select="(
                  '&quot;schema:measurementTechnique&quot;:',
                  '&quot;schema:variableMeasured&quot;:',
                  '&quot;schema:spatialCoverage&quot;:',
                  '&quot;schema:temporalCoverage&quot;:',
                  '&quot;dqv:hasQualityMeasurement&quot;:')"/>

  <!--
    schema:hasPart, which this formatter emits only for archive members on a
    distribution item. That is one of the two places cdifManifest declares it.
  -->
  <xsl:variable name="cdif-manifest-markers" as="xs:string*"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                select="'&quot;schema:hasPart&quot;:'"/>

  <!--
    The conformance class URIs this record should declare, in order, most general first.

    Three of the six CDIF modules are not declarable from this formatter and are
    deliberately absent:

      data_description  needs variables typed cdi:InstanceVariable; cdif-variables emits
                        schema:PropertyValue only.
      data_structure    needs cdi:isStructuredBy or one of the cdi: structure classes;
                        neither is emitted anywhere.
      provenance        needs a dual-typed prov:Activity + schema:Action carrying one of
                        schema:instrument, schema:object or schema:actionProcess.
                        cdif-provenance emits the dual type but only description and
                        prov:used, which is the minimal activity cdifCore already covers.

    If any of those starts being emitted, add its marker above and a branch here.
  -->
  <xsl:template name="cdif-conformance-classes" as="xs:string*"
                xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <xsl:param name="body" select="''"/>
    <xsl:param name="version" select="'1.1'"/>

    <xsl:sequence select="concat('https://w3id.org/cdif/core/', $version)"/>
    <xsl:if test="some $m in $cdif-discovery-markers satisfies contains($body, $m)">
      <xsl:sequence select="concat('https://w3id.org/cdif/discovery/', $version)"/>
    </xsl:if>
    <xsl:if test="some $m in $cdif-manifest-markers satisfies contains($body, $m)">
      <xsl:sequence select="concat('https://w3id.org/cdif/manifest/', $version)"/>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
