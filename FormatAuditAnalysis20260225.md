# Format Capability Audit — GeoNetwork-DDE
**Date:** 2026-02-25
**Branch:** DDEconfig
**Base:** GeoNetwork 4.4.9

## Capability Matrix

| Capability | ISO 19139 | ISO 19115-3 | DDE Profile | CDIF JSON-LD |
|---|---|---|---|---|
| **Harvest** | Full | Full | Full (via converters) | Full (sitemap) |
| **Display** | Full (11 formatters) | Full (14+ formatters) | Full (dde/view.xsl) | None (displays as ISO 19115-3) |
| **Edit** | Full (4 views) | Full (4 views, ddeview default) | Full (ddeview, 8 tabs) | None (edits as ISO 19115-3) |
| **Export/Search Results** | Full (native + CSW) | Full (native + API) | Partial (formatter only) | Missing |

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
- **Pipeline:** Sitemap XML → fetch each URL → org.json.XML.toString() → XSLT → ISO 19115-3

---

## 2. Display / Formatters

### ISO 19139
- **Status:** Full — 11 output formatters
- **Available:** xsl-view, citation, jsonld, oai_dc, dcat, eu-dcat-ap, eu-dcat-ap-hvd, eu-geodcat-ap, eu-geodcat-ap-semiceu, datacite, eu-po-doi, iso19115-3.2018 (cross-conversion)
- Note: xsl-view has `published=false` in config.properties

### ISO 19115-3
- **Status:** Full — 14+ output formatters
- **Available:** All ISO 19139 formatters plus: eu-dcat-ap-mobility, dde, iso19139 (cross-conversion)
- Extensive modular DCAT support with specialized sub-stylesheets

### DDE Profile
- **Status:** Full
- **Formatter:** `formatter/dde/view.xsl` — imports `toDDE_20240204.xsl`
- Outputs valid DDE XML (dde:MD_Metadata root element, XSD ref: DDEMetadataXSD_20240103.xsd)

### CDIF JSON-LD
- **Status:** No formatter
- CDIF records are converted to ISO 19115-3 on ingest and display as ISO 19115-3
- **Gap:** No ISO 19115-3 → CDIF JSON-LD export formatter exists

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
- **Gap:** No round-trip back to CDIF JSON-LD after editing

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
- **Status:** Missing
- **Gap:** No ISO 19115-3 → CDIF JSON-LD converter exists
- Cannot export search results in CDIF format
- No round-trip capability

---

## 5. CDIF Conversion Coverage Analysis

### fromJsonCdif.xsl — Schema Coverage

**Total CDIF properties (CDIFCompleteSchema.json):** 34 root properties
**Handled by XSLT:** 16 (47%)
**Required properties covered:** 100%

#### Fully Handled Properties

| CDIF Property | ISO 19115-3 Target |
|---|---|
| `@id` | mdb:metadataIdentifier |
| `@type` | mdb:metadataScope/resourceScope |
| `schema:name` | mri:citation/cit:title |
| `schema:description` | mri:abstract |
| `schema:identifier` | cit:identifier/MD_Identifier |
| `schema:datePublished` | cit:date (publication) |
| `schema:dateModified` | mdb:dateInfo (revision) |
| `schema:creator` | cit:citedResponsibleParty + mri:pointOfContact |
| `schema:license` | mri:resourceConstraints/MD_LegalConstraints |
| `schema:conditionsOfAccess` | mri:resourceConstraints/MD_LegalConstraints |
| `schema:keywords` | mri:descriptiveKeywords/MD_Keywords |
| `schema:additionalType` | mri:descriptiveKeywords (as keywords) |
| `schema:spatialCoverage` | mri:extent/EX_GeographicBoundingBox |
| `schema:distribution` | mdb:distributionInfo/MD_Distribution |
| `schema:url` | mrd:transferOptions (fallback) |
| `schema:subjectOf` | mdb:dateInfo (partial — dateModified only) |

#### Unmapped Properties (12 gaps)

| CDIF Property | Purpose | Priority |
|---|---|---|
| `schema:temporalCoverage` | Time interval of data coverage | **Critical** (especially for DDE geoscience) |
| `schema:variableMeasured` | What the dataset measures | **Critical** (data understanding) |
| `schema:funding` | Grant/funding information | High (research provenance) |
| `schema:contributor` | Other parties involved | High (attribution) |
| `schema:publisher` | Party who made data available | High (attribution) |
| `schema:provider` | Party maintaining distribution | Medium |
| `schema:version` | Dataset version | Low (easy fix, ~5 lines XSLT) |
| `schema:inLanguage` | Content language | Low (easy fix, ~10 lines) |
| `schema:sameAs` | Alternate identifiers | Low (easy fix, ~15 lines) |
| `schema:measurementTechnique` | Method used to determine values | Medium |
| `schema:relatedLink` | Links to related resources | Medium |
| `schema:publishingPrinciples` | Maintenance/persistence policies | Medium |

#### Nested Property Gaps

**Creator/Contributor details:**
- Handled: name, identifier, propertyID, @type detection
- Not handled: affiliation, alternateName, contactPoint, sameAs

**Distribution items:**
- Handled: contentUrl, encodingFormat, name, description
- Not handled: provider, spdx:checksum, cdi:fileSize, cdi:characterSet

**Spatial coverage:**
- Handled: geo/box parsing, latitude/longitude pairs
- Not handled: linestring, geosparql:hasGeometry (WKT/GeoJSON), multiple areas

---

## 6. JSON-LD Framing Problem

### Current Pipeline

```
CDIF JSON-LD → org.json.XML.toString() → Intermediate XML → fromJsonCdif.xsl → ISO 19115-3
```

### The Problem

`org.json.XML.toString()` is **not JSON-LD aware**. It performs mechanical JSON-to-XML conversion without understanding:
- `@context` (prefix mappings are lost)
- `@list` (creates extra nesting levels)
- `@id` references (treated as plain strings)
- `@value` / `@language` constructs
- Compact vs expanded vs flattened vs framed forms

### Key Conversion Rules
- `schema:name` → `<schema_name>` (colon → underscore)
- `@id` → `<id>` (@ prefix stripped by regex in Harvester.java)
- `@type` → `<type>` (@ prefix stripped)
- Nested objects → nested XML elements
- Arrays → repeated XML elements

### Structural Assumptions in fromJsonCdif.xsl

The XSLT assumes a specific JSON-LD form (compact, with embedded objects):
- `schema_creator` as direct child elements (breaks if wrapped in `@list`)
- `type` element containing type string (breaks if `@type` is an array)
- Objects embedded inline (breaks if referenced by `@id`)

### What Breaks

| JSON-LD Variant | Impact |
|---|---|
| `@list` wrapper on creator | Creator elements nested under extra level — XSLT misses them |
| `@type` as array | Multiple `<type>` elements — XSLT may match wrong one |
| `@graph` wrapper | All data one level deeper — all XSLT paths fail |
| Expanded form (full URIs) | `http_schema_org_name` instead of `schema_name` — no matches |
| Flattened form (@id references) | Objects not embedded — XSLT can't traverse |

### Current Test File Status

The 77 CDIF test files are all in **compact form** with consistent `@context`. They do use `@list` for `schema:creator`, which is a known fragility point. The test files are carefully curated to (mostly) work with the current converter.

### Recommended Solutions

**Option A: JSON-LD Framing Pre-processor (Recommended)**
- Add a JSON-LD processing step (using jsonld-java library) before XML conversion
- Frame all incoming documents to a canonical form
- Guarantees consistent structure regardless of input form
- Effort: Medium (Java code in Harvester.java + jsonld-java dependency)

**Option B: Direct JSON-LD to Elasticsearch Mapping**
- Skip the XML conversion entirely
- Map JSON-LD properties directly to the ES index schema
- Use JSON-LD processor to expand/normalize, then map to ES fields
- Pros: Eliminates XML round-trip, better performance, native JSON handling
- Cons: Bypasses GeoNetwork's schema plugin system, records not editable in standard editor
- Effort: High (new harvester pathway, custom indexing)

**Option C: Defensive XSLT with Multiple Fallback Patterns**
- Add XPath fallbacks for @list, @graph, array @type, etc.
- Most fragile long-term but lowest effort
- Doesn't solve the fundamental problem

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

---

## 8. Summary of Gaps and Priorities

### Critical Gaps (blocking full workflow)

1. **No CDIF JSON-LD export** — Cannot round-trip CDIF records or serve search results in CDIF format
2. **JSON-LD framing fragility** — `@list`, `@graph`, expanded forms break the conversion
3. **12 unmapped CDIF properties** — temporalCoverage and variableMeasured most critical

### Important Gaps (functional but incomplete)

4. **No DDE harvester preset** — Manual configuration required
5. **DDE not in CSW outputSchema** — Can't serve DDE via CSW GetRecords
6. **No CDIF-specific display** — Shows as ISO 19115-3

### Nice to Have

7. **CDIF-native editor** — Currently edits as ISO 19115-3
8. **Direct JSON→ES mapping** — Would enable richer indexing of CDIF-specific fields
