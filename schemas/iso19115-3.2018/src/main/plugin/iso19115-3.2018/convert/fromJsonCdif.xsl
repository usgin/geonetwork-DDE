<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:gmd="http://www.isotc211.org/2005/gmd"
                xmlns:gcoold="http://www.isotc211.org/2005/gco"
                xmlns:gmi="http://www.isotc211.org/2005/gmi"
                xmlns:gmx="http://www.isotc211.org/2005/gmx"
                xmlns:gsr="http://www.isotc211.org/2005/gsr"
                xmlns:gss="http://www.isotc211.org/2005/gss"
                xmlns:gts="http://www.isotc211.org/2005/gts"
                xmlns:srvold="http://www.isotc211.org/2005/srv"
                xmlns:gml30="http://www.opengis.net/gml"
                xmlns:cat="http://standards.iso.org/iso/19115/-3/cat/1.0"
                xmlns:cit="http://standards.iso.org/iso/19115/-3/cit/2.0"
                xmlns:gcx="http://standards.iso.org/iso/19115/-3/gcx/1.0"
                xmlns:gex="http://standards.iso.org/iso/19115/-3/gex/1.0"
                xmlns:lan="http://standards.iso.org/iso/19115/-3/lan/1.0"
                xmlns:srv="http://standards.iso.org/iso/19115/-3/srv/2.1"
                xmlns:mac="http://standards.iso.org/iso/19115/-3/mac/2.0"
                xmlns:mas="http://standards.iso.org/iso/19115/-3/mas/1.0"
                xmlns:mcc="http://standards.iso.org/iso/19115/-3/mcc/1.0"
                xmlns:mco="http://standards.iso.org/iso/19115/-3/mco/1.0"
                xmlns:mda="http://standards.iso.org/iso/19115/-3/mda/1.0"
                xmlns:mdb="http://standards.iso.org/iso/19115/-3/mdb/2.0"
                xmlns:mdt="http://standards.iso.org/iso/19115/-3/mdt/1.0"
                xmlns:mex="http://standards.iso.org/iso/19115/-3/mex/1.0"
                xmlns:mic="http://standards.iso.org/iso/19115/-3/mic/1.0"
                xmlns:mil="http://standards.iso.org/iso/19115/-3/mil/1.0"
                xmlns:mrl="http://standards.iso.org/iso/19115/-3/mrl/2.0"
                xmlns:mds="http://standards.iso.org/iso/19115/-3/mds/2.0"
                xmlns:mmi="http://standards.iso.org/iso/19115/-3/mmi/1.0"
                xmlns:mpc="http://standards.iso.org/iso/19115/-3/mpc/1.0"
                xmlns:mrc="http://standards.iso.org/iso/19115/-3/mrc/2.0"
                xmlns:mrd="http://standards.iso.org/iso/19115/-3/mrd/1.0"
                xmlns:mri="http://standards.iso.org/iso/19115/-3/mri/1.0"
                xmlns:mrs="http://standards.iso.org/iso/19115/-3/mrs/1.0"
                xmlns:msr="http://standards.iso.org/iso/19115/-3/msr/2.0"
                xmlns:mai="http://standards.iso.org/iso/19115/-3/mai/1.0"
                xmlns:mdq="http://standards.iso.org/iso/19157/-2/mdq/1.0"
                xmlns:gco="http://standards.iso.org/iso/19115/-3/gco/1.0"
                xmlns:gml="http://www.opengis.net/gml/3.2"
                xmlns:xlink="http://www.w3.org/1999/xlink"
                xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                exclude-result-prefixes="xsl xs gmd gcoold gmi gmx gsr gss gts srvold gml30 xd">

    <xsl:output method="xml" indent="yes"/>

    <xsl:strip-space elements="*"/>

    <!-- Convert CDIF JSON-LD (via JSON-to-XML intermediate form) to ISO 19115-3.
         JSON keys are transformed: schema:name -> schema_name, @id -> id, @type -> type.
         Arrays become repeated sibling elements. -->

    <xsl:template match="/record">

      <mdb:MD_Metadata xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:cit="http://standards.iso.org/iso/19115/-3/cit/2.0"
                       xmlns:gex="http://standards.iso.org/iso/19115/-3/gex/1.0"
                       xmlns:lan="http://standards.iso.org/iso/19115/-3/lan/1.0"
                       xmlns:mcc="http://standards.iso.org/iso/19115/-3/mcc/1.0"
                       xmlns:mco="http://standards.iso.org/iso/19115/-3/mco/1.0"
                       xmlns:mdb="http://standards.iso.org/iso/19115/-3/mdb/2.0"
                       xmlns:mmi="http://standards.iso.org/iso/19115/-3/mmi/1.0"
                       xmlns:mrd="http://standards.iso.org/iso/19115/-3/mrd/1.0"
                       xmlns:mri="http://standards.iso.org/iso/19115/-3/mri/1.0"
                       xmlns:mrl="http://standards.iso.org/iso/19115/-3/mrl/2.0"
                       xmlns:mrs="http://standards.iso.org/iso/19115/-3/mrs/1.0"
                       xmlns:mrc="http://standards.iso.org/iso/19115/-3/mrc/2.0"
                       xmlns:mdq="http://standards.iso.org/iso/19157/-2/mdq/1.0"
                       xmlns:gco="http://standards.iso.org/iso/19115/-3/gco/1.0"
                       xmlns:gfc="http://standards.iso.org/iso/19110/gfc/1.1"
                       xmlns:cat="http://standards.iso.org/iso/19115/-3/cat/1.0"
                       xmlns:fcc="http://standards.iso.org/iso/19110/fcc/1.0"
                       xmlns:gml="http://www.opengis.net/gml/3.2"
                       xsi:schemaLocation="http://standards.iso.org/iso/19115/-3/mdb/2.0 http://standards.iso.org/iso/19115/-3/mdb/2.0/mdb.xsd
                                            http://standards.iso.org/iso/19115/-3/mco/1.0 http://standards.iso.org/iso/19115/-3/mco/1.0/mco.xsd
                                            http://standards.iso.org/iso/19115/-3/mrc/2.0 http://standards.iso.org/iso/19115/-3/mrc/2.0/mrc.xsd
                                            http://standards.iso.org/iso/19115/-3/mrd/1.0 http://standards.iso.org/iso/19115/-3/mrd/1.0/mrd.xsd
                                            http://standards.iso.org/iso/19115/-3/mrl/2.0 http://standards.iso.org/iso/19115/-3/mrl/2.0/mrl.xsd
                                            http://standards.iso.org/iso/19157/-2/mdq/1.0 http://standards.iso.org/iso/19157/-2/mdq/1.0/mdq.xsd
                                            http://standards.iso.org/iso/19110/gfc/1.1 http://standards.iso.org/iso/19110/gfc/1.1/gfc.xsd
                                            http://standards.iso.org/iso/19110/fcc/1.0 http://standards.iso.org/iso/19110/fcc/1.0/fcc.xsd">

        <!-- ================================================================
             1. metadataIdentifier
             ================================================================ -->
        <mdb:metadataIdentifier>
          <mcc:MD_Identifier>
            <mcc:code>
              <gco:CharacterString>
                <xsl:value-of select="uuid"/>
              </gco:CharacterString>
            </mcc:code>
          </mcc:MD_Identifier>
        </mdb:metadataIdentifier>

        <!-- ================================================================
             2. defaultLocale (use schema_inLanguage when available)
             ================================================================ -->
        <mdb:defaultLocale>
          <lan:PT_Locale>
            <lan:language>
              <xsl:variable name="langCode">
                <xsl:choose>
                  <xsl:when test="schema_inLanguage != ''">
                    <xsl:call-template name="mapLanguageCode">
                      <xsl:with-param name="lang" select="schema_inLanguage"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>eng</xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <lan:LanguageCode codeList="codeListLocation#LanguageCode"
                                codeListValue="{$langCode}"/>
            </lan:language>
            <lan:characterEncoding>
              <lan:MD_CharacterSetCode codeList="codeListLocation#MD_CharacterSetCode"
                                       codeListValue="utf8"/>
            </lan:characterEncoding>
          </lan:PT_Locale>
        </mdb:defaultLocale>

        <!-- ================================================================
             3. metadataScope
             ================================================================ -->
        <mdb:metadataScope>
          <mdb:MD_MetadataScope>
            <mdb:resourceScope>
              <xsl:variable name="scopeCode">
                <xsl:choose>
                  <xsl:when test="type[contains(., 'Dataset')] or type[contains(., 'schema_Dataset')]">dataset</xsl:when>
                  <xsl:when test="type[contains(., 'Service')]">service</xsl:when>
                  <xsl:when test="type[contains(., 'SoftwareApplication')] or type[contains(., 'SoftwareSourceCode')]">software</xsl:when>
                  <xsl:otherwise>dataset</xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <mcc:MD_ScopeCode codeList="http://standards.iso.org/iso/19115/resources/Codelists/cat/codelists.xml#MD_ScopeCode"
                                codeListValue="{$scopeCode}"/>
            </mdb:resourceScope>
          </mdb:MD_MetadataScope>
        </mdb:metadataScope>

        <!-- ================================================================
             4. contact — creator (existing)
             Handle both direct schema_creator children and @list-wrapped
             (schema_creator/list) from JSON-LD framing.
             ================================================================ -->
        <xsl:variable name="creators"
                      select="schema_creator[schema_name] | schema_creator/list[schema_name]"/>
        <xsl:choose>
          <xsl:when test="$creators">
            <xsl:for-each select="$creators[1]">
              <mdb:contact>
                <xsl:call-template name="buildResponsibility">
                  <xsl:with-param name="role">author</xsl:with-param>
                </xsl:call-template>
              </mdb:contact>
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise>
            <mdb:contact>
              <cit:CI_Responsibility>
                <cit:role>
                  <cit:CI_RoleCode codeList="codeListLocation#CI_RoleCode" codeListValue="author"/>
                </cit:role>
                <cit:party>
                  <cit:CI_Organisation>
                    <cit:name>
                      <gco:CharacterString/>
                    </cit:name>
                  </cit:CI_Organisation>
                </cit:party>
              </cit:CI_Responsibility>
            </mdb:contact>
          </xsl:otherwise>
        </xsl:choose>

        <!-- 4b. contact — provider as distributor -->
        <xsl:if test="schema_provider[schema_name != '']">
          <xsl:for-each select="schema_provider[schema_name != ''][1]">
            <mdb:contact>
              <xsl:call-template name="buildResponsibility">
                <xsl:with-param name="role">distributor</xsl:with-param>
              </xsl:call-template>
            </mdb:contact>
          </xsl:for-each>
        </xsl:if>

        <!-- 4c. contact — subjectOf/maintainer as pointOfContact -->
        <xsl:if test="schema_subjectOf/schema_maintainer">
          <xsl:for-each select="schema_subjectOf/schema_maintainer[1]">
            <mdb:contact>
              <xsl:call-template name="buildResponsibility">
                <xsl:with-param name="role">pointOfContact</xsl:with-param>
              </xsl:call-template>
            </mdb:contact>
          </xsl:for-each>
        </xsl:if>

        <!-- ================================================================
             5. dateInfo — revision (metadata dateModified)
             ================================================================ -->
        <xsl:if test="schema_subjectOf/schema_dateModified">
          <mdb:dateInfo>
            <cit:CI_Date>
              <cit:date>
                <xsl:call-template name="formatDateOrDateTime">
                  <xsl:with-param name="dateValue" select="schema_subjectOf/schema_dateModified"/>
                </xsl:call-template>
              </cit:date>
              <cit:dateType>
                <cit:CI_DateTypeCode codeList="codeListLocation#CI_DateTypeCode" codeListValue="revision"/>
              </cit:dateType>
            </cit:CI_Date>
          </mdb:dateInfo>
        </xsl:if>

        <!-- 5b. dateInfo — creation (metadata sdDatePublished) -->
        <xsl:if test="schema_subjectOf/schema_sdDatePublished">
          <mdb:dateInfo>
            <cit:CI_Date>
              <cit:date>
                <xsl:call-template name="formatDateOrDateTime">
                  <xsl:with-param name="dateValue" select="schema_subjectOf/schema_sdDatePublished"/>
                </xsl:call-template>
              </cit:date>
              <cit:dateType>
                <cit:CI_DateTypeCode codeList="codeListLocation#CI_DateTypeCode" codeListValue="creation"/>
              </cit:dateType>
            </cit:CI_Date>
          </mdb:dateInfo>
        </xsl:if>

        <!-- 5c. dateInfo — publication (resource datePublished) -->
        <xsl:if test="schema_datePublished">
          <mdb:dateInfo>
            <cit:CI_Date>
              <cit:date>
                <xsl:call-template name="formatDateOrDateTime">
                  <xsl:with-param name="dateValue" select="schema_datePublished"/>
                </xsl:call-template>
              </cit:date>
              <cit:dateType>
                <cit:CI_DateTypeCode codeList="codeListLocation#CI_DateTypeCode" codeListValue="publication"/>
              </cit:dateType>
            </cit:CI_Date>
          </mdb:dateInfo>
        </xsl:if>

        <!-- ================================================================
             6. metadataStandard
             ================================================================ -->
        <mdb:metadataStandard>
          <cit:CI_Citation>
            <cit:title>
              <gco:CharacterString>ISO 19115-3</gco:CharacterString>
            </cit:title>
          </cit:CI_Citation>
        </mdb:metadataStandard>

        <!-- ================================================================
             7. metadataProfile (from subjectOf/dcterms_conformsTo)
             ================================================================ -->
        <xsl:for-each select="schema_subjectOf/dcterms_conformsTo">
          <mdb:metadataProfile>
            <cit:CI_Citation>
              <cit:title>
                <gco:CharacterString>
                  <xsl:choose>
                    <xsl:when test="schema_name != ''">
                      <xsl:value-of select="schema_name"/>
                    </xsl:when>
                    <xsl:when test="id != ''">
                      <xsl:value-of select="id"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="."/>
                    </xsl:otherwise>
                  </xsl:choose>
                </gco:CharacterString>
              </cit:title>
              <xsl:variable name="profileUrl">
                <xsl:choose>
                  <xsl:when test="schema_url != ''"><xsl:value-of select="schema_url"/></xsl:when>
                  <xsl:when test="id != '' and starts-with(id, 'http')"><xsl:value-of select="id"/></xsl:when>
                  <xsl:when test="not(*) and starts-with(., 'http')"><xsl:value-of select="."/></xsl:when>
                </xsl:choose>
              </xsl:variable>
              <xsl:if test="$profileUrl != ''">
                <cit:onlineResource>
                  <cit:CI_OnlineResource>
                    <cit:linkage>
                      <gco:CharacterString><xsl:value-of select="$profileUrl"/></gco:CharacterString>
                    </cit:linkage>
                  </cit:CI_OnlineResource>
                </cit:onlineResource>
              </xsl:if>
            </cit:CI_Citation>
          </mdb:metadataProfile>
        </xsl:for-each>

        <!-- ================================================================
             8. metadataLinkage (from subjectOf/includedInDataCatalog)
             ================================================================ -->
        <xsl:for-each select="schema_subjectOf/schema_includedInDataCatalog">
          <xsl:variable name="catalogUrl">
            <xsl:choose>
              <xsl:when test="schema_url != ''"><xsl:value-of select="schema_url"/></xsl:when>
              <xsl:when test="id != '' and starts-with(id, 'http')"><xsl:value-of select="id"/></xsl:when>
              <xsl:when test="not(*) and starts-with(., 'http')"><xsl:value-of select="."/></xsl:when>
            </xsl:choose>
          </xsl:variable>
          <xsl:if test="$catalogUrl != ''">
            <mdb:metadataLinkage>
              <cit:CI_OnlineResource>
                <cit:linkage>
                  <gco:CharacterString><xsl:value-of select="$catalogUrl"/></gco:CharacterString>
                </cit:linkage>
                <xsl:if test="schema_name != ''">
                  <cit:name>
                    <gco:CharacterString><xsl:value-of select="schema_name"/></gco:CharacterString>
                  </cit:name>
                </xsl:if>
                <cit:function>
                  <cit:CI_OnLineFunctionCode codeList="codeListLocation#CI_OnLineFunctionCode"
                                             codeListValue="completeMetadata"/>
                </cit:function>
              </cit:CI_OnlineResource>
            </mdb:metadataLinkage>
          </xsl:if>
        </xsl:for-each>

        <!-- ================================================================
             9. identificationInfo
             ================================================================ -->
        <mdb:identificationInfo>
          <mri:MD_DataIdentification>
            <mri:citation>
              <cit:CI_Citation>
                <!-- Title -->
                <cit:title>
                  <gco:CharacterString>
                    <xsl:value-of select="schema_name"/>
                  </gco:CharacterString>
                </cit:title>

                <!-- Publication date -->
                <xsl:if test="schema_datePublished">
                  <cit:date>
                    <cit:CI_Date>
                      <cit:date>
                        <xsl:call-template name="formatDateOrDateTime">
                          <xsl:with-param name="dateValue" select="schema_datePublished"/>
                        </xsl:call-template>
                      </cit:date>
                      <cit:dateType>
                        <cit:CI_DateTypeCode codeList="codeListLocation#CI_DateTypeCode" codeListValue="publication"/>
                      </cit:dateType>
                    </cit:CI_Date>
                  </cit:date>
                </xsl:if>

                <!-- Edition (version) -->
                <xsl:if test="schema_version != ''">
                  <cit:edition>
                    <gco:CharacterString><xsl:value-of select="schema_version"/></gco:CharacterString>
                  </cit:edition>
                </xsl:if>

                <!-- Resource Identifier (DOI or structured) -->
                <xsl:if test="schema_identifier">
                  <cit:identifier>
                    <mcc:MD_Identifier>
                      <mcc:code>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_identifier/schema_value">
                              <xsl:value-of select="schema_identifier/schema_value"/>
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:value-of select="schema_identifier"/>
                            </xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </mcc:code>
                      <xsl:if test="schema_identifier/schema_propertyID">
                        <mcc:codeSpace>
                          <gco:CharacterString>
                            <xsl:value-of select="schema_identifier/schema_propertyID"/>
                          </gco:CharacterString>
                        </mcc:codeSpace>
                      </xsl:if>
                    </mcc:MD_Identifier>
                  </cit:identifier>
                </xsl:if>

                <!-- sameAs as additional identifier -->
                <xsl:for-each select="schema_sameAs">
                  <cit:identifier>
                    <mcc:MD_Identifier>
                      <mcc:code>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="id != ''"><xsl:value-of select="id"/></xsl:when>
                            <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </mcc:code>
                      <mcc:codeSpace>
                        <gco:CharacterString>sameAs</gco:CharacterString>
                      </mcc:codeSpace>
                    </mcc:MD_Identifier>
                  </cit:identifier>
                </xsl:for-each>

                <!-- Cited Responsible Parties: creators (handle @list wrapper) -->
                <xsl:for-each select="schema_creator[schema_name] | schema_creator/list[schema_name]">
                  <cit:citedResponsibleParty>
                    <xsl:call-template name="buildResponsibility">
                      <xsl:with-param name="role">author</xsl:with-param>
                    </xsl:call-template>
                  </cit:citedResponsibleParty>
                </xsl:for-each>

                <!-- Cited Responsible Parties: publisher -->
                <xsl:for-each select="schema_publisher">
                  <cit:citedResponsibleParty>
                    <xsl:call-template name="buildResponsibility">
                      <xsl:with-param name="role">publisher</xsl:with-param>
                    </xsl:call-template>
                  </cit:citedResponsibleParty>
                </xsl:for-each>

                <!-- Cited Responsible Parties: contributors with role mapping.
                     CDIF uses a Role wrapper: schema_contributor/schema_contributor holds
                     the actual person/org, and schema_contributor/schema_roleName holds the role. -->
                <xsl:for-each select="schema_contributor">
                  <xsl:variable name="mappedRole">
                    <xsl:choose>
                      <xsl:when test="schema_roleName != ''">
                        <xsl:call-template name="mapRoleName">
                          <xsl:with-param name="roleName" select="schema_roleName"/>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:otherwise>contributor</xsl:otherwise>
                    </xsl:choose>
                  </xsl:variable>
                  <xsl:choose>
                    <!-- Role wrapper pattern: inner schema_contributor holds the actual agent -->
                    <xsl:when test="schema_contributor">
                      <xsl:for-each select="schema_contributor">
                        <cit:citedResponsibleParty>
                          <xsl:call-template name="buildResponsibility">
                            <xsl:with-param name="role" select="$mappedRole"/>
                          </xsl:call-template>
                        </cit:citedResponsibleParty>
                      </xsl:for-each>
                    </xsl:when>
                    <!-- Direct contributor (no Role wrapper) -->
                    <xsl:when test="schema_name">
                      <cit:citedResponsibleParty>
                        <xsl:call-template name="buildResponsibility">
                          <xsl:with-param name="role" select="$mappedRole"/>
                        </xsl:call-template>
                      </cit:citedResponsibleParty>
                    </xsl:when>
                  </xsl:choose>
                </xsl:for-each>
              </cit:CI_Citation>
            </mri:citation>

            <!-- Abstract -->
            <mri:abstract>
              <gco:CharacterString>
                <xsl:choose>
                  <xsl:when test="schema_description != ''">
                    <xsl:value-of select="schema_description"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="schema_name"/>
                  </xsl:otherwise>
                </xsl:choose>
              </gco:CharacterString>
            </mri:abstract>

            <!-- Point of Contact (creators, handle @list wrapper) -->
            <xsl:for-each select="schema_creator[schema_name] | schema_creator/list[schema_name]">
              <mri:pointOfContact>
                <xsl:call-template name="buildResponsibility">
                  <xsl:with-param name="role">author</xsl:with-param>
                </xsl:call-template>
              </mri:pointOfContact>
            </xsl:for-each>

            <!-- Extent: spatial + temporal combined -->
            <xsl:if test="schema_spatialCoverage/schema_geo or schema_temporalCoverage[normalize-space(.) != '']">
              <mri:extent>
                <gex:EX_Extent>
                  <!-- Geographic element -->
                  <xsl:if test="schema_spatialCoverage/schema_geo">
                    <gex:geographicElement>
                      <gex:EX_GeographicBoundingBox>
                        <gex:westBoundLongitude>
                          <gco:Decimal>
                            <xsl:choose>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_box">
                                <xsl:value-of select="tokenize(schema_spatialCoverage/schema_geo/schema_box, '\s+')[2]"/>
                              </xsl:when>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_longitude">
                                <xsl:value-of select="schema_spatialCoverage/schema_geo/schema_longitude"/>
                              </xsl:when>
                              <xsl:otherwise>-180</xsl:otherwise>
                            </xsl:choose>
                          </gco:Decimal>
                        </gex:westBoundLongitude>
                        <gex:eastBoundLongitude>
                          <gco:Decimal>
                            <xsl:choose>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_box">
                                <xsl:value-of select="tokenize(schema_spatialCoverage/schema_geo/schema_box, '\s+')[4]"/>
                              </xsl:when>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_longitude">
                                <xsl:value-of select="schema_spatialCoverage/schema_geo/schema_longitude"/>
                              </xsl:when>
                              <xsl:otherwise>180</xsl:otherwise>
                            </xsl:choose>
                          </gco:Decimal>
                        </gex:eastBoundLongitude>
                        <gex:southBoundLatitude>
                          <gco:Decimal>
                            <xsl:choose>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_box">
                                <xsl:value-of select="tokenize(schema_spatialCoverage/schema_geo/schema_box, '\s+')[1]"/>
                              </xsl:when>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_latitude">
                                <xsl:value-of select="schema_spatialCoverage/schema_geo/schema_latitude"/>
                              </xsl:when>
                              <xsl:otherwise>-90</xsl:otherwise>
                            </xsl:choose>
                          </gco:Decimal>
                        </gex:southBoundLatitude>
                        <gex:northBoundLatitude>
                          <gco:Decimal>
                            <xsl:choose>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_box">
                                <xsl:value-of select="tokenize(schema_spatialCoverage/schema_geo/schema_box, '\s+')[3]"/>
                              </xsl:when>
                              <xsl:when test="schema_spatialCoverage/schema_geo/schema_latitude">
                                <xsl:value-of select="schema_spatialCoverage/schema_geo/schema_latitude"/>
                              </xsl:when>
                              <xsl:otherwise>90</xsl:otherwise>
                            </xsl:choose>
                          </gco:Decimal>
                        </gex:northBoundLatitude>
                      </gex:EX_GeographicBoundingBox>
                    </gex:geographicElement>
                  </xsl:if>

                  <!-- Temporal element -->
                  <xsl:for-each select="schema_temporalCoverage">
                    <xsl:variable name="tempStart">
                      <xsl:choose>
                        <xsl:when test="time_hasBeginning/time_inTimePosition/schema_value != ''">
                          <xsl:value-of select="time_hasBeginning/time_inTimePosition/schema_value"/>
                        </xsl:when>
                        <xsl:when test="time_intervalStartedBy != ''">
                          <xsl:value-of select="time_intervalStartedBy"/>
                        </xsl:when>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="tempEnd">
                      <xsl:choose>
                        <xsl:when test="time_hasEnd/time_inTimePosition/schema_value != ''">
                          <xsl:value-of select="time_hasEnd/time_inTimePosition/schema_value"/>
                        </xsl:when>
                        <xsl:when test="time_intervalFinishedBy != ''">
                          <xsl:value-of select="time_intervalFinishedBy"/>
                        </xsl:when>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:if test="$tempStart != '' or $tempEnd != ''">
                      <gex:temporalElement>
                        <gex:EX_TemporalExtent>
                          <gex:extent>
                            <gml:TimePeriod gml:id="temporal-extent-1">
                              <gml:beginPosition>
                                <xsl:if test="$tempStart = ''">
                                  <xsl:attribute name="indeterminatePosition">unknown</xsl:attribute>
                                </xsl:if>
                                <xsl:value-of select="$tempStart"/>
                              </gml:beginPosition>
                              <gml:endPosition>
                                <xsl:if test="$tempEnd = ''">
                                  <xsl:attribute name="indeterminatePosition">unknown</xsl:attribute>
                                </xsl:if>
                                <xsl:value-of select="$tempEnd"/>
                              </gml:endPosition>
                            </gml:TimePeriod>
                          </gex:extent>
                        </gex:EX_TemporalExtent>
                      </gex:temporalElement>
                    </xsl:if>
                  </xsl:for-each>
                </gex:EX_Extent>
              </mri:extent>
            </xsl:if>

            <!-- Keywords -->
            <xsl:if test="schema_keywords">
              <mri:descriptiveKeywords>
                <mri:MD_Keywords>
                  <xsl:for-each select="schema_keywords">
                    <mri:keyword>
                      <gco:CharacterString>
                        <xsl:choose>
                          <xsl:when test="schema_name"><xsl:value-of select="schema_name"/></xsl:when>
                          <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                        </xsl:choose>
                      </gco:CharacterString>
                    </mri:keyword>
                  </xsl:for-each>
                  <mri:type>
                    <mri:MD_KeywordTypeCode codeListValue="theme"
                                            codeList="./resources/codeList.xml#MD_KeywordTypeCode"/>
                  </mri:type>
                </mri:MD_Keywords>
              </mri:descriptiveKeywords>
            </xsl:if>

            <!-- additionalType as keywords -->
            <xsl:if test="schema_additionalType">
              <mri:descriptiveKeywords>
                <mri:MD_Keywords>
                  <xsl:for-each select="schema_additionalType">
                    <mri:keyword>
                      <gco:CharacterString>
                        <xsl:choose>
                          <xsl:when test="schema_name"><xsl:value-of select="schema_name"/></xsl:when>
                          <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                        </xsl:choose>
                      </gco:CharacterString>
                    </mri:keyword>
                  </xsl:for-each>
                  <mri:type>
                    <mri:MD_KeywordTypeCode codeListValue="theme"
                                            codeList="./resources/codeList.xml#MD_KeywordTypeCode"/>
                  </mri:type>
                </mri:MD_Keywords>
              </mri:descriptiveKeywords>
            </xsl:if>

            <!-- License / Resource Constraints -->
            <xsl:if test="schema_license">
              <mri:resourceConstraints>
                <mco:MD_LegalConstraints>
                  <mco:reference>
                    <cit:CI_Citation>
                      <cit:title>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_license/schema_name">
                              <xsl:value-of select="schema_license/schema_name"/>
                            </xsl:when>
                            <xsl:when test="schema_license/schema_text">
                              <xsl:value-of select="schema_license/schema_text"/>
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:value-of select="schema_license"/>
                            </xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </cit:title>
                      <xsl:if test="schema_license/schema_url or (not(schema_license/*) and starts-with(schema_license, 'http'))">
                        <cit:onlineResource>
                          <cit:CI_OnlineResource>
                            <cit:linkage>
                              <gco:CharacterString>
                                <xsl:choose>
                                  <xsl:when test="schema_license/schema_url">
                                    <xsl:value-of select="schema_license/schema_url"/>
                                  </xsl:when>
                                  <xsl:otherwise>
                                    <xsl:value-of select="schema_license"/>
                                  </xsl:otherwise>
                                </xsl:choose>
                              </gco:CharacterString>
                            </cit:linkage>
                          </cit:CI_OnlineResource>
                        </cit:onlineResource>
                      </xsl:if>
                    </cit:CI_Citation>
                  </mco:reference>
                  <mco:accessConstraints>
                    <mco:MD_RestrictionCode codeListValue="otherRestrictions"
                                            codeList="http://standards.iso.org/iso/19139/resources/gmxCodelists.xml#MD_RestrictionCode"/>
                  </mco:accessConstraints>
                  <mco:useConstraints>
                    <mco:MD_RestrictionCode codeListValue="otherRestrictions"
                                            codeList="http://standards.iso.org/iso/19139/resources/gmxCodelists.xml#MD_RestrictionCode"/>
                  </mco:useConstraints>
                </mco:MD_LegalConstraints>
              </mri:resourceConstraints>
            </xsl:if>

            <!-- conditionsOfAccess (alternative to license) -->
            <xsl:if test="schema_conditionsOfAccess and not(schema_license)">
              <mri:resourceConstraints>
                <mco:MD_LegalConstraints>
                  <mco:otherConstraints>
                    <gco:CharacterString>
                      <xsl:value-of select="schema_conditionsOfAccess"/>
                    </gco:CharacterString>
                  </mco:otherConstraints>
                  <mco:accessConstraints>
                    <mco:MD_RestrictionCode codeListValue="otherRestrictions"
                                            codeList="http://standards.iso.org/iso/19139/resources/gmxCodelists.xml#MD_RestrictionCode"/>
                  </mco:accessConstraints>
                </mco:MD_LegalConstraints>
              </mri:resourceConstraints>
            </xsl:if>

            <!-- Associated Resources (relatedLink) -->
            <xsl:for-each select="schema_relatedLink">
              <xsl:variable name="assocType">
                <xsl:choose>
                  <!-- DefinedTerm: use schema_name or schema_termCode -->
                  <xsl:when test="schema_linkRelationship/schema_name != ''">
                    <xsl:call-template name="mapAssociationType">
                      <xsl:with-param name="relType" select="schema_linkRelationship/schema_name"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:when test="schema_linkRelationship/schema_termCode != ''">
                    <xsl:call-template name="mapAssociationType">
                      <xsl:with-param name="relType" select="schema_linkRelationship/schema_termCode"/>
                    </xsl:call-template>
                  </xsl:when>
                  <!-- Plain string -->
                  <xsl:when test="schema_linkRelationship != ''">
                    <xsl:call-template name="mapAssociationType">
                      <xsl:with-param name="relType" select="schema_linkRelationship"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>crossReference</xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <mri:associatedResource>
                <mri:MD_AssociatedResource>
                  <mri:associationType>
                    <mri:DS_AssociationTypeCode codeList="codeListLocation#DS_AssociationTypeCode"
                                                codeListValue="{$assocType}"/>
                  </mri:associationType>
                  <mri:metadataReference>
                    <cit:CI_Citation>
                      <cit:title>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_name != ''"><xsl:value-of select="schema_name"/></xsl:when>
                            <xsl:when test="schema_target/schema_name != ''"><xsl:value-of select="schema_target/schema_name"/></xsl:when>
                            <xsl:when test="schema_linkRelationship/schema_name != ''"><xsl:value-of select="schema_linkRelationship/schema_name"/></xsl:when>
                            <xsl:otherwise><xsl:value-of select="schema_linkRelationship"/></xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </cit:title>
                      <xsl:variable name="targetUrl">
                        <xsl:choose>
                          <xsl:when test="schema_target/schema_url != ''"><xsl:value-of select="schema_target/schema_url"/></xsl:when>
                          <xsl:when test="schema_target/id != ''"><xsl:value-of select="schema_target/id"/></xsl:when>
                          <xsl:when test="schema_target != '' and starts-with(schema_target, 'http')"><xsl:value-of select="schema_target"/></xsl:when>
                        </xsl:choose>
                      </xsl:variable>
                      <xsl:if test="$targetUrl != ''">
                        <cit:onlineResource>
                          <cit:CI_OnlineResource>
                            <cit:linkage>
                              <gco:CharacterString><xsl:value-of select="$targetUrl"/></gco:CharacterString>
                            </cit:linkage>
                          </cit:CI_OnlineResource>
                        </cit:onlineResource>
                      </xsl:if>
                    </cit:CI_Citation>
                  </mri:metadataReference>
                </mri:MD_AssociatedResource>
              </mri:associatedResource>
            </xsl:for-each>

            <!-- Default Locale for resource -->
            <mri:defaultLocale>
              <lan:PT_Locale>
                <lan:language>
                  <xsl:variable name="resLangCode">
                    <xsl:choose>
                      <xsl:when test="schema_inLanguage != ''">
                        <xsl:call-template name="mapLanguageCode">
                          <xsl:with-param name="lang" select="schema_inLanguage"/>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:otherwise>eng</xsl:otherwise>
                    </xsl:choose>
                  </xsl:variable>
                  <lan:LanguageCode codeList="codeListLocation#LanguageCode"
                                    codeListValue="{$resLangCode}"/>
                </lan:language>
                <lan:characterEncoding>
                  <lan:MD_CharacterSetCode codeList="codeListLocation#MD_CharacterSetCode"
                                           codeListValue="utf8"/>
                </lan:characterEncoding>
              </lan:PT_Locale>
            </mri:defaultLocale>

            <!-- Supplemental Information (funding, measurementTechnique, publishingPrinciples, variable summaries) -->
            <xsl:variable name="supplementalText">
              <xsl:call-template name="buildSupplementalInformation"/>
            </xsl:variable>
            <xsl:if test="normalize-space($supplementalText) != ''">
              <mri:supplementalInformation>
                <gco:CharacterString><xsl:value-of select="$supplementalText"/></gco:CharacterString>
              </mri:supplementalInformation>
            </xsl:if>

          </mri:MD_DataIdentification>
        </mdb:identificationInfo>

        <!-- ================================================================
             10. contentInfo — Feature Catalogue (variableMeasured)
             ================================================================ -->
        <xsl:if test="schema_variableMeasured">
          <mdb:contentInfo>
            <mrc:MD_FeatureCatalogue>
              <mrc:featureCatalogue>
                <gfc:FC_FeatureCatalogue>
                  <cat:name>
                    <gco:CharacterString><xsl:value-of select="schema_name"/></gco:CharacterString>
                  </cat:name>
                  <cat:scope>
                    <gco:CharacterString>dataset</gco:CharacterString>
                  </cat:scope>
                  <cat:versionNumber>
                    <gco:CharacterString><xsl:value-of select="if (schema_version != '') then schema_version else '1.0'"/></gco:CharacterString>
                  </cat:versionNumber>
                  <cat:versionDate>
                    <gco:Date><xsl:value-of select="if (schema_datePublished != '') then schema_datePublished else format-date(current-date(), '[Y0001]-[M01]-[D01]')"/></gco:Date>
                  </cat:versionDate>
                  <gfc:producer/>
                  <gfc:featureType>
                    <gfc:FC_FeatureType>
                      <gfc:typeName>
                        <xsl:value-of select="schema_name"/>
                      </gfc:typeName>
                      <gfc:isAbstract>
                        <gco:Boolean>false</gco:Boolean>
                      </gfc:isAbstract>
                      <xsl:for-each select="schema_variableMeasured">
                        <gfc:carrierOfCharacteristics>
                          <gfc:FC_FeatureAttribute>
                            <gfc:memberName>
                              <xsl:choose>
                                <xsl:when test="schema_name != ''"><xsl:value-of select="schema_name"/></xsl:when>
                                <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                              </xsl:choose>
                            </gfc:memberName>
                            <xsl:if test="schema_description != ''">
                              <gfc:definition>
                                <gco:CharacterString><xsl:value-of select="schema_description"/></gco:CharacterString>
                              </gfc:definition>
                            </xsl:if>
                            <gfc:cardinality>
                              <gco:CharacterString>0..*</gco:CharacterString>
                            </gfc:cardinality>
                            <xsl:if test="schema_propertyID">
                              <gfc:code>
                                <gco:CharacterString>
                                  <xsl:choose>
                                    <xsl:when test="schema_propertyID/id != ''"><xsl:value-of select="schema_propertyID/id"/></xsl:when>
                                    <xsl:when test="schema_propertyID/schema_value != ''"><xsl:value-of select="schema_propertyID/schema_value"/></xsl:when>
                                    <xsl:otherwise><xsl:value-of select="schema_propertyID"/></xsl:otherwise>
                                  </xsl:choose>
                                </gco:CharacterString>
                              </gfc:code>
                            </xsl:if>
                            <xsl:if test="cdi_intendedDataType != ''">
                              <gfc:valueType>
                                <gco:TypeName>
                                  <gco:aName>
                                    <gco:CharacterString><xsl:value-of select="cdi_intendedDataType"/></gco:CharacterString>
                                  </gco:aName>
                                </gco:TypeName>
                              </gfc:valueType>
                            </xsl:if>
                            <xsl:if test="schema_unitText != '' or schema_unitCode != ''">
                              <gfc:valueMeasurementUnit>
                                <gco:UomIdentifier>
                                  <xsl:choose>
                                    <xsl:when test="schema_unitCode != ''"><xsl:value-of select="schema_unitCode"/></xsl:when>
                                    <xsl:otherwise><xsl:value-of select="schema_unitText"/></xsl:otherwise>
                                  </xsl:choose>
                                </gco:UomIdentifier>
                              </gfc:valueMeasurementUnit>
                            </xsl:if>
                          </gfc:FC_FeatureAttribute>
                        </gfc:carrierOfCharacteristics>
                      </xsl:for-each>
                      <gfc:featureCatalogue/>
                    </gfc:FC_FeatureType>
                  </gfc:featureType>
                </gfc:FC_FeatureCatalogue>
              </mrc:featureCatalogue>
            </mrc:MD_FeatureCatalogue>
          </mdb:contentInfo>
        </xsl:if>

        <!-- ================================================================
             11. distributionInfo
             ================================================================ -->
        <xsl:if test="schema_distribution or schema_url">
          <mdb:distributionInfo>
            <mrd:MD_Distribution>
              <!-- Distribution formats: top-level only, component file formats
                   are carried in cit:protocol on their onLine resources -->
              <xsl:for-each select="distinct-values(
                  schema_distribution/schema_encodingFormat[normalize-space(.) != ''])">
                <mrd:distributionFormat>
                  <mrd:MD_Format>
                    <mrd:formatSpecificationCitation>
                      <cit:CI_Citation>
                        <cit:title>
                          <gco:CharacterString>
                            <xsl:value-of select="."/>
                          </gco:CharacterString>
                        </cit:title>
                      </cit:CI_Citation>
                    </mrd:formatSpecificationCitation>
                  </mrd:MD_Format>
                </mrd:distributionFormat>
              </xsl:for-each>

              <!-- Transfer options from schema_distribution -->
              <xsl:for-each select="schema_distribution">
                <xsl:if test="schema_contentUrl != ''">
                  <xsl:variable name="archiveUrl" select="schema_contentUrl"/>
                  <mrd:transferOptions>
                    <mrd:MD_DigitalTransferOptions>
                      <!-- Transfer size from cdi_fileSize -->
                      <xsl:if test="cdi_fileSize != ''">
                        <mrd:transferSize>
                          <gco:Real>
                            <xsl:call-template name="convertToMegabytes">
                              <xsl:with-param name="size" select="cdi_fileSize"/>
                              <xsl:with-param name="unit" select="cdi_fileSizeUofM"/>
                            </xsl:call-template>
                          </gco:Real>
                        </mrd:transferSize>
                      </xsl:if>
                      <!-- Primary resource: the distribution itself -->
                      <mrd:onLine>
                        <cit:CI_OnlineResource>
                          <cit:linkage>
                            <gco:CharacterString>
                              <xsl:value-of select="schema_contentUrl"/>
                            </gco:CharacterString>
                          </cit:linkage>
                          <cit:protocol>
                            <gco:CharacterString>
                              <xsl:choose>
                                <xsl:when test="starts-with(schema_contentUrl, 'https')">https</xsl:when>
                                <xsl:when test="starts-with(schema_contentUrl, 'http')">http</xsl:when>
                                <xsl:when test="starts-with(schema_contentUrl, 'ftp')">ftp</xsl:when>
                                <xsl:otherwise>https</xsl:otherwise>
                              </xsl:choose>
                            </gco:CharacterString>
                          </cit:protocol>
                          <xsl:if test="schema_name != ''">
                            <cit:name>
                              <gco:CharacterString>
                                <xsl:value-of select="schema_name"/>
                              </gco:CharacterString>
                            </cit:name>
                          </xsl:if>
                          <xsl:if test="normalize-space(schema_description) != '' or cdi_characterSet != ''">
                            <cit:description>
                              <gco:CharacterString>
                                <xsl:value-of select="schema_description"/>
                                <xsl:if test="normalize-space(schema_description) != '' and cdi_characterSet != ''">
                                  <xsl:text> </xsl:text>
                                </xsl:if>
                                <xsl:if test="cdi_characterSet != ''">
                                  <xsl:text>[characterSet: </xsl:text>
                                  <xsl:value-of select="cdi_characterSet"/>
                                  <xsl:text>]</xsl:text>
                                </xsl:if>
                              </gco:CharacterString>
                            </cit:description>
                          </xsl:if>
                          <xsl:if test="schema_hasPart[schema_name != '']">
                            <cit:function>
                              <cit:CI_OnLineFunctionCode codeList="codeListLocation#CI_OnLineFunctionCode"
                                                         codeListValue="download"/>
                            </cit:function>
                          </xsl:if>
                        </cit:CI_OnlineResource>
                      </mrd:onLine>
                      <!-- Archive component files from hasPart (function=information) -->
                      <xsl:for-each select="schema_hasPart[schema_name != '']">
                        <mrd:onLine>
                          <cit:CI_OnlineResource>
                            <cit:linkage>
                              <gco:CharacterString>http://www.opengis.net/def/nil/OGC/0/inapplicable</gco:CharacterString>
                            </cit:linkage>
                            <xsl:if test="schema_encodingFormat != ''">
                              <cit:protocol>
                                <gco:CharacterString>
                                  <xsl:value-of select="schema_encodingFormat"/>
                                </gco:CharacterString>
                              </cit:protocol>
                            </xsl:if>
                            <cit:name>
                              <gco:CharacterString>
                                <xsl:value-of select="schema_name"/>
                              </gco:CharacterString>
                            </cit:name>
                            <xsl:variable name="partDesc">
                              <xsl:if test="normalize-space(schema_description) != ''">
                                <xsl:value-of select="schema_description"/>
                              </xsl:if>
                              <xsl:if test="schema_size/schema_value != ''">
                                <xsl:if test="normalize-space(schema_description) != ''">
                                  <xsl:text> </xsl:text>
                                </xsl:if>
                                <xsl:text>[size: </xsl:text>
                                <xsl:value-of select="schema_size/schema_value"/>
                                <xsl:if test="schema_size/schema_unitText != ''">
                                  <xsl:text> </xsl:text>
                                  <xsl:value-of select="schema_size/schema_unitText"/>
                                </xsl:if>
                                <xsl:text>]</xsl:text>
                              </xsl:if>
                            </xsl:variable>
                            <xsl:if test="normalize-space($partDesc) != ''">
                              <cit:description>
                                <gco:CharacterString>
                                  <xsl:value-of select="$partDesc"/>
                                </gco:CharacterString>
                              </cit:description>
                            </xsl:if>
                            <cit:function>
                              <cit:CI_OnLineFunctionCode codeList="codeListLocation#CI_OnLineFunctionCode"
                                                         codeListValue="information"/>
                            </cit:function>
                          </cit:CI_OnlineResource>
                        </mrd:onLine>
                      </xsl:for-each>
                    </mrd:MD_DigitalTransferOptions>
                  </mrd:transferOptions>
                </xsl:if>
              </xsl:for-each>

              <!-- Simple URL fallback -->
              <xsl:if test="schema_url and not(schema_distribution/schema_contentUrl)">
                <mrd:transferOptions>
                  <mrd:MD_DigitalTransferOptions>
                    <mrd:onLine>
                      <cit:CI_OnlineResource>
                        <cit:linkage>
                          <gco:CharacterString>
                            <xsl:value-of select="schema_url"/>
                          </gco:CharacterString>
                        </cit:linkage>
                      </cit:CI_OnlineResource>
                    </mrd:onLine>
                  </mrd:MD_DigitalTransferOptions>
                </mrd:transferOptions>
              </xsl:if>
            </mrd:MD_Distribution>
          </mdb:distributionInfo>
        </xsl:if>

        <!-- ================================================================
             12. dataQualityInfo (from dqv_hasQualityMeasurement)
             ================================================================ -->
        <xsl:if test="dqv_hasQualityMeasurement">
          <mdb:dataQualityInfo>
            <mdq:DQ_DataQuality>
              <mdq:scope>
                <mcc:MD_Scope>
                  <mcc:level>
                    <mcc:MD_ScopeCode codeList="codeListLocation#MD_ScopeCode" codeListValue="dataset"/>
                  </mcc:level>
                </mcc:MD_Scope>
              </mdq:scope>
              <xsl:for-each select="dqv_hasQualityMeasurement">
                <mdq:report>
                  <mdq:DQ_UsabilityElement>
                    <xsl:if test="dqv_isMeasurementOf">
                      <mdq:measure>
                        <mdq:DQ_MeasureReference>
                          <mdq:nameOfMeasure>
                            <gco:CharacterString>
                              <xsl:choose>
                                <xsl:when test="dqv_isMeasurementOf/schema_name != ''">
                                  <xsl:value-of select="dqv_isMeasurementOf/schema_name"/>
                                </xsl:when>
                                <xsl:when test="dqv_isMeasurementOf/id != ''">
                                  <xsl:value-of select="dqv_isMeasurementOf/id"/>
                                </xsl:when>
                                <xsl:otherwise>
                                  <xsl:value-of select="dqv_isMeasurementOf"/>
                                </xsl:otherwise>
                              </xsl:choose>
                            </gco:CharacterString>
                          </mdq:nameOfMeasure>
                        </mdq:DQ_MeasureReference>
                      </mdq:measure>
                    </xsl:if>
                    <xsl:if test="dqv_value">
                      <mdq:result>
                        <mdq:DQ_DescriptiveResult>
                          <mdq:statement>
                            <gco:CharacterString>
                              <xsl:choose>
                                <!-- PropertyValue with schema_value -->
                                <xsl:when test="dqv_value/schema_value != ''">
                                  <xsl:value-of select="dqv_value/schema_value"/>
                                </xsl:when>
                                <!-- DefinedTerm with schema_name -->
                                <xsl:when test="dqv_value/schema_name != ''">
                                  <xsl:value-of select="dqv_value/schema_name"/>
                                </xsl:when>
                                <!-- Plain string -->
                                <xsl:otherwise>
                                  <xsl:value-of select="dqv_value"/>
                                </xsl:otherwise>
                              </xsl:choose>
                            </gco:CharacterString>
                          </mdq:statement>
                        </mdq:DQ_DescriptiveResult>
                      </mdq:result>
                    </xsl:if>
                  </mdq:DQ_UsabilityElement>
                </mdq:report>
              </xsl:for-each>
            </mdq:DQ_DataQuality>
          </mdb:dataQualityInfo>
        </xsl:if>

        <!-- ================================================================
             13. resourceLineage (from prov_wasGeneratedBy / prov_wasDerivedFrom)
             ================================================================ -->
        <mdb:resourceLineage>
          <mrl:LI_Lineage>
            <xsl:choose>
              <xsl:when test="prov_wasGeneratedBy or prov_wasDerivedFrom">
                <!-- statement: auto-generated summary from activity descriptions -->
                <mrl:statement>
                  <gco:CharacterString>
                    <xsl:for-each select="prov_wasGeneratedBy">
                      <xsl:if test="schema_description != '' or schema_name != ''">
                        <xsl:if test="position() > 1"><xsl:text>; </xsl:text></xsl:if>
                        <xsl:choose>
                          <xsl:when test="schema_description != ''"><xsl:value-of select="schema_description"/></xsl:when>
                          <xsl:otherwise><xsl:value-of select="schema_name"/></xsl:otherwise>
                        </xsl:choose>
                      </xsl:if>
                    </xsl:for-each>
                  </gco:CharacterString>
                </mrl:statement>

                <!-- scope (required position per XSD: after statement, before source) -->
                <mrl:scope>
                  <mcc:MD_Scope>
                    <mcc:level>
                      <mcc:MD_ScopeCode codeList="codeListLocation#MD_ScopeCode" codeListValue="dataset"/>
                    </mcc:level>
                  </mcc:MD_Scope>
                </mrl:scope>

                <!-- Sources from prov_wasDerivedFrom (XSD order: source before processStep) -->
                <xsl:for-each select="prov_wasDerivedFrom">
                  <mrl:source>
                    <mrl:LI_Source>
                      <mrl:description>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_description != ''"><xsl:value-of select="schema_description"/></xsl:when>
                            <xsl:when test="schema_name != ''"><xsl:value-of select="schema_name"/></xsl:when>
                            <xsl:when test="id != ''"><xsl:value-of select="id"/></xsl:when>
                            <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </mrl:description>
                      <xsl:variable name="sourceUrl">
                        <xsl:choose>
                          <xsl:when test="schema_url != ''"><xsl:value-of select="schema_url"/></xsl:when>
                          <xsl:when test="id != '' and starts-with(id, 'http')"><xsl:value-of select="id"/></xsl:when>
                        </xsl:choose>
                      </xsl:variable>
                      <xsl:if test="$sourceUrl != '' or schema_name != ''">
                        <mrl:sourceCitation>
                          <cit:CI_Citation>
                            <cit:title>
                              <gco:CharacterString>
                                <xsl:choose>
                                  <xsl:when test="schema_name != ''"><xsl:value-of select="schema_name"/></xsl:when>
                                  <xsl:otherwise><xsl:value-of select="$sourceUrl"/></xsl:otherwise>
                                </xsl:choose>
                              </gco:CharacterString>
                            </cit:title>
                            <xsl:if test="$sourceUrl != ''">
                              <cit:onlineResource>
                                <cit:CI_OnlineResource>
                                  <cit:linkage>
                                    <gco:CharacterString><xsl:value-of select="$sourceUrl"/></gco:CharacterString>
                                  </cit:linkage>
                                </cit:CI_OnlineResource>
                              </cit:onlineResource>
                            </xsl:if>
                          </cit:CI_Citation>
                        </mrl:sourceCitation>
                      </xsl:if>
                    </mrl:LI_Source>
                  </mrl:source>
                </xsl:for-each>

                <!-- Process steps from prov_wasGeneratedBy -->
                <xsl:for-each select="prov_wasGeneratedBy">
                  <mrl:processStep>
                    <mrl:LI_ProcessStep>
                      <mrl:description>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_description != ''"><xsl:value-of select="schema_description"/></xsl:when>
                            <xsl:when test="schema_name != ''"><xsl:value-of select="schema_name"/></xsl:when>
                            <xsl:otherwise>Processing activity</xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </mrl:description>
                      <xsl:if test="schema_endTime != ''">
                        <mrl:stepDateTime>
                          <gml:TimeInstant gml:id="step-time-{position()}">
                            <gml:timePosition><xsl:value-of select="schema_endTime"/></gml:timePosition>
                          </gml:TimeInstant>
                        </mrl:stepDateTime>
                      </xsl:if>
                      <!-- Sources from prov:used -->
                      <xsl:for-each select="prov_used">
                        <mrl:source>
                          <mrl:LI_Source>
                            <mrl:description>
                              <gco:CharacterString>
                                <xsl:choose>
                                  <xsl:when test="schema_description != ''"><xsl:value-of select="schema_description"/></xsl:when>
                                  <xsl:when test="schema_name != ''"><xsl:value-of select="schema_name"/></xsl:when>
                                  <xsl:when test="id != ''"><xsl:value-of select="id"/></xsl:when>
                                  <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                                </xsl:choose>
                              </gco:CharacterString>
                            </mrl:description>
                          </mrl:LI_Source>
                        </mrl:source>
                      </xsl:for-each>
                    </mrl:LI_ProcessStep>
                  </mrl:processStep>
                </xsl:for-each>
              </xsl:when>
              <xsl:otherwise>
                <!-- Empty fallback when no provenance properties exist -->
                <mrl:statement>
                  <gco:CharacterString/>
                </mrl:statement>
              </xsl:otherwise>
            </xsl:choose>
          </mrl:LI_Lineage>
        </mdb:resourceLineage>
      </mdb:MD_Metadata>
    </xsl:template>


    <!-- ==================================================================
         Named template: formatDateOrDateTime
         Output gco:Date for date-only values (YYYY-MM-DD), gco:DateTime
         for full datetime values (containing 'T').
         ================================================================== -->
    <xsl:template name="formatDateOrDateTime">
      <xsl:param name="dateValue"/>
      <xsl:choose>
        <xsl:when test="contains($dateValue, 'T')">
          <gco:DateTime><xsl:value-of select="$dateValue"/></gco:DateTime>
        </xsl:when>
        <xsl:otherwise>
          <gco:Date><xsl:value-of select="$dateValue"/></gco:Date>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <!-- ==================================================================
         Named template: mapLanguageCode
         Map 2-letter ISO 639-1 codes to 3-letter ISO 639-2/B codes
         ================================================================== -->
    <xsl:template name="mapLanguageCode">
      <xsl:param name="lang"/>
      <xsl:variable name="lc" select="lower-case(normalize-space($lang))"/>
      <xsl:choose>
        <xsl:when test="string-length($lc) = 3"><xsl:value-of select="$lc"/></xsl:when>
        <xsl:when test="$lc = 'en'">eng</xsl:when>
        <xsl:when test="$lc = 'fr'">fra</xsl:when>
        <xsl:when test="$lc = 'de'">deu</xsl:when>
        <xsl:when test="$lc = 'es'">spa</xsl:when>
        <xsl:when test="$lc = 'it'">ita</xsl:when>
        <xsl:when test="$lc = 'pt'">por</xsl:when>
        <xsl:when test="$lc = 'nl'">nld</xsl:when>
        <xsl:when test="$lc = 'ru'">rus</xsl:when>
        <xsl:when test="$lc = 'zh'">zho</xsl:when>
        <xsl:when test="$lc = 'ja'">jpn</xsl:when>
        <xsl:when test="$lc = 'ko'">kor</xsl:when>
        <xsl:when test="$lc = 'ar'">ara</xsl:when>
        <xsl:when test="$lc = 'pl'">pol</xsl:when>
        <xsl:when test="$lc = 'sv'">swe</xsl:when>
        <xsl:when test="$lc = 'no'">nor</xsl:when>
        <xsl:when test="$lc = 'da'">dan</xsl:when>
        <xsl:when test="$lc = 'fi'">fin</xsl:when>
        <xsl:when test="$lc = 'el'">gre</xsl:when>
        <xsl:when test="$lc = 'cs'">cze</xsl:when>
        <xsl:when test="$lc = 'tr'">tur</xsl:when>
        <xsl:when test="$lc = 'hu'">hun</xsl:when>
        <xsl:when test="$lc = 'ro'">rum</xsl:when>
        <xsl:when test="$lc = 'uk'">ukr</xsl:when>
        <xsl:when test="$lc = 'vi'">vie</xsl:when>
        <xsl:when test="$lc = 'th'">tha</xsl:when>
        <xsl:when test="$lc = 'hi'">hin</xsl:when>
        <xsl:otherwise>eng</xsl:otherwise>
      </xsl:choose>
    </xsl:template>


    <!-- ==================================================================
         Named template: mapRoleName
         Map CDIF/schema.org roleName values to ISO CI_RoleCode
         ================================================================== -->
    <xsl:template name="mapRoleName">
      <xsl:param name="roleName"/>
      <xsl:variable name="lc" select="lower-case(normalize-space($roleName))"/>
      <xsl:choose>
        <xsl:when test="$lc = 'contributor'">contributor</xsl:when>
        <xsl:when test="$lc = 'editor'">editor</xsl:when>
        <xsl:when test="$lc = 'funder' or $lc = 'funding agency'">funder</xsl:when>
        <xsl:when test="$lc = 'principal investigator' or $lc = 'principalinvestigator' or $lc = 'pi'">principalInvestigator</xsl:when>
        <xsl:when test="$lc = 'publisher'">publisher</xsl:when>
        <xsl:when test="$lc = 'author' or $lc = 'creator'">author</xsl:when>
        <xsl:when test="$lc = 'custodian'">custodian</xsl:when>
        <xsl:when test="$lc = 'distributor'">distributor</xsl:when>
        <xsl:when test="$lc = 'originator'">originator</xsl:when>
        <xsl:when test="$lc = 'point of contact' or $lc = 'pointofcontact' or $lc = 'contact'">pointOfContact</xsl:when>
        <xsl:when test="$lc = 'processor'">processor</xsl:when>
        <xsl:when test="$lc = 'resource provider' or $lc = 'resourceprovider'">resourceProvider</xsl:when>
        <xsl:when test="$lc = 'user'">user</xsl:when>
        <xsl:when test="$lc = 'sponsor'">sponsor</xsl:when>
        <xsl:when test="$lc = 'collaborator'">collaborator</xsl:when>
        <xsl:when test="$lc = 'stakeholder'">stakeholder</xsl:when>
        <xsl:when test="$lc = 'coauthor' or $lc = 'co-author'">coAuthor</xsl:when>
        <xsl:when test="$lc = 'rights holder' or $lc = 'rightsholder'">rightsHolder</xsl:when>
        <xsl:when test="$lc = 'mediator'">mediator</xsl:when>
        <xsl:otherwise>contributor</xsl:otherwise>
      </xsl:choose>
    </xsl:template>


    <!-- ==================================================================
         Named template: mapAssociationType
         Map relationship types to ISO DS_AssociationTypeCode
         ================================================================== -->
    <xsl:template name="mapAssociationType">
      <xsl:param name="relType"/>
      <xsl:variable name="lc" select="lower-case(normalize-space($relType))"/>
      <xsl:choose>
        <xsl:when test="$lc = 'ispartof' or $lc = 'is part of'">largerWorkCitation</xsl:when>
        <xsl:when test="$lc = 'haspart' or $lc = 'has part'">partOfSeamlessDatabase</xsl:when>
        <xsl:when test="$lc = 'references'">crossReference</xsl:when>
        <xsl:when test="$lc = 'isreferencedby' or $lc = 'is referenced by'">crossReference</xsl:when>
        <xsl:when test="$lc = 'isbasedon' or $lc = 'is based on'">dependency</xsl:when>
        <xsl:when test="$lc = 'isbasisfor' or $lc = 'is basis for'">revisionOf</xsl:when>
        <xsl:when test="$lc = 'issupplementto' or $lc = 'is supplement to'">isComposedOf</xsl:when>
        <xsl:when test="$lc = 'issupplementedby' or $lc = 'is supplemented by'">isComposedOf</xsl:when>
        <xsl:when test="contains($lc, 'stereo')">stereoMate</xsl:when>
        <xsl:otherwise>crossReference</xsl:otherwise>
      </xsl:choose>
    </xsl:template>


    <!-- ==================================================================
         Named template: buildSupplementalInformation
         Collect funding, measurementTechnique, publishingPrinciples,
         and variable summaries into a structured text block
         ================================================================== -->
    <xsl:template name="buildSupplementalInformation">
      <!-- Funding -->
      <xsl:if test="schema_funding">
        <xsl:text>FUNDING: </xsl:text>
        <xsl:for-each select="schema_funding">
          <xsl:if test="position() > 1"><xsl:text>; </xsl:text></xsl:if>
          <xsl:if test="schema_name != ''">
            <xsl:value-of select="schema_name"/>
          </xsl:if>
          <xsl:if test="schema_funder/schema_name != ''">
            <xsl:text> (funder: </xsl:text>
            <xsl:value-of select="schema_funder/schema_name"/>
            <xsl:text>)</xsl:text>
          </xsl:if>
          <xsl:if test="schema_identifier">
            <xsl:text> [</xsl:text>
            <xsl:choose>
              <xsl:when test="schema_identifier/schema_value != ''">
                <xsl:value-of select="schema_identifier/schema_value"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="schema_identifier"/>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:text>]</xsl:text>
          </xsl:if>
        </xsl:for-each>
        <xsl:text>
</xsl:text>
      </xsl:if>

      <!-- Measurement Technique -->
      <xsl:if test="schema_measurementTechnique[normalize-space(.) != '']">
        <xsl:text>MEASUREMENT TECHNIQUE: </xsl:text>
        <xsl:for-each select="schema_measurementTechnique[normalize-space(.) != '']">
          <xsl:if test="position() > 1"><xsl:text>; </xsl:text></xsl:if>
          <xsl:choose>
            <xsl:when test="schema_name != ''">
              <xsl:value-of select="schema_name"/>
              <xsl:if test="schema_identifier/schema_value != ''">
                <xsl:text> [</xsl:text><xsl:value-of select="schema_identifier/schema_value"/><xsl:text>]</xsl:text>
              </xsl:if>
              <xsl:if test="schema_identifier[not(schema_value)] != '' and not(schema_identifier/*)">
                <xsl:text> [</xsl:text><xsl:value-of select="schema_identifier"/><xsl:text>]</xsl:text>
              </xsl:if>
            </xsl:when>
            <xsl:when test="schema_description != ''"><xsl:value-of select="schema_description"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
        <xsl:text>
</xsl:text>
      </xsl:if>

      <!-- Publishing Principles -->
      <xsl:if test="schema_publishingPrinciples[normalize-space(.) != '']">
        <xsl:text>PUBLISHING PRINCIPLES: </xsl:text>
        <xsl:for-each select="schema_publishingPrinciples[normalize-space(.) != '']">
          <xsl:if test="position() > 1"><xsl:text>; </xsl:text></xsl:if>
          <xsl:choose>
            <xsl:when test="schema_name != ''"><xsl:value-of select="schema_name"/></xsl:when>
            <xsl:when test="id != ''"><xsl:value-of select="id"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
        <xsl:text>
</xsl:text>
      </xsl:if>

      <!-- Variable summaries (name, unit, range) -->
      <xsl:if test="schema_variableMeasured[schema_name]">
        <xsl:text>VARIABLES MEASURED: </xsl:text>
        <xsl:for-each select="schema_variableMeasured[schema_name]">
          <xsl:if test="position() > 1"><xsl:text>; </xsl:text></xsl:if>
          <xsl:value-of select="schema_name"/>
          <xsl:if test="schema_unitText != ''">
            <xsl:text> (</xsl:text>
            <xsl:value-of select="schema_unitText"/>
            <xsl:text>)</xsl:text>
          </xsl:if>
          <xsl:if test="schema_minValue != '' or schema_maxValue != ''">
            <xsl:text> [</xsl:text>
            <xsl:value-of select="schema_minValue"/>
            <xsl:text>..</xsl:text>
            <xsl:value-of select="schema_maxValue"/>
            <xsl:text>]</xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:if>
    </xsl:template>


    <!-- ==================================================================
         Named template: convertToMegabytes
         Convert file size with unit string to megabytes (Real)
         ================================================================== -->
    <xsl:template name="convertToMegabytes">
      <xsl:param name="size"/>
      <xsl:param name="unit"/>
      <xsl:variable name="numSize" select="number($size)"/>
      <xsl:variable name="lcUnit" select="lower-case(normalize-space($unit))"/>
      <xsl:choose>
        <xsl:when test="$lcUnit = 'bytes' or $lcUnit = 'byte' or $lcUnit = 'b'">
          <xsl:value-of select="format-number($numSize div 1048576, '#.######')"/>
        </xsl:when>
        <xsl:when test="$lcUnit = 'kb' or $lcUnit = 'kilobytes' or $lcUnit = 'kilobyte'">
          <xsl:value-of select="format-number($numSize div 1024, '#.######')"/>
        </xsl:when>
        <xsl:when test="$lcUnit = 'gb' or $lcUnit = 'gigabytes' or $lcUnit = 'gigabyte'">
          <xsl:value-of select="format-number($numSize * 1024, '#.######')"/>
        </xsl:when>
        <xsl:when test="$lcUnit = 'tb' or $lcUnit = 'terabytes' or $lcUnit = 'terabyte'">
          <xsl:value-of select="format-number($numSize * 1048576, '#.######')"/>
        </xsl:when>
        <!-- Default: assume MB -->
        <xsl:otherwise>
          <xsl:value-of select="$numSize"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>


    <!-- ==================================================================
         Named template: buildResponsibility
         Build a CI_Responsibility from a person/organization context node
         ================================================================== -->
    <xsl:template name="buildResponsibility">
      <xsl:param name="role" select="'author'"/>

      <cit:CI_Responsibility>
        <cit:role>
          <cit:CI_RoleCode codeList="codeListLocation#CI_RoleCode" codeListValue="{$role}"/>
        </cit:role>
        <cit:party>
          <xsl:choose>
            <!-- Person with @type containing Person -->
            <xsl:when test="type[contains(., 'Person')]">
              <cit:CI_Individual>
                <cit:name>
                  <gco:CharacterString>
                    <xsl:value-of select="schema_name"/>
                  </gco:CharacterString>
                </cit:name>
                <xsl:if test="schema_email != '' or schema_contactPoint/schema_email != ''">
                  <cit:contactInfo>
                    <cit:CI_Contact>
                      <cit:address>
                        <cit:CI_Address>
                          <cit:electronicMailAddress>
                            <gco:CharacterString>
                              <xsl:choose>
                                <xsl:when test="schema_email != ''"><xsl:value-of select="schema_email"/></xsl:when>
                                <xsl:otherwise><xsl:value-of select="schema_contactPoint[1]/schema_email"/></xsl:otherwise>
                              </xsl:choose>
                            </gco:CharacterString>
                          </cit:electronicMailAddress>
                        </cit:CI_Address>
                      </cit:address>
                    </cit:CI_Contact>
                  </cit:contactInfo>
                </xsl:if>
                <!-- ORCID or other identifier -->
                <xsl:if test="schema_identifier">
                  <cit:partyIdentifier>
                    <mcc:MD_Identifier>
                      <mcc:code>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_identifier/schema_value">
                              <xsl:value-of select="schema_identifier/schema_value"/>
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:value-of select="schema_identifier"/>
                            </xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </mcc:code>
                      <xsl:if test="schema_identifier/schema_propertyID">
                        <mcc:codeSpace>
                          <gco:CharacterString>
                            <xsl:value-of select="schema_identifier/schema_propertyID"/>
                          </gco:CharacterString>
                        </mcc:codeSpace>
                      </xsl:if>
                    </mcc:MD_Identifier>
                  </cit:partyIdentifier>
                </xsl:if>
              </cit:CI_Individual>
            </xsl:when>
            <!-- Organization -->
            <xsl:when test="type[contains(., 'Organization')]">
              <cit:CI_Organisation>
                <cit:name>
                  <gco:CharacterString>
                    <xsl:value-of select="schema_name"/>
                  </gco:CharacterString>
                </cit:name>
                <xsl:if test="schema_email != '' or schema_contactPoint/schema_email != ''">
                  <cit:contactInfo>
                    <cit:CI_Contact>
                      <cit:address>
                        <cit:CI_Address>
                          <cit:electronicMailAddress>
                            <gco:CharacterString>
                              <xsl:choose>
                                <xsl:when test="schema_email != ''"><xsl:value-of select="schema_email"/></xsl:when>
                                <xsl:otherwise><xsl:value-of select="schema_contactPoint[1]/schema_email"/></xsl:otherwise>
                              </xsl:choose>
                            </gco:CharacterString>
                          </cit:electronicMailAddress>
                        </cit:CI_Address>
                      </cit:address>
                    </cit:CI_Contact>
                  </cit:contactInfo>
                </xsl:if>
                <xsl:if test="schema_identifier">
                  <cit:partyIdentifier>
                    <mcc:MD_Identifier>
                      <mcc:code>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_identifier/schema_value">
                              <xsl:value-of select="schema_identifier/schema_value"/>
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:value-of select="schema_identifier"/>
                            </xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </mcc:code>
                    </mcc:MD_Identifier>
                  </cit:partyIdentifier>
                </xsl:if>
              </cit:CI_Organisation>
            </xsl:when>
            <!-- Default: treat as Individual -->
            <xsl:otherwise>
              <cit:CI_Individual>
                <cit:name>
                  <gco:CharacterString>
                    <xsl:value-of select="schema_name"/>
                  </gco:CharacterString>
                </cit:name>
                <xsl:if test="schema_email != '' or schema_contactPoint/schema_email != ''">
                  <cit:contactInfo>
                    <cit:CI_Contact>
                      <cit:address>
                        <cit:CI_Address>
                          <cit:electronicMailAddress>
                            <gco:CharacterString>
                              <xsl:choose>
                                <xsl:when test="schema_email != ''"><xsl:value-of select="schema_email"/></xsl:when>
                                <xsl:otherwise><xsl:value-of select="schema_contactPoint[1]/schema_email"/></xsl:otherwise>
                              </xsl:choose>
                            </gco:CharacterString>
                          </cit:electronicMailAddress>
                        </cit:CI_Address>
                      </cit:address>
                    </cit:CI_Contact>
                  </cit:contactInfo>
                </xsl:if>
                <xsl:if test="schema_identifier">
                  <cit:partyIdentifier>
                    <mcc:MD_Identifier>
                      <mcc:code>
                        <gco:CharacterString>
                          <xsl:choose>
                            <xsl:when test="schema_identifier/schema_value">
                              <xsl:value-of select="schema_identifier/schema_value"/>
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:value-of select="schema_identifier"/>
                            </xsl:otherwise>
                          </xsl:choose>
                        </gco:CharacterString>
                      </mcc:code>
                    </mcc:MD_Identifier>
                  </cit:partyIdentifier>
                </xsl:if>
              </cit:CI_Individual>
            </xsl:otherwise>
          </xsl:choose>
        </cit:party>
      </cit:CI_Responsibility>
    </xsl:template>
</xsl:stylesheet>
