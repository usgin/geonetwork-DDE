# DDE / CDIF Metadata Harvester for GeoNetwork

## Overview

This fork of [GeoNetwork opensource](https://github.com/geonetwork/core-geonetwork) was originally developed to harvest and edit [Deep-time Digital Earth (DDE)](https://www.ddeworld.org/) ISO 19115-3 metadata. The DDE project uses GeoNetwork as its metadata catalogue for geoscience data resources, with customizations to the editor UI, indexing, and vocabularies for DDE-specific requirements.

The fork has since been extended with the ability to harvest [CDIF (Cross-Domain Interoperability Framework)](https://cross-domain-interoperability-framework.github.io/cdifbook/preamble/) metadata records encoded as JSON-LD based on the schema.org vocabulary.

CDIF defines a discovery metadata profile that uses schema.org vocabulary to describe datasets, their distributions, creators, licenses, and spatial/temporal coverage. This harvester ingests CDIF JSON-LD records via a sitemap, converts them to ISO 19115-3 XML, and indexes them in GeoNetwork for standard search and discovery.

## Architecture

The harvester extends GeoNetwork's existing **Simple URL Harvester** with sitemap support. The processing pipeline is:

```
                         INBOUND (harvesting)
Sitemap XML          JSON-LD files         Intermediate XML       ISO 19115-3 XML
(list of URLs)  -->  (fetched per-URL) --> (org.json.XML)     --> (fromJsonCdif.xsl)
                                                                       |
                                                                  GeoNetwork DB +
                                                                  Elasticsearch index +
                                                                  search UI
                                                                       |
                         OUTBOUND (export)                             v
                     CDIF JSON-LD       <---  (iso19115-3-to-cdif.xsl)
                     (/formatters/cdif)
```

### Inbound (harvesting)

1. The harvester fetches a sitemap XML file listing CDIF record URLs (or individual JSON-LD files)
2. Each URL is fetched individually, returning a single JSON-LD document
3. JSON-LD framing is applied using `cdif-frame.jsonld` to normalize structure
4. `recoverDroppedFields()` merges back fields dropped by the Java JSON-LD framing library
5. `removeNulls()` strips null values introduced by framing for absent optional properties
6. GeoNetwork's built-in `org.json.XML.toString()` converts JSON to intermediate XML
7. A custom XSLT (`fromJsonCdif.xsl`) transforms the intermediate XML to valid ISO 19115-3
8. GeoNetwork indexes and stores the record using its standard iso19115-3.2018 schema support

### Outbound (export)

1. A CDIF formatter (`iso19115-3-to-cdif.xsl`) converts ISO 19115-3 back to CDIF JSON-LD
2. Accessible via the GeoNetwork API: `/srv/api/records/{uuid}/formatters/cdif`
3. Supports roundtrip: CDIF JSON-LD → ISO 19115-3 → CDIF JSON-LD with high fidelity

## Building and Running

### Prerequisites

- Java 11 (e.g. [Adoptium OpenJDK 11 LTS](https://adoptium.net/temurin/archive/?version=11))
- Apache Maven 3.6+
- Docker (for Elasticsearch 8.14.3)
- Git

### Build

```bash
git clone https://github.com/<your-org>/core-geonetwork.git
cd core-geonetwork
git checkout DDEconfig
git submodule update --init --recursive
mvn clean install -DskipTests
```

> **Windows / Java 11.0.2 TLS note**: If Maven fails with SSL errors, set:
> ```
> set MAVEN_OPTS=-Dhttps.protocols=TLSv1.2 -Djdk.tls.client.protocols=TLSv1.2
> ```

Useful build variants:

| Command | Purpose |
|---------|---------|
| `mvn install -DskipTests -T 2C` | Parallel build (2 threads per CPU core) |
| `mvn install -DskipTests -rf :gn-harvesters` | Resume from a specific module after fixing a compile error |
| `cd web && mvn process-resources -PschemasCopy` | Hot-reload UI and schema changes into a running Jetty instance |
| `cd web && mvn clean:clean@reset` | Reset the H2 database and all caches |

### Start Elasticsearch

```bash
cd es
docker-compose up -d
```

- Elasticsearch: http://localhost:9200
- Kibana: http://localhost:5601

The `docker-compose.yml` runs Elasticsearch 8.14.3 with security disabled (`xpack.security.enabled=false`) and a single-node cluster.

### Start GeoNetwork

```bash
cd web
mvn jetty:run -Penv-dev
```

GeoNetwork will be available at http://localhost:8080/geonetwork. Default login: `admin` / `admin`.

The H2 database is stored in your home directory as `~/gn.mv.db`.

## Configuring the CDIF Harvester

### Using the UI

1. Log in as **admin**
2. Go to **Admin Console > Harvesting**
3. Click **Harvest from > Simple URL**
4. Select the **CDIF Sitemap** preset from the helper dropdown at the top of the form
5. Set the **URL** to the sitemap listing your CDIF JSON-LD files
6. The preset fills in these settings automatically:
   - **URL is a sitemap**: checked
   - **Record ID path**: `/@id`
   - **Conversion**: `schema:iso19115-3.2018:convert/fromJsonCdif`
7. Configure harvest schedule, privileges, and categories as needed
8. Save and click **Harvest**

### Using the API

You can also create a harvester via the XML services API:

```bash
# Get XSRF token
COOKIES=$(mktemp)
curl -s -c $COOKIES -b $COOKIES \
  "http://localhost:8080/geonetwork/srv/eng/info?type=me" > /dev/null
XSRF=$(grep XSRF $COOKIES | awk '{print $NF}')

# Create harvester
curl -s -b $COOKIES \
  -H "X-XSRF-TOKEN: $XSRF" \
  -H "Content-Type: application/xml" \
  -d '<request>
    <node id="-1" type="simpleurl">
      <site>
        <name>CDIF Metadata</name>
        <url>http://localhost:9999/sitemap.xml</url>
        <icon>blank.png</icon>
        <isSitemap>true</isSitemap>
        <loopElement></loopElement>
        <numberOfRecordPath></numberOfRecordPath>
        <recordIdPath>/@id</recordIdPath>
        <pageSizeParam></pageSizeParam>
        <pageFromParam></pageFromParam>
        <toISOConversion>schema:iso19115-3.2018:convert/fromJsonCdif</toISOConversion>
      </site>
      <options>
        <every>0 0 0 ? * *</every>
        <oneRunOnly>true</oneRunOnly>
        <overrideUuid>SKIP</overrideUuid>
        <status>active</status>
      </options>
      <content>
        <validate>NOVALIDATION</validate>
        <importxslt>none</importxslt>
      </content>
    </node>
  </request>' \
  "http://localhost:8080/geonetwork/srv/eng/admin.harvester.add"

# Run the harvester (replace ID with the returned harvester ID)
curl -s -b $COOKIES \
  -H "X-XSRF-TOKEN: $XSRF" \
  "http://localhost:8080/geonetwork/srv/eng/admin.harvester.run?id=100"
```

### Sitemap Format

The sitemap must follow the [sitemaps.org protocol](https://www.sitemaps.org/protocol.html). Each `<url>/<loc>` entry should point to a URL that returns a single CDIF JSON-LD document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/metadata/record-1.json</loc></url>
  <url><loc>https://example.com/metadata/record-2.json</loc></url>
</urlset>
```

Sitemaps with or without the `http://www.sitemaps.org/schemas/sitemap/0.9` namespace are both supported.

### Serving Local Files for Testing

To test with local JSON-LD files, serve them via a simple HTTP server and create a sitemap:

```bash
# Start a local server
cd /path/to/json-ld-files
python -m http.server 9999

# Create a sitemap (example)
echo '<?xml version="1.0" encoding="UTF-8"?>' > sitemap.xml
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' >> sitemap.xml
for f in *.json; do
  echo "  <url><loc>http://localhost:9999/$f</loc></url>" >> sitemap.xml
done
echo '</urlset>' >> sitemap.xml
```

Then point the harvester URL to `http://localhost:9999/sitemap.xml`.

## All Harvesting Options (Simple URL Harvester)

The Simple URL Harvester supports several presets beyond CDIF:

| Preset | Use Case | Key Settings |
|--------|----------|--------------|
| **CDIF Sitemap** | CDIF JSON-LD records from a sitemap | `isSitemap=true`, `recordIdPath=/@id`, conversion=`fromJsonCdif` |
| **DCAT** | DCAT-AP JSON catalogs | `loopElement=/dcat:dataset`, conversion=`fromJsonDcat` |
| **CKAN** | CKAN portals | `loopElement=/results`, conversion=`fromJsonCkan` |
| **OpenDataSoft** | OpenDataSoft portals | `loopElement=/datasets`, conversion=`fromJsonOpendatasoft` |
| **(Custom)** | Any JSON API | Configure `loopElement`, `recordIdPath`, `pageSizeParam`, `pageFromParam`, and a custom `toISOConversion` XSLT |

### Parameter Reference

| Parameter | Description |
|-----------|-------------|
| **URL** | The endpoint URL. For CDIF, this is the sitemap URL. |
| **URL is a sitemap** (`isSitemap`) | When checked, the URL is treated as a sitemap and each `<loc>` URL is fetched individually. |
| **Loop element** (`loopElement`) | JSONPath to the array of records in the API response. Not used for sitemap mode. |
| **Number of records path** (`numberOfRecordPath`) | JSONPath to the total record count for pagination. Not used for sitemap mode. |
| **Record ID path** (`recordIdPath`) | JSONPath to the unique identifier within each record. For CDIF: `/@id`. |
| **Page size param** (`pageSizeParam`) | Query parameter name for page size. Not used for sitemap mode. |
| **Page from param** (`pageFromParam`) | Query parameter name for page offset. Not used for sitemap mode. |
| **Conversion** (`toISOConversion`) | XSLT to convert intermediate XML to ISO metadata. Format: `schema:<schema>:convert/<xslt-name>`. |

## DDE Editor Customizations

The iso19115-3.2018 schema plugin includes a custom editor view (`ddeview`) and supporting infrastructure ported from the earlier DDEcore GeoNetwork deployment (~4.4.4).

### DDE Editor View

The `ddeview` is defined in `config-editor.xml` as the default editor view with 8 tabs:

| Tab | Key Fields |
|-----|------------|
| **basicmetadata** | Title, abstract, status, DDE topic/acquisition/resource type keyword pickers, dates, contacts, constraints, lineage |
| **firstdetail** | Supplemental info, credits, reference system, aggregation |
| **extent** | Geographic bounding box, spatial resolution, temporal extent (calendar dates + geologic age in Ma before present) |
| **imagery** | Wavelength, sensors, instruments, platforms (conditional: `mdb:name='image'`) |
| **service** | Service type, access properties, operated datasets, operations (conditional: scope='service') |
| **relatedresource** | Associated resources with DDE codelist URLs |
| **dde-distributionInfo** | Format, distributor, transfer options |
| **metadatametadata** | Identifier, DDE profile stamp ("DDE S01-2023"), locale, contact, dates |

The upstream `default`, `advanced`, and `xml` views remain accessible via the view switcher.

### DDE Controlled Vocabularies

Four SKOS thesauri in `web/.../codelist/local/thesauri/theme/`:

| File | Thesaurus Key | Used By |
|------|---------------|---------|
| `topiccategoryskos.rdf` | `local.theme.topiccategoryskos` | basicmetadata tab |
| `acquisitioncodeskos.rdf` | `local.theme.acquisitioncodeskos` | basicmetadata tab |
| `resourcetypeskos.rdf` | `local.theme.resourcetypeskos` | basicmetadata tab |
| `servicetypeskos.rdf` | `local.theme.servicetypeskos` | service tab |

### DDE Format Converters

XSLT files in `schemas/iso19115-3.2018/.../convert/`:

| File | Direction |
|------|-----------|
| `toDDE_20240204.xsl` | ISO 19115-3 → DDE |
| `fromDDE-20240405.xsl` | DDE → ISO 19115-3 |
| `ISO19115-3ToDDE_20240204.xsl` | ISO 19115-3 → DDE (alternate) |
| `ddeToISO19115-3_20240208.xsl` | DDE → ISO 19115-3 (alternate) |
| `fromISO19139-DDE.xsl` | ISO 19139 → DDE |
| `fromDDE-any.xsl` | DDE auto-detect entry point |
| `utilityDDE/` | 12 shared XSLT utility files |

### DDE Layout/Indexing Modifications

| File | Change |
|------|--------|
| `layout/layout.xsl` | Added `xmlns:gts` namespace + `gts:*` matching for geologic time elements |
| `layout/layout-custom-fields-date.xsl` | Added `$overrideLabel` parameter and `data-hide-time` calendar control |
| `index-fields/link-utility.xsl` | Added `nilReason` element output during indexing |
| `formatter/dde/view.xsl` | DDE output format template |
| `loc/eng/strings.xml` | DDE help text entries (geologic age, calendar extent, etc.) |

### Build Configuration

Dublin Core and ISO 19110 schema plugins are disabled in the build (`schemas/pom.xml` and `web/pom.xml`) since they are not needed for DDE workflows.

## Components

### New Files

| File | Purpose |
|------|---------|
| `schemas/iso19115-3.2018/.../convert/fromJsonCdif.xsl` | XSLT converting CDIF JSON-LD intermediate XML to XSD-valid ISO 19115-3 `mdb:MD_Metadata` |
| `schemas/iso19115-3.2018/.../convert/cdif-frame.jsonld` | JSON-LD frame document for CDIF harvesting pre-processing |
| `schemas/iso19115-3.2018/.../formatter/cdif/iso19115-3-to-cdif.xsl` | XSLT converting ISO 19115-3 back to CDIF JSON-LD (outbound formatter) |
| `oxygen-catalog.xml` | Oxygen XML Editor catalog with absolute `file:///` paths for local XSD validation |
| `test_cdif_xslt.py` | Test pipeline: JSON-LD framing → XML conversion → XSLT → structural validation |
| `validate_cdif_examples.py` | Roundtrip validation: compares original CDIF JSON-LD with GeoNetwork formatter output |
| `agents.md` | This documentation file |

### Modified Files

| File | Change |
|------|--------|
| `harvesters/.../simpleurl/Harvester.java` | Added sitemap processing: `extractUrlsFromSitemap()`, `collectSingleJsonRecord()`, `isSitemapContent()`. JSON-LD framing with `removeNulls()` and `recoverDroppedFields()`. Fixed sitemap parsing to use direct JDOM traversal instead of XPath (works around `Xml.loadString()` detaching root from Document). |
| `harvesters/.../simpleurl/SimpleUrlParams.java` | Added `isSitemap` parameter |
| `harvesters/.../simpleurl/SimpleUrlHarvester.java` | Persists `isSitemap` in harvester settings DB |
| `web/src/main/webapp/xsl/xml/harvesting/simpleurl.xsl` | Added `<isSitemap>` to the settings-to-XML transform (required for `isSitemap` to load from the DB) |
| `web-ui/.../harvest/type/simpleurl.html` | Added sitemap checkbox in harvester configuration UI |
| `web-ui/.../harvest/type/simpleurl.js` | Added `isSitemap` to harvester data model and XML serialization |
| `web-ui/.../admin/HarvestSettingsController.js` | Added "CDIF Sitemap" preset to harvester helper configuration |
| `web-ui/.../locales/en-admin.json` | Added `simpleurl-isSitemap` and `simpleurl-isSitemapHelp` locale strings |
| `schemas/iso19115-3.2018/.../oasis-catalog.xml` | Added `<system>` entries for concrete ISO schemas (mco, mrc, mrd, mrl, mdq, gfc, fcc) needed for XSD substitution group resolution |
| `web/.../data/config/index/records.json` | Fixed Elasticsearch 8.x mapping incompatibilities (fielddata on keyword, doc_values on text, copy_to on object) |
| `web/.../data/config/index/features.json` | Fixed Elasticsearch 8.x mapping incompatibilities (format on double, fielddata on keyword) |
| `web/.../config/config-service-monitoring.xml` | Disabled `DashboardAppHealthCheck` (Kibana) for dev environments without Kibana running |

## CDIF to ISO 19115-3 Field Mapping

The `fromJsonCdif.xsl` stylesheet maps CDIF schema.org/PROV/DCAT fields to ISO 19115-3 elements. The output is XSD-valid against the ISO 19115-3:2018 schemas bundled with GeoNetwork.

### Metadata-level properties

| CDIF Field | ISO 19115-3 Target |
|------------|---------------------|
| `@id` | `mdb:metadataIdentifier` |
| `@type` | `mdb:metadataScope` (mapped to ISO scope code) |
| `schema:inLanguage` | `mdb:defaultLocale` (2-letter → 3-letter language code) |
| `schema:creator` | `mdb:contact` role=author |
| `schema:provider` | `mdb:contact` role=distributor |
| `schema:subjectOf/schema:maintainer` | `mdb:contact` role=pointOfContact |
| `schema:dateModified` | `mdb:dateInfo` dateType=revision |
| `schema:subjectOf/schema:sdDatePublished` | `mdb:dateInfo` dateType=creation |
| `schema:datePublished` | `mdb:dateInfo` dateType=publication |
| — | `mdb:metadataStandard` (hardcoded ISO 19115-3) |
| `dcterms:conformsTo` (from subjectOf) | `mdb:metadataProfile` |
| `schema:includedInDataCatalog` (from subjectOf) | `mdb:metadataLinkage` |

### Identification info (citation)

| CDIF Field | ISO 19115-3 Target |
|------------|---------------------|
| `schema:name` | `cit:title` |
| `schema:identifier` | `cit:identifier` (DOI with codeSpace) |
| `schema:sameAs` | `cit:identifier` codeSpace=sameAs |
| `schema:version` | `cit:edition` |
| `schema:datePublished` | `cit:date` dateType=publication |
| `schema:dateModified` | `cit:date` dateType=revision |
| `schema:creator` | `cit:citedResponsibleParty` role=author |
| `schema:publisher` | `cit:citedResponsibleParty` role=publisher |
| `schema:contributor` (via Role wrapper) | `cit:citedResponsibleParty` with mapped role |

### Identification info (other)

| CDIF Field | ISO 19115-3 Target |
|------------|---------------------|
| `schema:description` | `mri:abstract` |
| `schema:creator` | `mri:pointOfContact` role=author |
| `schema:spatialCoverage` | `gex:EX_GeographicBoundingBox` |
| `schema:temporalCoverage` | `gex:EX_TemporalExtent/gml:TimePeriod` |
| `schema:keywords` | `mri:descriptiveKeywords/mri:MD_Keywords` |
| `schema:additionalType` | `mri:descriptiveKeywords` (with thesaurus if URI) |
| `schema:license` | `mri:resourceConstraints/mco:MD_LegalConstraints` |
| `schema:relatedLink` | `mri:associatedResource/mri:MD_AssociatedResource` |
| `schema:inLanguage` | `mri:defaultLocale` (inside identificationInfo) |
| funding, measurementTechnique, publishingPrinciples, variable summaries | `mri:supplementalInformation` (structured text block) |

### Content info (Feature Catalogue)

| CDIF Field | ISO 19115-3 Target |
|------------|---------------------|
| `schema:variableMeasured` | `mrc:MD_FeatureCatalogue/gfc:FC_FeatureCatalogue` |
| `variableMeasured/schema:name` | `gfc:memberName` |
| `variableMeasured/schema:description` | `gfc:definition` |
| `variableMeasured/schema:propertyID` | `gfc:code` |
| `variableMeasured/cdi:intendedDataType` | `gfc:valueType/gco:TypeName/gco:aName` |
| `variableMeasured/schema:unitText` or `unitCode` | `gfc:valueMeasurementUnit/gco:UomIdentifier` |

### Distribution

| CDIF Field | ISO 19115-3 Target |
|------------|---------------------|
| `schema:distribution` | `mrd:MD_DigitalTransferOptions/mrd:onLine` |
| `distribution/schema:contentUrl` | `cit:linkage` |
| `distribution/schema:encodingFormat` | `cit:applicationProfile` |
| `distribution/schema:name` | `cit:name` |
| `distribution/schema:description` | `cit:description` |
| `distribution/cdi:fileSize` + `cdi:fileSizeUofM` | `mrd:transferSize` (converted to MB) |

### Data quality

| CDIF Field | ISO 19115-3 Target |
|------------|---------------------|
| `dqv:hasQualityMeasurement` | `mdq:DQ_DataQuality/mdq:report/mdq:DQ_UsabilityElement` |
| `dqv:isMeasurementOf` | `mdq:nameOfMeasure` |
| `dqv:value` | `mdq:DQ_DescriptiveResult/mdq:statement` |

### Lineage (provenance)

| CDIF Field | ISO 19115-3 Target |
|------------|---------------------|
| `prov:wasGeneratedBy` | `mrl:processStep/mrl:LI_ProcessStep` |
| `prov:wasGeneratedBy/schema:description` | `mrl:description` |
| `prov:wasGeneratedBy/schema:endTime` | `mrl:stepDateTime` |
| `prov:wasGeneratedBy/prov:used` | `mrl:source/mrl:LI_Source` (nested in processStep) |
| `prov:wasDerivedFrom` | `mrl:source/mrl:LI_Source` (top-level) |
| Combined activity descriptions | `mrl:statement` (auto-generated) |

### Contributor role mapping

| CDIF `schema:roleName` | ISO `CI_RoleCode` |
|-------------------------|-------------------|
| contributor | contributor |
| editor | editor |
| funder | funder |
| principalInvestigator | principalInvestigator |
| sponsor | sponsor |
| collaborator | collaborator |
| (other values) | contributor (default) |

## XSD Schema Validation

The `fromJsonCdif.xsl` output is validated against the ISO 19115-3:2018 XSD schemas bundled with GeoNetwork at `schemas/iso19115-3.2018/.../schema/standards.iso.org/`.

### Schema locations

The output `xsi:schemaLocation` lists all concrete schemas needed for substitution group resolution:

- `mdb/2.0` — MD_Metadata (entry point)
- `mco/1.0` — MD_LegalConstraints (substitutes Abstract_Constraints)
- `mrc/2.0` — MD_FeatureCatalogue (substitutes Abstract_ContentInformation)
- `mrd/1.0` — MD_Distribution (substitutes Abstract_Distribution)
- `mrl/2.0` — LI_Lineage (substitutes Abstract_LineageInformation)
- `mdq/1.0` — DQ_DataQuality (substitutes Abstract_DataQuality)
- `gfc/1.1` — FC_FeatureCatalogue
- `fcc/1.0` — Abstract_FeatureCatalogue

Note: there is no bundled `mds/2.0` aggregator schema, so all concrete schemas must be listed individually.

### GeoNetwork runtime validation

GeoNetwork uses `oasis-catalog.xml` (in the schema plugin directory) to resolve HTTP schema URLs to local files. The catalog uses relative paths that work in the Java runtime.

### Oxygen XML Editor validation

Oxygen does not correctly resolve relative URIs in OASIS catalogs on Windows. Use `oxygen-catalog.xml` (repo root) instead — it contains `rewriteSystem` entries with absolute `file:///` paths pointing to the bundled schemas.

Setup: `Options → Preferences → XML → XML Catalog → Add` → point to `oxygen-catalog.xml`. Make sure "Resolve schema locations also through system mappings" is checked.

### Test pipeline

`test_cdif_xslt.py` replicates the harvester pipeline outside GeoNetwork:

1. Loads CDIF JSON-LD input and `cdif-frame.jsonld`
2. Applies JSON-LD framing (pyld library)
3. Converts framed JSON to XML (replicating `org.json.XML.toString()`)
4. Applies `fromJsonCdif.xsl` via Saxon C/HE (XSLT 2.0)
5. Runs structural validation checks against the output
6. Saves intermediate and output XML for inspection

Requirements: `pip install pyld saxonche lxml`

## JSON-to-XML Conversion Notes

GeoNetwork uses `org.json.XML.toString()` to convert JSON to intermediate XML before XSLT processing. Key transformations:

- JSON key `schema:name` becomes XML element `<schema_name>` (colon replaced by underscore)
- JSON key `@id` becomes XML element `<id>` (@ prefix stripped)
- JSON key `@type` becomes XML element `<type>`
- Nested JSON objects become nested XML elements
- JSON arrays become repeated XML elements with the same name
- The harvester injects `<uuid>`, `<apiUrl>`, and `<nodeUrl>` child elements into the intermediate XML

## Known Issues and Fixes

### Sitemap parsing — JDOM XPath on detached elements

**Problem**: GeoNetwork's `Xml.loadString()` calls `jdoc.getRootElement().detach()` (line 316 of `Xml.java`), which detaches the root element from its Document. XPath expressions using `//` fail silently on detached elements.

**Fix**: `extractUrlsFromSitemap()` uses direct JDOM `getChildren()` traversal with local-name matching instead of XPath. This correctly handles both namespaced and non-namespaced sitemaps.

### Harvester settings persistence — missing isSitemap in XSLT

**Problem**: The `simpleurl.xsl` transform (which converts flat DB settings back to hierarchical XML for `SimpleUrlParams.create()`) was missing the `<isSitemap>` element. This caused the parameter to be null when loaded from the database, even though it was correctly stored.

**Fix**: Added `<isSitemap><xsl:value-of select="isSitemap/value"/></isSitemap>` to `simpleurl.xsl`.

### Elasticsearch 8.x index mapping compatibility

**Problem**: The default GeoNetwork 4.4.9 index mappings (`records.json`, `features.json`) contain several constructs that are invalid in Elasticsearch 8.x:
- `"fielddata": true` on `keyword` type fields (fielddata is only for `text`)
- `"doc_values": false` on `text` type fields (text fields don't support doc_values)
- `"format": ""` on `double` type fields
- `"copy_to"` on `object` type dynamic templates

**Fix**: Changed affected field types from `keyword` to `text` where `fielddata` was needed, removed invalid `doc_values` and `format` properties, and removed `copy_to` from object-level dynamic template mappings.

### JSON-LD framing — Java jsonld-java drops complex fields

**Problem**: The Java `jsonld-java` library (used by GeoNetwork) produces fundamentally different framing results from the Python `pyld` library. Fields using `@list` containers (`schema:creator`), nested distributions (`schema:distribution` with `schema:hasPart`), funding (`schema:funding`), and contributors (`schema:contributor`) are silently dropped during framing.

**Fix**: `recoverDroppedFields()` in `Harvester.java` merges back fields from the original unframed JSON-LD input when the framing library drops them. The method checks these fields: `schema:creator`, `schema:contributor`, `schema:publisher`, `schema:provider`, `schema:funding`, `schema:distribution`, `schema:variableMeasured`, `schema:dateModified`.

### JSON-LD framing — null values from frame properties

**Problem**: JSON-LD framing introduces `null` values for every property defined in the frame document (`cdif-frame.jsonld`) that is absent in the source record. When `org.json.XML.toString()` serializes these, it writes the literal string `"null"` which causes downstream XSLT issues.

**Fix**: `removeNulls()` and `removeNullsFromList()` in `Harvester.java` recursively strip null-valued entries from the framed JSON before XML conversion. Maps and Lists that become empty after null removal are also removed.

### DashboardAppHealthCheck blocks admin UI

**Problem**: When Kibana is not running (common in dev environments), `DashboardAppHealthCheck` fails and the GeoNetwork admin UI becomes entirely grayed out / non-functional. The browser console shows `warninghealthcheck` returning HTTP 500.

**Fix**: Disabled `DashboardAppHealthCheck` in `web/.../config/config-service-monitoring.xml` by commenting it out. Other healthchecks (catalog, ES, indexing, CSW) continue to run normally.

## CDIF JSON-LD Formatter (Outbound)

The outbound formatter at `schemas/iso19115-3.2018/.../formatter/cdif/iso19115-3-to-cdif.xsl` converts ISO 19115-3 XML back to CDIF JSON-LD. It is accessible via:

```
GET /geonetwork/srv/api/records/{uuid}/formatters/cdif
```

### Formatter sections

The XSLT generates these CDIF JSON-LD properties:

| JSON-LD Property | Source in ISO 19115-3 |
|------------------|----------------------|
| `@context`, `@type`, `@id` | Hardcoded context; `mdb:metadataScope`; record URL |
| `schema:name` | `cit:title` |
| `schema:description` | `mri:abstract` |
| `schema:identifier` | `cit:identifier` (DOI detection via propertyID) |
| `schema:datePublished` | `cit:date` with `dateType=publication` |
| `schema:dateModified` | `cit:date` with `dateType=revision`, fallback to creation then publication |
| `schema:inLanguage` | `mri:defaultLocale` (3-letter → 2-letter code) |
| `schema:creator` | `cit:citedResponsibleParty` with `role=author` |
| `schema:contributor` | `cit:citedResponsibleParty` with role other than author/publisher |
| `schema:publisher` | `cit:citedResponsibleParty` with `role=publisher` |
| `schema:keywords` | `mri:descriptiveKeywords` |
| `schema:license` | `mco:MD_LegalConstraints` |
| `schema:distribution` | `mrd:MD_DigitalTransferOptions/mrd:onLine` |
| `schema:variableMeasured` | `gfc:FC_FeatureCatalogue` members |
| `schema:spatialCoverage` | `gex:EX_GeographicBoundingBox` |
| `schema:temporalCoverage` | `gex:EX_TemporalExtent` |
| `prov:wasGeneratedBy` | `mrl:processStep/mrl:LI_ProcessStep` |
| `prov:wasDerivedFrom` | `mrl:source/mrl:LI_Source` (top-level) |
| `dqv:hasQualityMeasurement` | `mdq:DQ_DataQuality` reports |
| `schema:funding` | Parsed from `mri:supplementalInformation` |
| `schema:measurementTechnique` | Parsed from `mri:supplementalInformation` |
| `schema:subjectOf` | Metadata-about-metadata (catalog record, profiles) |

### Distribution handling

The formatter distinguishes between primary distributions and archive members:
- **Primary distribution**: `cit:function` = `download` (even if URL is `nil/OGC/0/withheld`)
- **Archive members**: `cit:function` = `information` with URL = `nil/OGC/0/inapplicable`

Archive members are nested inside the primary distribution as `schema:hasPart`.

Encoding format prefers `mrd:distributionFormat/mrd:MD_Format` over `cit:protocol`. Bare protocol values (`http`, `https`, `ftp`) are excluded.

### Funding output

When funding data has structured markers (funder name, grant ID), it outputs `schema:name` and `schema:funder`. When it contains only free text (no structured markers), it outputs `schema:description` instead.

## Roundtrip Validation

The CDIF roundtrip (JSON-LD → ISO 19115-3 → JSON-LD) has been validated against 121 ADA (Astromaterials Data Archive) records:

- **120 PASS** — all expected fields preserved through the roundtrip
- **1 FAIL** — source data issue (`sameAs` value mismatch in source record)
- **0 ERROR** — no conversion failures

Expected structural differences in the roundtrip output (not considered failures):
- `@id` uses GeoNetwork API URL instead of original
- `@context` includes all CDIF prefixes (original may have fewer)
- Agent `@id` values are blank nodes instead of original URIs
- `schema:additionalType` stored as keywords (preserved but in different location)

## Test Data

- **CDIF validation repository**: The [CDIF validation repo](https://github.com/Cross-Domain-Interoperability-Framework/validation/tree/main/testJSONMetadata) contains 77 CDIF JSON-LD test files validated against the [CDIF Complete Schema](https://github.com/Cross-Domain-Interoperability-Framework/validation/blob/main/CDIFCompleteSchema.json) (JSON Schema Draft 2020-12). All 77 records have been successfully harvested and indexed.
- **ADA (Astromaterials Data Archive)**: 121 records harvested from the ADA sitemap at `https://ada.astromat.org/metadata/sitemap.xml`. These records include complex distributions (zip archives with `hasPart` members), funding, provenance, and measurement techniques. Roundtrip validation: 120/121 PASS.

## Related Repositories

- **CDIF validation**: https://github.com/Cross-Domain-Interoperability-Framework/validation — Test metadata files and JSON Schema
- **CDIF specification**: https://cross-domain-interoperability-framework.github.io/cdifbook/ — CDIF book and profiles
- **amds-ldeo/metadata**: https://github.com/amds-ldeo/metadata — Source metadata records

## Branch Information

- **Branch**: `DDEconfig`
- **Base**: GeoNetwork 4.4.9
- **Upstream**: https://github.com/geonetwork/core-geonetwork
