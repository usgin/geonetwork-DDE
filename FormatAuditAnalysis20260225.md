# Format Capability Audit — GeoNetwork-DDE
**Date:** 2026-02-25 (updated 2026-03-09)
**Branch:** DDEconfig
**Base:** GeoNetwork 4.4.9

## Capability Matrix

| Capability | ISO 19139 | ISO 19115-3 | DDE Profile | CDIF JSON-LD |
|---|---|---|---|---|
| **Harvest** | Full | Full | Full (via converters) | Full (sitemap) |
| **Display** | Full (11 formatters) | Full (14+ formatters) | Full (dde/view.xsl) | Full (displays as ISO 19115-3) |
| **Edit** | Full (4 views) | Full (4 views, ddeview default) | Full (ddeview, 8 tabs) | Via ISO 19115-3 (no native editor) |
| **Export/Search Results** | Full (native + CSW) | Full (native + API) | Partial (formatter only) | Full (formatter: `/formatters/cdif`) |

---

## 1. Harvesting

### ISO 19139
- **Status:** Full support
- **Harvesters:** CSW, OAI-PMH, Simple URL, GeoNetwork, WebDAV, SFTP
- CSW harvester uses `outputSchema` parameter to request ISO 19139
- OAI-PMH uses `metadataPrefix` for format selection

### ISO 19115-3
- **Status:** Full support
- **Harvesters:** CSW (via outputSchema), Simple URL (preset: "XML ISO19115-3")
- Conversion from ISO 19139 available via `fromISO19139.xsl`
- Simple URL preset configured in HarvestSettingsController.js with `recordIdPath=mdb:metadataIdentifier/*/mcc:code/*/text()`

### DDE Profile
- **Status:** Full (via converters), no harvester preset
- **Converters available:**
  - `fromDDE-20240405.xsl` — DDE → ISO 19115-3
  - `fromDDE-any.xsl` — DDE auto-detect entry point
  - `ddeToISO19115-3_20240208.xsl` — DDE → ISO 19115-3 (alternate)
  - `fromISO19139-DDE.xsl` — ISO 19139 → DDE
- **Gap:** No Simple URL harvester preset for DDE sources in HarvestSettingsController.js. Users must manually configure the harvester with `toISOConversion` pointing to the appropriate converter.

### CDIF JSON-LD
- **Status:** Full support via custom sitemap harvester
- **Converter:** `fromJsonCdif.xsl` — CDIF JSON-LD → ISO 19115-3
- **Preset:** "CDIF Sitemap" configured in HarvestSettingsController.js
  - `isSitemap=true`, `recordIdPath=/@id`, `toISOConversion=schema:iso19115-3.2018:convert/fromJsonCdif`
- **Pipeline:** Sitemap XML → fetch each URL → JSON-LD framing (`cdif-frame.jsonld`) → `recoverDroppedFields()` → `removeNulls()` → `org.json.XML.toString()` → XSLT → ISO 19115-3
- **Tested:** 77 CDIF validation records + 121 ADA records harvested successfully

---

## 2. Display / Formatters

### ISO 19139
- **Status:** Full — 11 output formatters
- **Available:** xsl-view, citation, jsonld, oai_dc, dcat, eu-dcat-ap, eu-dcat-ap-hvd, eu-geodcat-ap, eu-geodcat-ap-semiceu, datacite, eu-po-doi, iso19115-3.2018 (cross-conversion)
- Note: xsl-view has `published=false` in config.properties

### ISO 19115-3
- **Status:** Full — 14+ output formatters
- **Available:** All ISO 19139 formatters plus: eu-dcat-ap-mobility, dde, cdif, iso19139 (cross-conversion)
- Extensive modular DCAT support with specialized sub-stylesheets

### DDE Profile
- **Status:** Full
- **Formatter:** `formatter/dde/view.xsl` — imports `toDDE_20240204.xsl`
- Outputs valid DDE XML (dde:MD_Metadata root element, XSD ref: DDEMetadataXSD_20240103.xsd)

### CDIF JSON-LD
- **Status:** Full
- **Formatter:** `formatter/cdif/iso19115-3-to-cdif.xsl` — ISO 19115-3 → CDIF JSON-LD
- **Endpoint:** `GET /geonetwork/srv/api/records/{uuid}/formatters/cdif`
- Roundtrip validated: 120/121 ADA records pass (1 fail due to source data issue)
- Handles complex distributions (primary + archive `hasPart` members), funding, provenance, data quality, all agent roles

---

## 3. Editing

### ISO 19139
- **Status:** Full — 4 editor views
- **Views:** inspire (conditional on INSPIRE setting), default (default=true), advanced, xml
- **Templates:** 8+ (vector, vector-multilingual, raster, service, map, inspire_sds, subtemplates)

### ISO 19115-3
- **Status:** Full — 4 editor views
- **Views:** ddeview (default=true, 8 tabs), default, advanced, xml
- **Templates:** 5 (geodata, geodata-multilingual, service, map, featureTypeDescription)

### DDE Profile
- **Status:** Full — the ddeview is the DDE editor
- **8 tabs:** basicmetadata, firstdetail, extent, imagery, service, relatedresource, dde-distributionInfo, metadatametadata
- **DDE thesauri (all present):**
  - `local.theme.topiccategoryskos` → topiccategoryskos.rdf
  - `local.theme.acquisitioncodeskos` → acquisitioncodeskos.rdf
  - `local.theme.resourcetypeskos` → resourcetypeskos.rdf
  - `local.theme.servicetypeskos` → servicetypeskos.rdf
- **DDE-specific features:** Geologic age (Ma before present), DDE profile stamp, DDE codelist URLs

### CDIF JSON-LD
- **Status:** No native editor
- CDIF records are converted to ISO 19115-3 on harvest and edited as ISO 19115-3
- Roundtrip back to CDIF JSON-LD is available via the formatter endpoint after editing

---

## 4. Export / Search Result Formatting

### ISO 19139
- **Status:** Full
- CSW GetRecords supports `outputSchema=gmd` for ISO 19139
- API supports XML, JSON, ZIP (MEF) via Accept header negotiation
- Multiple export formatters available

### ISO 19115-3
- **Status:** Full
- Native schema — records returned directly via API
- Cross-conversion to ISO 19139 available

### DDE Profile
- **Status:** Partial — formatter only
- DDE output available via formatter API (dde/view.xsl → toDDE_20240204.xsl)
- **Gap:** DDE not registered as CSW outputSchema value; cannot request DDE format via CSW GetRecords

### CDIF JSON-LD
- **Status:** Full — formatter available
- **Endpoint:** `GET /geonetwork/srv/api/records/{uuid}/formatters/cdif`
- Converts ISO 19115-3 back to CDIF JSON-LD with high fidelity
- **Gap:** Not integrated with CSW GetRecords or bulk search result export; individual record export only

---

## 5. CDIF Conversion Coverage Analysis

### fromJsonCdif.xsl — Schema Coverage (Inbound)

**Total CDIF properties (CDIFCompleteSchema.json):** 34 root properties
**Handled by XSLT:** 28 (82%)
**Required properties covered:** 100%

#### Fully Handled Properties

| CDIF Property | ISO 19115-3 Target |
|---|---|
| `@id` | mdb:metadataIdentifier |
| `@type` | mdb:metadataScope/resourceScope |
| `schema:name` | mri:citation/cit:title |
| `schema:description` | mri:abstract |
| `schema:identifier` | cit:identifier/MD_Identifier (DOI detection) |
| `schema:sameAs` | cit:identifier (codeSpace='sameAs') |
| `schema:version` | cit:edition |
| `schema:datePublished` | cit:date (publication) |
| `schema:dateModified` | mdb:dateInfo (revision), cascade: revision → creation → pubDate |
| `schema:inLanguage` | mdb:defaultLocale (2-letter → 3-letter code) |
| `schema:creator` | cit:citedResponsibleParty (role=author) + mri:pointOfContact |
| `schema:contributor` | cit:citedResponsibleParty (with mapped roleName) |
| `schema:publisher` | cit:citedResponsibleParty (role=publisher) |
| `schema:provider` | mdb:contact (role=distributor) |
| `schema:license` | mri:resourceConstraints/MD_LegalConstraints |
| `schema:conditionsOfAccess` | mri:resourceConstraints/MD_LegalConstraints |
| `schema:keywords` | mri:descriptiveKeywords/MD_Keywords |
| `schema:additionalType` | mri:descriptiveKeywords (as keywords with thesaurus if URI) |
| `schema:spatialCoverage` | mri:extent/EX_GeographicBoundingBox |
| `schema:temporalCoverage` | gex:EX_TemporalExtent/gml:TimePeriod (ISO dates) or gml:TimeInstant (geologic Ma) |
| `schema:distribution` | mdb:distributionInfo/MD_Distribution (contentUrl, encodingFormat, name, description, fileSize, characterSet, hasPart) |
| `schema:url` | mrd:transferOptions (fallback when no distribution) |
| `schema:variableMeasured` | mrc:MD_FeatureCatalogue/gfc:FC_FeatureCatalogue (name, description, propertyID, intendedDataType, unitText/unitCode) |
| `schema:funding` | mri:supplementalInformation (structured text) |
| `schema:measurementTechnique` | mri:supplementalInformation (structured text) |
| `schema:publishingPrinciples` | mri:supplementalInformation (structured text) |
| `schema:relatedLink` | mri:associatedResource/mri:MD_AssociatedResource |
| `schema:subjectOf` | mdb:dateInfo, mdb:metadataProfile, mdb:metadataLinkage |

#### Handled Nested Properties

**Creator/Contributor:**
- name, identifier, propertyID, @type detection
- affiliation → nested organization name
- contactPoint → email extraction
- email → direct mapping
- partyIdentifier → person/org ID

**Distribution:**
- contentUrl, encodingFormat, name, description
- `cdi:fileSize` + `cdi:fileSizeUofM` → transferSize (converted to MB)
- `cdi:characterSet` → embedded in description
- `schema:hasPart` → archive members (function=information, nil URL)

**Spatial coverage:**
- `schema:geo/schema:box` → 4-value bounding box
- `schema:geo/schema:latitude` + `schema:longitude` → point as bbox

#### Remaining Unmapped Properties (6 gaps)

| Property | Scope | Priority | Notes |
|---|---|---|---|
| `schema:alternateName` | Creator/contributor agents | Low | No natural ISO 19115-3 target |
| `schema:sameAs` | Creator/contributor agents | Low | Agent-level sameAs (not resource-level) |
| `schema:contactPoint` (full) | Creator/contributor agents | Low | Only email extracted; full nested ContactPoint not handled |
| `schema:provider` | Per-distribution | Low | Only top-level provider mapped; distribution-level provider not extracted |
| `spdx:checksum` | Distribution | Low | No standard ISO 19115-3 target |
| `geosparql:hasGeometry` | Spatial coverage | Medium | WKT/GeoJSON geometries not parsed; only bbox supported |

### iso19115-3-to-cdif.xsl — Coverage (Outbound)

The outbound formatter mirrors the inbound coverage. All 28 inbound-mapped properties are reconstructed in the CDIF JSON-LD output, with the same nested property support.

**Additional outbound features:**
- Distribution type detection: primary (function=download) vs archive members (function=information, nil URL) → `schema:hasPart`
- Encoding format prefers `mrd:distributionFormat` over `cit:protocol`; bare protocols (`http`, `https`, `ftp`) excluded
- Funding output: structured (name + funder) when markers present, `schema:description` for free text
- dateModified cascade: revision → creation → pubDate
- Provenance: `prov:wasGeneratedBy` and `prov:wasDerivedFrom` from lineage
- Data quality: `dqv:hasQualityMeasurement` from DQ_DataQuality reports
- Contributor role mapping (6 named roles + default)
- Language code conversion (3-letter → 2-letter)

**Roundtrip-known structural differences (not failures):**
- `@id` uses GeoNetwork API URL instead of original
- `@context` includes all CDIF prefixes (original may have fewer)
- Agent `@id` values are blank nodes instead of original URIs
- `schema:additionalType` stored as keywords (preserved but in different location)

---

## 6. JSON-LD Framing — Implemented

### Pipeline (current)

```
CDIF JSON-LD → JSON-LD framing (cdif-frame.jsonld)
             → recoverDroppedFields()
             → removeNulls()
             → org.json.XML.toString()
             → fromJsonCdif.xsl
             → ISO 19115-3
```

### Implementation

**Option A (JSON-LD Framing Pre-processor) was implemented** in `Harvester.java`:

1. **`cdif-frame.jsonld`** — JSON-LD frame document that normalizes all incoming CDIF records to a canonical structure, regardless of whether they arrive in compact, expanded, or flattened form.

2. **`recoverDroppedFields()`** — Merges back fields that the Java `jsonld-java` library silently drops during framing:
   - `schema:creator` (uses `@list` container)
   - `schema:contributor`
   - `schema:publisher`
   - `schema:provider`
   - `schema:funding`
   - `schema:distribution` (nested `hasPart`)
   - `schema:variableMeasured`
   - `schema:dateModified`

3. **`removeNulls()` / `removeNullsFromList()`** — Recursively strips null values introduced by framing for properties defined in the frame but absent in the source record. Prevents `org.json.XML.toString()` from serializing the literal string `"null"`.

### Remaining Fragility

The `jsonld-java` library (v0.13.6 bundled with GeoNetwork) has known differences from the W3C JSON-LD 1.1 spec and the Python `pyld` reference implementation. The `recoverDroppedFields()` workaround handles the known dropped fields, but new CDIF properties added to the frame may need to be added to the recovery list if `jsonld-java` drops them.

Upgrading `jsonld-java` or switching to `titanium-json-ld` (JSON-LD 1.1 compliant) would be a more robust long-term fix but requires dependency analysis across GeoNetwork's codebase.

---

## 7. Direct JSON → Elasticsearch Mapping Question

GeoNetwork's Elasticsearch index (`records.json`) already defines a flat-ish document schema with fields like `resourceTitleObject`, `resourceAbstractObject`, `contactForResource`, `tag`, `geom`, etc. A CDIF JSON-LD record could potentially be mapped directly to these ES fields without XML conversion:

| CDIF Property | ES Index Field |
|---|---|
| `schema:name` | `resourceTitleObject.default` |
| `schema:description` | `resourceAbstractObject.default` |
| `schema:keywords` | `tag[].default` |
| `schema:creator` | `contactForResource[].organisationObject` or `.individual` |
| `schema:spatialCoverage` | `geom` (GeoJSON) |
| `schema:datePublished` | `publicationDateForResource` |
| `schema:distribution` | `link[]` |

**Feasibility:** Technically possible but architecturally challenging because:
1. GeoNetwork assumes all records have an XML representation in the metadata table
2. The editor, CSW service, and formatter system all operate on XML
3. The index is a secondary artifact rebuilt from XML — it's not the source of truth
4. Would require a parallel "JSON-native" record pathway through the entire stack

**Hybrid approach:** Use JSON-LD processor to normalize the JSON, convert to ISO 19115-3 XML for storage/editing, but also directly populate ES fields from the JSON for richer indexing (e.g., variables, funding) that don't map cleanly to ISO.

**Current status:** Not implemented. The current ISO 19115-3 indexing path works well — all CDIF properties that map to ISO are indexed via the standard schema plugin indexer. Properties stored in `supplementalInformation` (funding, measurement technique, publishing principles) are indexed as free text but not as structured ES fields.

---

## 8. Summary of Gaps and Priorities

### Resolved Since Initial Audit (2026-02-25)

| Gap | Resolution |
|---|---|
| No CDIF JSON-LD export | **Resolved** — `iso19115-3-to-cdif.xsl` formatter at `/formatters/cdif` |
| JSON-LD framing fragility | **Resolved** — `cdif-frame.jsonld` + `recoverDroppedFields()` + `removeNulls()` |
| 12 unmapped CDIF properties | **Resolved** — all 12 now mapped (temporalCoverage, variableMeasured, funding, contributor, publisher, provider, version, inLanguage, sameAs, measurementTechnique, relatedLink, publishingPrinciples) |
| No round-trip capability | **Resolved** — 120/121 ADA records pass roundtrip validation |
| Creator/contributor details | **Mostly resolved** — affiliation, email, contactPoint (email), identifier now handled |
| Distribution details | **Mostly resolved** — fileSize, characterSet, hasPart archive members now handled |

### Remaining Gaps

#### Functional Gaps (Medium Priority)

1. **No DDE harvester preset** — Manual configuration required for DDE sources
2. **DDE not in CSW outputSchema** — Can't serve DDE format via CSW GetRecords
3. **CDIF not in bulk export** — Formatter works per-record; no batch/search-result CDIF export
4. **`geosparql:hasGeometry`** — WKT/GeoJSON spatial geometries not supported; only bounding box
5. **Supplemental info indexing** — Funding, measurement technique, publishing principles are stored as free text in `supplementalInformation`; not indexed as structured ES fields

#### Minor Gaps (Low Priority)

6. **Agent `alternateName`** — Not extracted from creator/contributor (no natural ISO target)
7. **Agent `sameAs`** — Agent-level sameAs URIs not extracted (resource-level sameAs is handled)
8. **Full `contactPoint` object** — Only email extracted from nested ContactPoint
9. **Distribution-level `provider`** — Only top-level provider mapped
10. **`spdx:checksum`** — No standard ISO 19115-3 target for checksums
11. **Multiple spatial areas** — Only single bounding box supported per extent

#### Architectural Considerations (Future)

12. **`jsonld-java` limitations** — Bundled library drops fields; workaround in place but fragile for new properties
13. **CDIF-native editor** — Currently edits as ISO 19115-3; a CDIF-aware editor view is not planned
14. **Direct JSON→ES mapping** — Would enable richer structured indexing but requires significant architecture changes
