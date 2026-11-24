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

Entries may also point at **HTML landing pages** that carry their metadata in a
`<script type="application/ld+json">` block — the science-on-schema.org pattern — as well as at
`.json` documents. Added 2026-11-15; before that an HTML entry failed with a JSON parse error on the
leading `<`. Where a page holds several JSON-LD blocks, the one describing a `Dataset` is selected
(`BreadcrumbList` and `Organization` blocks commonly sit beside it); the whole block is passed on,
not the matched node, so `@context` survives and framing still runs.

### How a record is identified as CDIF

**By configuration, unless dispatch rules are set.** With no rules, `isCdifConversion()` is a
substring test for `fromJsonCdif` against the chosen conversion, and the chosen conversion is
whatever the harvester was configured with — the behaviour since the harvester was written. Set
rules and a JSON record's own declared conformance picks the conversion instead, so one harvester
can take a mixed feed.

#### Dispatch on the catalog record's conformance class

Selecting the XSLT from the record's declared conformance, so one harvester can take a mixed feed.
Not implemented. The matcher specification, which is narrower than it first appears:

1. Find `schema:subjectOf` (accept the unprefixed `subjectOf`, and object-or-array).
2. Among its entries, take the one whose `schema:additionalType` contains `dcat:CatalogRecord` —
   accepting both the compacted form and the expanded `http://www.w3.org/ns/dcat#CatalogRecord`.
   **Do not** match on `@type`: the catalog record is `"@type": ["schema:Dataset"]` with
   `dcat:CatalogRecord` carried in `schema:additionalType`, so an `@type` test never fires.
3. Read `dcterms:conformsTo` **on that node only**, as array-or-object of `{"@id": …}`.
4. Match ordered rules against those `@id`s, most specific first.

Step 3 is the part that matters. `dcterms:conformsTo` is legal in four places in v1.1.1
`profile-core` — on a distribution, on a distribution's `potentialAction` result, and on
`schema:subjectOf` (twice). A "find any `conformsTo`" matcher would dispatch a record on the format
conformance of one of its *data files*.

Rules must be ordered because every CDIF record asserts several classes at once: the released
vocabulary is `cdif/core/1.1`, `discovery/1.1`, `data_description/1.1`, `data_structure/1.1`,
`manifest/1.1` and `codelist/1.1`, and a record declares `core/1.1` alongside its specific profile.
A `core/1.1` rule placed first would swallow everything.

Two implementation notes, both now done. The conformance is read from the **unframed** record —
framing rewrites structure, which is why `recoverDroppedFields()` exists — and `isCdifConversion()`
takes the *selected* conversion rather than reading the configured one, or a rule-dispatched CDIF
record would silently skip framing.

Implemented 2026-11-15 in `CdifConformance` (matcher and rules) and `Harvester.selectConversion()`
(wiring), with 21 unit tests in `CdifConformanceTest`. The two traps above are each asserted by a
named test, including that a `conformsTo` on a `schema:distribution` is **not** picked up.

##### Configuring it

A new harvester field, `conformanceRules`, stored beside `toISOConversion`. One rule per line (or
separated by `;`), `conformanceUri=conversion`, blank lines and `#` comments ignored. A trailing `*`
makes the URI a prefix, which is how one rule covers a family of profile URIs:

```
# most specific first
https://w3id.org/cdif/dde/1.0/*=schema:iso19115-3.2018:convert/fromDde
https://w3id.org/cdif/core/2.0=schema:iso19115-3.2018:convert/fromJsonCdifV2
https://w3id.org/cdif/core/1.1=schema:iso19115-3.2018:convert/fromJsonCdif
```

The conversion name is the full transform identifier, the same form `toISOConversion` takes —
`schema:iso19115-3.2018:convert/fromJsonCdif`, not the bare file name. `GET
/srv/api/site/info/transforms` lists what the catalogue offers.

Three deliberate limits:

- **Rules are tried in order, and for each rule every declared URI**, so rule order decides rather
  than the order a record happens to list its classes in. A rule for a shared base class placed
  first swallows every record; there is a test asserting exactly that, so the cost of getting the
  order wrong is visible rather than folklore.
- **No match means fall back**, to the configured `toISOConversion`, logged at debug. A record is
  never dropped for declaring something unrecognised.
- **Only the JSON path dispatches.** `collectRecordsFromRdf` and `collectRecordsFromXml` call the
  two-argument `applyConversion` and always use the configured conversion, since neither carries a
  conformance declaration to dispatch on.

The DDE conformance URIs this was blocked on are now settled: each DDE profile pins
`https://w3id.org/cdif/dde/1.0/{profileName}` (usgin/ddeBuildingBlocks#7, merged 2026-11-15), which
is a versioned conformance class rather than the register path with no version that `ddeCore` used
to declare. The w3id redirects are perma-id/w3id.org#7199.

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

### WAF harvesting is the WebDAV harvester, not this one

A WAF (Web Accessible Folder — a plain HTTP directory listing of metadata files) is **not** a
Simple URL mode. It is handled by the **WebDAV** harvester, whose `WAFRetriever` walks the listing
and descends into subdirectories. This is in production use: the deployed catalogue harvests
`https://data.noaa.gov/waf/NOAA/NESDIS/NGDC/MGG/Geology/iso/xml/` as the `ngdc-mgg-geology`
harvester.

**It cannot ingest CDIF as it stands**, and the reason is one method —
`WAFRetriever.getFileType` in
`harvesters/src/main/java/org/fao/geonet/kernel/harvest/harvester/webdav/WAFRetriever.java:72-82`:

| link in the listing | classified as |
|---|---|
| contains `REQUEST=GETCAPABILITIES` | `type_GetCapabilities` |
| ends `.XML` (case-insensitive) | `type_xml` |
| ends `/` | `type_dir` — descend into it |
| anything else, `.json` included | `null` |

`retrieveFiles` then does `if (fileType == null) continue;` with **no log statement of any kind**,
not even at debug level. So pointing the WebDAV harvester at a WAF of CDIF `.json` files yields
zero records and reports no error — it looks like an empty folder.

Supporting it would take two changes, and the second is the substantial one:

1. Teach `getFileType` to recognise `.json` (and return a new type for it).
2. Run the CDIF preparation pipeline on what is fetched. `WAFRemoteFile.getMetadata`
   (`WAFRemoteFile.java:75`) is `return Xml.loadFile(new URL(path))` — it parses the fetched
   resource straight into a JDOM `Element`, so a `.json` file dies at the parse, exactly as a
   CDIF upload does in Contribute > Import. A JSON branch has to go through `CdifJsonPreparer`
   (frame → `removeNulls` → `recoverDroppedFields`) and the `JsonRecordToXml` synthesis step
   before `fromJsonCdif.xsl` can run. That machinery already exists and is shared by the
   SimpleUrl and Directory harvesters; it is not wired into WebDAV.

Until then, the two CDIF ingest routes that work are the **sitemap** (above) and a **single
record by URL**, both through the Simple URL harvester and both needing no code.

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

### Version family, and which conformance classes it declares

CDIF versions its conformance URIs as `https://w3id.org/cdif/{module}/{version}`, and a release
changes only the version: CDIF `main` is the **1.1** family throughout, the unmerged
`release/conformance-2.0` branch is **2.0** throughout. One parameter therefore covers the switch:

```
GET /geonetwork/srv/api/records/{uuid}/formatters/cdif?cdifVersion=2.0
```

`cdifVersion` defaults to `1.1`, which is what CDIF publishes and what the DDE building blocks
vendor. `XsltFormatter` passes URL parameters to the stylesheet by name, so no other wiring is
needed. Nothing else in the formatter hardcodes a version.

**The declared classes follow the body actually emitted**, not a fixed list, on the principle
CDIF's own `validation/detect_conformance.py` uses: a class is declared when the record uses the
elements that class introduces beyond its base. Before 2026-11-15 the formatter emitted a single
fixed `discovery/1.1` whatever the record contained — over-declaring for a bare record, and never
declaring `core`, which `cdifCore` requires.

The rule lives in `formatter/cdif/cdif-conformance.xsl`, kept separate from the main formatter and
free of `util:` extension functions so it can be driven directly under plain Saxon. It tests the
emitted JSON text rather than re-deriving the ISO-side conditions, deliberately: re-deriving would
leave two expressions of one rule, free to drift, which is how a record ends up declaring a class
it does not satisfy.

| class | marker |
|---|---|
| `core/{v}` | always — the formatter always emits a Dataset with a name and an identifier |
| `discovery/{v}` | any of `schema:measurementTechnique`, `schema:variableMeasured`, `schema:spatialCoverage`, `schema:temporalCoverage`, `dqv:hasQualityMeasurement` |
| `manifest/{v}` | `schema:hasPart`, which this formatter emits only for archive members on a distribution item |

Three of the six CDIF modules are **not declarable from this formatter**, verified by grepping it
for each marker:

- `data_description` needs variables typed `cdi:InstanceVariable`; `cdif-variables` emits
  `schema:PropertyValue` only.
- `data_structure` needs `cdi:isStructuredBy` or a `cdi:` structure class; neither is emitted.
- `provenance` needs a dual-typed `prov:Activity` + `schema:Action` carrying one of
  `schema:instrument`, `schema:object` or `schema:actionProcess`. `cdif-provenance` emits the dual
  type but only `schema:description` and `prov:used`, which is the minimal activity `cdifCore`
  already covers.

Verified against the oracle, not just by reading: nine records covering each marker, the
version swap, a provenance activity carrying only description and `prov:used`, and a description
containing the literal text `"schema:hasPart"`, were run through both the XSLT (under Saxon) and
`detect_conformance.py`. **All nine agree.** The escaped-lookalike case confirms that searching for
the key with its trailing colon cannot be fooled by content, because `util:escapeForJson` turns the
quotes into `\"`.

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

`validate_cdif_output.py` fetches `/formatters/cdif` for every indexed record and validates it
against the CDIF **discovery** profile (`_sources/profiles/cdifProfile/cdifDiscovery/resolvedSchema.json`
in the CDIF register).

**Measured 2026-11-13 on 4.4.9-0: 122 PASS, 0 FAIL, 0 ERROR** of 122 records (121 ADA plus the geologic-age fixture below).

The earlier figure of "120/121 PASS" was measured against `CDIFcomplete`, a schema that no longer
exists under that name: the CDIF register renamed and regrouped its profiles on 2026-03-21
(metadataBuildingBlocks `dab021ad26`). Re-measured against the current register *before* the fixes
below, the result was **0/121** — CDIF had tightened two shapes that `iso19115-3-to-cdif.xsl` still
emitted in the pre-2026 form. Both are now fixed:

- `dcterms:conformsTo` must **contain** `{"@id": "https://w3id.org/cdif/discovery/1.1"}` — a bare
  `@id` reference (`additionalProperties: false`), and the *versioned* URI, not
  `https://w3id.org/cdif/profiles/discovery`. Because the constraint is `contains`, further entries
  are allowed, so profiles declared in the source metadata are appended alongside it rather than
  replacing it.
- `@type` and `schema:measurementTechnique` must be **arrays** where the formatter emitted scalars:
  `schema:Place` (both spatialCoverage branches), `schema:GeoShape`, `dqv:QualityMeasurement`, and
  the measurement-technique string. The `schema:box` value itself was already correct — SW
  latitude/longitude then NE — only its `@type` was wrong.

### Geologic time, and why the ADA corpus does not test it

`schemas/iso19115-3.2018/src/test/resources/metadata-geologic-age-cdif.xml` is the only record
that exercises the geologic-time branch of `iso19115-3-to-cdif.xsl`. **None of the 121 ADA records
do** — they carry no `mri:extent` at all — so a green ADA run says nothing about this code path,
and said nothing about it while the path was broken.

CDIF's discovery profile offers two independent `anyOf` forms for a geologic interval, and they
take different properties:

| form | properties | requirement |
|---|---|---|
| named eras | `time:intervalStartedBy` / `time:intervalFinishedBy` | plain URI strings |
| numeric ages | `time:hasBeginning` / `time:hasEnd` | each REQUIRES `time:inTimePosition` with `@type` (array), `time:hasTRS` (string), `time:numericPosition` (number) |

The formatter emits both independently, which matters because **a bound with a name but no age must
not produce a `time:hasBeginning`**: a bound lacking `time:inTimePosition` fails the numeric form
without satisfying the named one, so a partial bound is worse than none. The fixture is built around
exactly that asymmetry — its begin bound (Paleoproterozoic) has an era URI *and* an age, its end
bound (Holocene) has only an era URI and a name — so a formatter that emits a bare `time:hasEnd`
fails it.

Until 2026-11-13 the branch emitted scalar `@type` instead of arrays, `time:hasTRS` as an
`{"@id": ...}` object instead of a string, and `schema:value` instead of `time:numericPosition`;
it also selected bounds by document order (`(.//gml:timePosition[@frame])[2]`) rather than by
`gml:begin` / `gml:end`, so an end bound without an age silently became the *next* interval's
begin value. Re-import the fixture and re-run the validator after touching this branch.

Use the default `--schema discovery`. `--schema complete` is the wrong profile for this output and
reports 121 failures with ~879 error paths, because `cdifComplete` requires `schema:variableMeasured`
— data-description metadata that GeoNetwork does not emit.

This measurement requires GeoNetwork and Elasticsearch running, and a current clone of the CDIF
register at the path in `validate_cdif_output.py`'s `CDIF_SCHEMA_DIR`. Re-run it after any change to
`iso19115-3-to-cdif.xsl`, and after any CDIF register update — the register is the moving part here,
as the 0/121 result showed.

Expected structural differences in the roundtrip output (not considered failures):
- `@id` uses GeoNetwork API URL instead of original
- `@context` includes all CDIF prefixes (original may have fewer)
- Agent `@id` values are blank nodes instead of original URIs
- `schema:additionalType` stored as keywords (preserved but in different location)

## Test Data

- **CDIF validation repository**: The [CDIF validation repo](https://github.com/Cross-Domain-Interoperability-Framework/validation/tree/main/testJSONMetadata) contains 77 CDIF JSON-LD test files validated against the [CDIF Complete Schema](https://github.com/Cross-Domain-Interoperability-Framework/validation/blob/main/CDIFCompleteSchema.json) (JSON Schema Draft 2020-12). All 77 records have been successfully harvested and indexed.
- **ADA (Astromaterials Data Archive)**: 121 records harvested from the ADA sitemap at `https://ada.astromat.org/metadata/sitemap.xml`. These records include complex distributions (zip archives with `hasPart` members), funding, provenance, and measurement techniques. Roundtrip validation: 121/121 PASS against the CDIF discovery profile, measured 2026-11-13 (see Roundtrip Validation). None of them carry a temporal extent, so they do not cover geologic time.

## Related Repositories

- **CDIF validation**: https://github.com/Cross-Domain-Interoperability-Framework/validation — Test metadata files and JSON Schema
- **CDIF specification**: https://cross-domain-interoperability-framework.github.io/cdifbook/ — CDIF book and profiles
- **amds-ldeo/metadata**: https://github.com/amds-ldeo/metadata — Source metadata records

## Branch Information

- **Branch**: `DDEconfig`
- **Base**: GeoNetwork 4.4.9
- **Upstream**: https://github.com/geonetwork/core-geonetwork
