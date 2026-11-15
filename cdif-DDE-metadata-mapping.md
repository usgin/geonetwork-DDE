<!-- Converted from cdif-DDE-metadata-mapping.docx on 2026-11-15 by
     tools/docx_to_md.py. THIS FILE IS THE SOURCE OF TRUTH; the .docx is kept
     only as the historical original.

     The "Harvester Status" claims are checked against the converters by
     tools/check_mapping_doc.py. Run it after changing either
     convert/fromJsonCdif.xsl or formatter/cdif/iso19115-3-to-cdif.xsl. -->

# CDIF to DDE ISO 19115-3 Metadata Mapping Report

Date: 2026-03-09

Branch: DDEconfig \| Base: GeoNetwork 4.4.9

## 1. Introduction

This report provides a detailed mapping between the CDIF (Cross-Domain Interoperability Framework) Complete JSON Schema and the DDE (Deep-time Digital Earth) metadata profile based on ISO 19115-3:2018. The focus is on identifying DDE content elements that are not accounted for in CDIF, and documenting how the GeoNetwork CDIF harvester bridges the two schemas through its inbound (fromJsonCdif.xsl) and outbound (iso19115-3-to-cdif.xsl) XSLT transformations.

The DDE metadata schema (DDEMetadataXSD_20240103.xsd) is a profile of ISO 19115-3 with geoscience-specific extensions including geologic time, acquisition methods, service types, imagery metadata, spatial representation, and an extensive TopicCategoryCode vocabulary with 191 DDE geoscience sub-categories.

## 2. Schema Overview

### 2.1 DDE Metadata Schema

The DDE schema defines 14 complex types, 14 codelist simple types, and 2 utility simple types (DateTime and NilReasonType), counted from DDEMetadataXSD_20240103.xsd. The root element is MD_Metadata containing metadataIdentifier, metadataStandardName, metadataResponsibleParty, metadataDate, and identificationInfo. MD_Identification carries the bulk of descriptive metadata including extent, distribution, constraints, keywords, lineage, quality, service identification, and imagery information.

### 2.2 CDIF Complete Schema

The CDIF Complete schema composes six profile modules: cdifCore, cdifDiscovery, cdifDataDescription, cdifDataStructure, cdifManifest and cdifProvenance (see cdifComplete/schema.yaml). An earlier revision of this document described it as "CDIFDiscovery (cdifMandatory + cdifOptional)"; neither cdifMandatory nor cdifOptional exists any more. It defines ~30 mandatory and optional properties using schema.org, PROV, DQV, OWL-Time, and DDI-CDI vocabularies. Distribution items can be DataDownload, WebAPI, or archive distributions with hasPart members.

## 3. Complete Element-by-Element Mapping

The following table provides the complete mapping between DDE ISO 19115-3 elements and CDIF JSON-LD properties, including the harvester mapping status. "Mapped" means the GeoNetwork harvester XSLTs handle the conversion in both directions.

### 3.1 Metadata-Level Elements

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_Metadata/metadataIdentifier(MD_Identifier/code) | @id (constructed from uuid) | Mapped (both directions) |
| MD_Metadata/metadataStandardName | subjectOf/dcterms:conformsTo | Mapped (inbound: conformsTo name;outbound: metadataProfile title) |
| MD_Metadata/metadataResponsibleParty(CI_Responsibility) | schema:creator, schema:provider,subjectOf/schema:maintainer | Mapped (inbound: first creator->author,first provider->distributor,maintainer->pointOfContact;outbound: reverse mapping) |
| MD_Metadata/metadataDate(CI_Date with dateType) | schema:dateModified,subjectOf/schema:sdDatePublished,schema:datePublished | Mapped (inbound: dateModified->revision,sdDatePublished->creation,datePublished->publication;outbound: reverse cascade) |
| MD_Metadata/identificationInfo | (container for all resource properties) | Mapped (structural wrapper) |

### 3.2 Identification and Citation

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_Identification/title | schema:name | Mapped |
| MD_Identification/alternateTitle | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_Identification/abstract | schema:description | Mapped |
| MD_Identification/resourceIdentifier(MD_Identifier) | schema:identifier(PropertyValue or string) | Mapped (with codeSpaceand propertyID support) |
| MD_Identification/resourceDate(CI_Date) | schema:datePublished | Mapped (publication date type) |
| MD_Identification/edition | schema:version | Mapped |
| MD_Identification/language | schema:inLanguage | Mapped (ISO 639-1 <-> 639-2/Bconversion) |
| MD_Identification/characterEncoding(CharacterSetCode) | (no CDIF equivalent) | NOT mapped - DDE only.9 values: UTF-8, US-ASCII, etc. |
| MD_Identification/additionalDocumentation | (no direct equivalent;partially via schema:relatedLink) | NOT mapped directly.Could use relatedLink. |

### 3.3 Responsible Parties

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| CI_Responsibility/name | schema:name (on Person/Organization) | Mapped |
| CI_Responsibility/role(RoleTypeCode: 20 values) | schema:roleName(on schema:Role wrapper) | Mapped (bidirectionalrole name mapping) |
| CI_Responsibility/identifier(MD_Identifier) | schema:identifier (e.g. ORCID) | Mapped (as @id andschema:identifier) |
| CI_Responsibility/country(CountryCode: 249 values) | (no CDIF equivalent) | NOT mapped - DDE only |
| CI_Responsibility/electronicMailAddress | schema:email orschema:contactPoint/schema:email | Mapped |
| resourceResponsibleParty(multiple with roles) | schema:creator, schema:publisher,schema:contributor, schema:provider | Mapped (role-based routing:author->creator, publisher->publisher,others->contributor) |
| distributionResponsibleParty(per-distribution) | schema:distribution/schema:provider | Mapped (added 2026-03-09:inbound + outbound) |

### 3.4 Keywords and Topic Categories

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_Identification/keyword(Anchor_Type: label+URI) | schema:keywords(DefinedTerm or string) | Mapped (inbound: name + termCode;outbound: flat string array) |
| MD_Identification/topicCategory(TopicCategoryCode) | schema:keywords orschema:additionalType | Partially mapped.Inbound: additionalType -> keywords.DDE has ~170 GI_ sub-categoriesnot in CDIF vocabulary. |
| MD_Identification/resourceType(ResourceTypeCode: 33 values) | schema:additionalType(DefinedTerm) | Mapped via additionalType.DDE has more granular types(e.g. geographicDataset,nonGeographicDataset, thesis, poster). |
| MD_Identification/acquisitionType(AcquisitionCode: 21+ values) | (no CDIF equivalent) | NOT mapped - DDE-specific.Geoscience acquisition methods(e.g. geologicalMapping, survey,drillBorehole, remoteSensing). |

### 3.5 Constraints

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_Constraints/restrictionCode(RestrictionCode: 17 values) | schema:license orschema:conditionsOfAccess | Partially mapped.Inbound: license -> MD_LegalConstraintswith reference citation.DDE restrictionCode vocabularynot directly used. |
| MD_Constraints/restrictionText(Anchor_Type) | schema:license/schema:name,schema:conditionsOfAccess | Mapped (as otherConstraintsor reference title) |

### 3.6 Geographic and Temporal Extent

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| EX_GeographicExtent/westBoundLongitude,eastBoundLongitude,southBoundLatitude,northBoundLatitude | schema:spatialCoverage/schema:geo/schema:box | Mapped (space-delimitedbbox string) |
| EX_GeographicExtent/geographicIdentifier(MD_Identifier) | schema:spatialCoverage/schema:name | Mapped (added 2026-03-09:inbound + outbound) |
| EX_GeographicExtent/verbatimCoordinateLocation | (no CDIF equivalent) | NOT mapped - DDE only.Free-text coordinate description. |
| EX_GeographicExtent/elevation | (no CDIF equivalent) | NOT mapped - DDE only.Elevation/depth information. |
| EX_TemporalExtent/beginDate,endDate | schema:temporalCoverage(ISO 8601 interval) | Mapped (as gml:TimePeriod) |
| EX_TemporalExtent/beginName,endName (geologic ages) | schema:temporalCoverage/time:ProperInterval/time:intervalStartedBy,time:intervalFinishedBy | Mapped (named ordinal eras) |
| EX_TemporalExtent/beginCoordinate,endCoordinate (numeric ages) | schema:temporalCoverage/time:ProperInterval/time:hasBeginning,time:hasEnd | Mapped (numeric positionswith TRS reference) |
| EX_TemporalExtent/coordinateUnits(TemporalUnitsEnum: Ka, Ma, Ga) | time:hasTRS(frame attribute) | Mapped (as timePositionframe attribute) |
| MD_Identification/geoTime(CharacterString_Type) | (no direct CDIF equivalent;partially via temporalCoverage) | NOT mapped directly.DDE uses geoTime as afree-text geologic time label;CDIF uses structuredtemporal intervals. |

### 3.7 Distribution

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_Distribution/onlineResource(CI_OnlineResource/linkage) | schema:distribution/schema:contentUrl | Mapped |
| CI_OnlineResource/title | schema:distribution/schema:name | Mapped |
| CI_OnlineResource/description | schema:distribution/schema:description | Mapped |
| MD_Distribution/distributionFormat(Anchor_Type) | schema:distribution/schema:encodingFormat | Mapped (preferred over protocol) |
| CI_OnlineResource/function(FunctionCode: 12 values) | (no direct CDIF equivalent) | Partially mapped.Only "information" functionused for archive member detection.Other values not exported. |
| CI_OnlineResource/applicationProfile(Anchor_Type) | (no CDIF equivalent) | NOT mapped - DDE only.Application profile links. |
| MD_Distribution/distributionResponsibleParty | schema:distribution/schema:provider | Mapped (added 2026-03-09) |
| MD_Distribution/spatialRepresentationInfo(MD_SpatialRepresentation) | (no CDIF equivalent) | NOT mapped - DDE only.See Section 3.10. |

### 3.8 Lineage and Provenance

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_Identification/lineage(Anchor_Type) | prov:wasGeneratedBy/schema:description | Mapped (as lineage statementand process step description) |
| MD_Identification/source(Anchor_Type, 0..n) | prov:wasDerivedFrom | Mapped (as LI_Source withdescription and citation) |
| MD_Identification/dataQuality(Anchor_Type) | dqv:hasQualityMeasurement | Mapped (as DQ_UsabilityElementwith measure name and result) |

### 3.9 Service Identification

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| SV_ServiceIdentification/serviceType(ServiceTypeCode: 37+ values) | @type containing "schema:WebAPI"or schema:distribution with WebAPI | NOT mapped. CDIF defines a WebAPI type, but neither converter mentions it, so no service type is carried in either direction. DDE has 37+ specific service type codes (data/knowledge/platform/thematic/vocabulary services). |
| SV_ServiceIdentification/containOperations | schema:potentialAction(on WebAPI distribution) | NOT mapped. CDIF has Action with target/result, but neither converter mentions schema:potentialAction. DDE uses free-text operation names. |
| SV_ServiceIdentification/accessProperties | (no CDIF equivalent) | NOT mapped - DDE only.Service access properties. |
| SV_ServiceIdentification/operatedDataset(MD_Identifier) | (no CDIF equivalent) | NOT mapped - DDE only.Datasets operated by service. |
| SV_ServiceIdentification/endpointDescription(CI_OnlineResource) | schema:documentation(on WebAPI) | NOT mapped. CDIF has a documentation URL, but neither converter mentions schema:documentation. DDE has a full CI_OnlineResource. |

### 3.10 Spatial Representation

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_SpatialRepresentation/spatialRepresentationType(6 values: vector, grid,textTable, tin, stereoModel, video) | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_SpatialRepresentation/spatialResolution | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_SpatialRepresentation/referenceSystemType(ReferenceSystemTypeCode:28 values) | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_SpatialRepresentation/referenceSystemIdentifier(MD_Identifier) | (no CDIF equivalent) | NOT mapped - DDE only |

### 3.11 Imagery Metadata

| DDE Element | CDIF Property | Harvester Status |
| --- | --- | --- |
| MD_Imagery/sensor | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_Imagery/platform | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_Imagery/equipment | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_Imagery/signalGenerator | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_Imagery/wavelength | (no CDIF equivalent) | NOT mapped - DDE only |
| MD_Imagery/processingLevel(ProcessingLevelCode:Level0-Level4) | (no CDIF equivalent) | NOT mapped - DDE only |

### 3.12 Additional CDIF Properties Without Direct DDE Equivalents

The following CDIF properties do not have direct DDE schema equivalents but are handled by the harvester through the supplementalInformation mechanism or other mappings:

| CDIF Property | Harvester Handling | Notes |
| --- | --- | --- |
| schema:funding(MonetaryGrant) | Stored in supplementalInformationas "FUNDING: {name} (funder: {org})[{identifier}]" | Roundtrips via structuredtext parsing |
| schema:measurementTechnique | Stored in supplementalInformationas "MEASUREMENT TECHNIQUE: {text}" | Roundtrips via structuredtext parsing |
| schema:publishingPrinciples | Stored in supplementalInformationas "PUBLISHING PRINCIPLES: {text}" | Roundtrips via structuredtext parsing |
| schema:variableMeasured(PropertyValue) | Mapped to FC_FeatureCatalogue+ summary in supplementalInformation | Full roundtrip with name,description, propertyID,unitText, dataType |
| schema:relatedLink(LinkRole) | Mapped to associatedResourcewith association type mapping | Bidirectional withassociation type vocabulary |
| schema:sameAs | Mapped to additionalcit:identifier withcodeSpace="sameAs" | Full roundtrip |
| dqv:hasQualityMeasurement | Mapped to DQ_UsabilityElement | Full roundtrip |
| prov:wasGeneratedBy(Activity) | Mapped to LI_Lineage/processStep | Full roundtrip withsources and descriptions |
| prov:wasDerivedFrom(Entity) | Mapped to LI_Lineage/source | Full roundtrip withname, description, URL |
| schema:subjectOf(CatalogRecord) | Mapped to metadataProfile,metadataLinkage, dateInfo,maintainer | Full roundtrip |
| cdi:TabularData,cdi:DataCube extensions | Not mapped | CDIF-specific datadescription extensions;no DDE equivalent |
| geosparql:hasGeometry(WKT geometries) | Not mapped | CDIF supports arbitrarygeometries; DDE usesbounding box only |
| spdx:checksum | Not mapped | File integrity checksums;no DDE equivalent |

## 4. Summary: DDE Elements Not Accounted for in CDIF

The following DDE schema elements have no equivalent in the CDIF Complete schema. These represent geoscience-domain-specific metadata that would be lost in a CDIF-to-DDE roundtrip unless preserved through extension mechanisms.

| # | DDE Element | Description | Impact |
| --- | --- | --- | --- |
| 1 | alternateTitle | Additional titles for the resource | Low - rarely used in practice |
| 2 | characterEncoding(CharacterSetCode) | Character set of the resource(9 values incl. UTF-8, US-ASCII) | Low - UTF-8 default coversmost cases |
| 3 | acquisitionType(AcquisitionCode) | Data acquisition method(21+ geoscience-specific values) | High - core DDE concept.No CDIF mechanism torepresent this. |
| 4 | geoTime(free-text label) | Free-text geologic time period name | Medium - CDIF has structuredtemporal with named eras,but no free-text label field |
| 5 | verbatimCoordinateLocation | Free-text coordinate description | Low - supplementary tobounding box |
| 6 | elevation | Elevation/depth extent | Medium - no vertical extentin CDIF spatial coverage |
| 7 | CI_Responsibility/country(CountryCode) | Country of responsible party(249 ISO 3166-1 values) | Low - not commonly usedin discovery metadata |
| 8 | CI_OnlineResource/applicationProfile | Application profile of online resource | Low - technical detail |
| 9 | CI_OnlineResource/function(FunctionCode) | Function of online resource(12 values) | Low - only "information" and"download" commonly used;partially handled viaarchive member detection |
| 10 | SV_ServiceIdentification(full type) | Service metadata:serviceType (37+ codes),containOperations,accessProperties,operatedDataset,endpointDescription | High - entire serviceidentification subsystem.CDIF WebAPI covers somebut not DDE granularity. |
| 11 | MD_SpatialRepresentation(full type) | Spatial representation:type (6 values),resolution,referenceSystemType (28 values),referenceSystemIdentifier | High - critical for geospatialdata. No CDIF equivalent. |
| 12 | MD_Imagery(full type) | Imagery metadata:sensor, platform, equipment,signalGenerator, wavelength,processingLevel (5 values) | Medium - specific to remotesensing datasets |
| 13 | TopicCategoryCode(DDE extensions) | ~170 GI_ geosciencesub-categories beyondISO 19115 base 22 | Medium - DDE vocabularyextension. Values can transitas keywords but losecodelist semantics. |
| 14 | MD_Constraints/restrictionCode(17 DDE values) | Granular restriction typesbeyond license/conditions | Low - CDIF license/conditionscovers most use cases |

## 5. Summary Statistics

| Category | Count |
| --- | --- |
| Total DDE schema elements analyzed | ~65 distinct elements across 13 complex types |
| Fully mapped (bidirectional roundtrip) | ~40 elements |
| Partially mapped | ~11 elements (some information loss) |
| Not mapped (DDE-only) | 14 elements/element groups |
| CDIF properties with no DDE equivalent | ~5 (TabularData, DataCube, hasGeometry, checksum, etc.) |
| Inbound XSLT mappings (CDIF -> ISO) | ~95 distinct field paths |
| Outbound XSLT mappings (ISO -> CDIF) | ~68 distinct element paths |

### 5.1 Coverage by Domain

| Domain | DDE Coverage | CDIF Coverage | Mapping Status |
| --- | --- | --- | --- |
| Core identification | Full | Full | Fully mapped |
| Responsible parties | Full (20 roles, country, email) | Full (Person, Org, roles) | Mapped (country not roundtripped) |
| Keywords / classification | Full (4 codelist types) | Partial (flat keywords) | Mapped (codelist semantics lost) |
| Constraints / licensing | Full (17 restriction codes) | Full (license, conditions) | Mapped (restriction codes simplified) |
| Geographic extent | Full (bbox, identifier, elevation) | Partial (bbox, name) | Mapped (elevation not roundtripped) |
| Temporal extent | Full (dates, geologic, units) | Full (dates, geologic) | Fully mapped |
| Distribution | Full (format, function, provider) | Full (download, encoding, provider) | Mapped (function partially handled) |
| Lineage / provenance | Basic (text + sources) | Full (PROV-O model) | Fully mapped |
| Data quality | Basic (text) | Full (DQV model) | Fully mapped |
| Service identification | Full (37+ service types) | Partial (WebAPI only) | NOT mapped |
| Spatial representation | Full (type, CRS, resolution) | None | Not mapped |
| Imagery | Full (sensor, platform, etc.) | None | Not mapped |
| Variables measured | None (via feature catalogue) | Full (PropertyValue) | Mapped via FC_FeatureCatalogue |

## 6. Recommendations

### 6.1 High-Priority Gaps

Three DDE element groups represent significant information loss when converting through CDIF:

1. Acquisition Type (AcquisitionCode): This is a core DDE concept with 21+ geoscience-specific values. Consider proposing a CDIF extension property (e.g., dde:acquisitionMethod) or encoding as a typed keyword with a DDE vocabulary URI.

2. Spatial Representation (MD_SpatialRepresentation): Coordinate reference system, spatial resolution, and representation type are critical for geospatial data interoperability. These could potentially be represented as CDIF extension properties on distribution items.

3. Service Identification (SV_ServiceIdentification): The DDE service type vocabulary is much more granular than CDIF WebAPI support. The 37+ DDE service types could be mapped to schema:serviceType on WebAPI distributions, but the full service metadata model (operations, access properties, operated datasets) has no CDIF equivalent.

### 6.2 Potential Workarounds

For elements that cannot be directly mapped, the harvester could use the same supplementalInformation encoding pattern already used for funding, measurement technique, and publishing principles. This would preserve DDE-specific metadata as structured text that can be parsed back on export. However, this approach sacrifices machine-readability within CDIF.

### 6.3 CDIF Extension Proposal

A formal CDIF extension profile for geoscience metadata could address the high-priority gaps by defining additional JSON-LD properties under a DDE namespace. This would allow lossless roundtripping while maintaining CDIF compatibility for non-DDE consumers.

## 7. Schema References

DDE Metadata Schema: DDEMetadataXSD_20240103.xsd (namespace: https://www.ddeworld.org/resource/standards/dde/ds01/metadata/1.0)

CDIF Complete Schema: CDIFcompleteSchema.json (composed from CDIFDiscovery, cdifMandatory, cdifOptional)

Inbound XSLT: schemas/iso19115-3.2018/.../convert/fromJsonCdif.xsl (CDIF JSON-LD to ISO 19115-3)

Outbound XSLT: schemas/iso19115-3.2018/.../formatter/cdif/iso19115-3-to-cdif.xsl (ISO 19115-3 to CDIF JSON-LD)

GeoNetwork Harvester: harvesters/.../simpleurl/Harvester.java (JSON-LD framing, field recovery)

ISO 19115-3:2018 Geographic information - Metadata

Schema.org (https://schema.org/)

W3C PROV Ontology (https://www.w3.org/TR/prov-o/)

W3C Data Quality Vocabulary (https://www.w3.org/TR/vocab-dqv/)

OWL-Time (https://www.w3.org/TR/owl-time/)
