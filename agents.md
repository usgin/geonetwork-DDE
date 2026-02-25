# DDE / CDIF Metadata Harvester for GeoNetwork

## Overview

This fork of [GeoNetwork opensource](https://github.com/geonetwork/core-geonetwork) was originally developed to harvest and edit [Deep-time Digital Earth (DDE)](https://www.ddeworld.org/) ISO 19115-3 metadata. The DDE project uses GeoNetwork as its metadata catalogue for geoscience data resources, with customizations to the editor UI, indexing, and vocabularies for DDE-specific requirements.

The fork has since been extended with the ability to harvest [CDIF (Cross-Domain Interoperability Framework)](https://cross-domain-interoperability-framework.github.io/cdifbook/preamble/) metadata records encoded as JSON-LD based on the schema.org vocabulary.

CDIF defines a discovery metadata profile that uses schema.org vocabulary to describe datasets, their distributions, creators, licenses, and spatial/temporal coverage. This harvester ingests CDIF JSON-LD records via a sitemap, converts them to ISO 19115-3 XML, and indexes them in GeoNetwork for standard search and discovery.

## Architecture

The harvester extends GeoNetwork's existing **Simple URL Harvester** with sitemap support. The processing pipeline is:

```
Sitemap XML          JSON-LD files         Intermediate XML       ISO 19115-3 XML
(list of URLs)  -->  (fetched per-URL) --> (org.json.XML)     --> (fromJsonCdif.xsl)
                                                                       |
                                                                  GeoNetwork DB +
                                                                  Elasticsearch index +
                                                                  search UI
```

1. The harvester fetches a sitemap XML file listing CDIF record URLs
2. Each URL is fetched individually, returning a single JSON-LD document
3. GeoNetwork's built-in `org.json.XML.toString()` converts JSON to intermediate XML
4. A custom XSLT (`fromJsonCdif.xsl`) transforms the intermediate XML to valid ISO 19115-3
5. GeoNetwork indexes and stores the record using its standard iso19115-3.2018 schema support

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
| `schemas/iso19115-3.2018/.../convert/fromJsonCdif.xsl` | XSLT converting CDIF JSON-LD intermediate XML to ISO 19115-3 `mdb:MD_Metadata` |
| `agents.md` | This documentation file |

### Modified Files

| File | Change |
|------|--------|
| `harvesters/.../simpleurl/Harvester.java` | Added sitemap processing: `extractUrlsFromSitemap()`, `collectSingleJsonRecord()`, `isSitemapContent()`. Fixed sitemap parsing to use direct JDOM traversal instead of XPath (works around `Xml.loadString()` detaching root from Document). |
| `harvesters/.../simpleurl/SimpleUrlParams.java` | Added `isSitemap` parameter |
| `harvesters/.../simpleurl/SimpleUrlHarvester.java` | Persists `isSitemap` in harvester settings DB |
| `web/src/main/webapp/xsl/xml/harvesting/simpleurl.xsl` | Added `<isSitemap>` to the settings-to-XML transform (required for `isSitemap` to load from the DB) |
| `web-ui/.../harvest/type/simpleurl.html` | Added sitemap checkbox in harvester configuration UI |
| `web-ui/.../harvest/type/simpleurl.js` | Added `isSitemap` to harvester data model and XML serialization |
| `web-ui/.../admin/HarvestSettingsController.js` | Added "CDIF Sitemap" preset to harvester helper configuration |
| `web-ui/.../locales/en-admin.json` | Added `simpleurl-isSitemap` and `simpleurl-isSitemapHelp` locale strings |
| `web/.../data/config/index/records.json` | Fixed Elasticsearch 8.x mapping incompatibilities (fielddata on keyword, doc_values on text, copy_to on object) |
| `web/.../data/config/index/features.json` | Fixed Elasticsearch 8.x mapping incompatibilities (format on double, fielddata on keyword) |

## CDIF to ISO 19115-3 Field Mapping

The `fromJsonCdif.xsl` stylesheet maps CDIF schema.org fields to ISO 19115-3 elements:

| CDIF Field (schema.org) | ISO 19115-3 Target |
|-------------------------|---------------------|
| `@id` | `mdb:metadataIdentifier` |
| `@type` | `mdb:metadataScope` (mapped to ISO scope code) |
| `schema:name` | `mri:citation/cit:title` |
| `schema:description` | `mri:abstract` |
| `schema:identifier` | `cit:identifier` (DOI with codeSpace) |
| `schema:datePublished` | `cit:CI_Date` dateType=publication |
| `schema:dateModified` | `cit:CI_Date` dateType=revision |
| `schema:creator` | `cit:citedResponsibleParty` and `mri:pointOfContact` (role=author) |
| `schema:creator/identifier` | `cit:partyIdentifier` (ORCID) |
| `schema:license` | `mri:resourceConstraints/mco:MD_LegalConstraints` |
| `schema:distribution` | `mrd:transferOptions` (contentUrl, encodingFormat) |
| `schema:spatialCoverage` | `gex:geographicElement/gex:EX_GeographicBoundingBox` |
| `schema:keywords` | `mri:descriptiveKeywords/mri:MD_Keywords` |
| `schema:additionalType` | `mri:descriptiveKeywords` (with thesaurus if URI) |

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

## Test Data

The [CDIF validation repository](https://github.com/Cross-Domain-Interoperability-Framework/validation/tree/main/testJSONMetadata) contains 77 CDIF JSON-LD test files validated against the [CDIF Complete Schema](https://github.com/Cross-Domain-Interoperability-Framework/validation/blob/main/CDIFCompleteSchema.json) (JSON Schema Draft 2020-12). All 77 records have been successfully harvested and indexed in testing.

## Related Repositories

- **CDIF validation**: https://github.com/Cross-Domain-Interoperability-Framework/validation — Test metadata files and JSON Schema
- **CDIF specification**: https://cross-domain-interoperability-framework.github.io/cdifbook/ — CDIF book and profiles
- **amds-ldeo/metadata**: https://github.com/amds-ldeo/metadata — Source metadata records

## Branch Information

- **Branch**: `DDEconfig`
- **Base**: GeoNetwork 4.4.9
- **Upstream**: https://github.com/geonetwork/core-geonetwork
