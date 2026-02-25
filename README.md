# GeoNetwork opensource — DDE / CDIF Fork

This is a fork of [GeoNetwork opensource](https://github.com/geonetwork/core-geonetwork) (based on release 4.4.9) originally developed to harvest and edit [Deep-time Digital Earth (DDE)](https://www.ddeworld.org/) ISO 19115-3 metadata. It has since been extended with support for harvesting [CDIF (Cross-Domain Interoperability Framework)](https://cross-domain-interoperability-framework.github.io/cdifbook/preamble/) metadata records.

CDIF metadata records are encoded as JSON-LD using the schema.org vocabulary. This fork extends GeoNetwork's Simple URL Harvester with sitemap support and includes an XSLT stylesheet that converts CDIF JSON-LD to ISO 19115-3 XML for standard cataloguing and discovery.

See [agents.md](agents.md) for full technical documentation of the CDIF harvester implementation, field mappings, and configuration instructions.

**Branch**: `DDEconfig` | **Upstream**: [geonetwork/core-geonetwork](https://github.com/geonetwork/core-geonetwork) 4.4.9

---

## Prerequisites

- **Java 11** (e.g. [Adoptium OpenJDK 11 LTS](https://adoptium.net/temurin/archive/?version=11))
- **Apache Maven 3.6+**
- **Docker** (for Elasticsearch)
- **Git**

## Quick Start

### 1. Clone and build

```bash
git clone https://github.com/<your-org>/core-geonetwork.git
cd core-geonetwork
git checkout DDEconfig
git submodule update --init --recursive
mvn clean install -DskipTests
```

> **Windows / Java 11.0.2 TLS note**: If Maven downloads fail with SSL errors, add:
> ```
> set MAVEN_OPTS=-Dhttps.protocols=TLSv1.2 -Djdk.tls.client.protocols=TLSv1.2
> ```

### 2. Start Elasticsearch 8.14.3

```bash
cd es
docker-compose up -d
```

Elasticsearch will be available at http://localhost:9200 and Kibana at http://localhost:5601.

### 3. Run GeoNetwork

```bash
cd web
mvn jetty:run -Penv-dev
```

GeoNetwork will be available at http://localhost:8080/geonetwork. Default admin login is `admin` / `admin`.

### 4. Configure the CDIF harvester

1. Log in as **admin**
2. Go to **Admin Console > Harvesting**
3. Click **Harvest from > Simple URL**
4. Select the **CDIF Sitemap** preset from the helper dropdown (top of the form)
5. Set the **URL** to the sitemap listing your CDIF JSON-LD files
6. Verify these settings are filled in by the preset:
   - **URL is a sitemap**: checked
   - **Record ID path**: `/@id`
   - **Conversion**: `schema:iso19115-3.2018:convert/fromJsonCdif`
7. Save and click **Harvest**

See [agents.md](agents.md) for details on field mappings, sitemap format, and advanced options.

## Harvesting Options

This fork supports several harvesting modes through the **Simple URL Harvester**:

| Mode | Description | Key Settings |
|------|-------------|--------------|
| **CDIF Sitemap** | Harvest CDIF JSON-LD records listed in a sitemap XML | `isSitemap=true`, conversion=`fromJsonCdif` |
| **DCAT** | Standard GeoNetwork DCAT harvesting | conversion=`fromJsonDcat` |
| **CKAN** | Standard GeoNetwork CKAN harvesting | conversion=`fromJsonCkan` |
| **OpenDataSoft** | Standard GeoNetwork OpenDataSoft harvesting | conversion=`fromJsonOpendatasoft` |
| **Custom JSON API** | Any JSON API with configurable pagination and loop elements | Set `loopElement`, `recordIdPath`, and custom `toISOConversion` |

### CDIF sitemap format

The sitemap must follow the [sitemaps.org protocol](https://www.sitemaps.org/protocol.html). Each `<loc>` URL should return a single CDIF JSON-LD document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/metadata/record-1.json</loc></url>
  <url><loc>https://example.com/metadata/record-2.json</loc></url>
</urlset>
```

### Serving local files for testing

To test with local JSON-LD files, serve them via a simple HTTP server:

```bash
cd /path/to/json-ld-files
python -m http.server 9999
```

Then create a sitemap XML listing URLs like `http://localhost:9999/record-1.json` and point the harvester at that sitemap.

## Build Options

| Command | Description |
|---------|-------------|
| `mvn clean install -DskipTests` | Full build, skip tests |
| `mvn install -DskipTests -T 2C` | Parallel build (2 threads per core) |
| `mvn install -DskipTests -rf :gn-harvesters` | Resume build from harvesters module |
| `cd web && mvn process-resources -PschemasCopy` | Hot-reload UI/schema changes into running Jetty |
| `cd web && mvn clean:clean@reset` | Reset all caches and database |

## GeoNetwork Features

* Immediate search access to local and distributed geospatial catalogues
* Uploading and downloading of data, graphics, documents, pdf files and any other content type
* An interactive Web Map Viewer to combine Web Map Services from distributed servers around the world
* Online editing of metadata with a powerful template system
* Scheduled harvesting and synchronization of metadata between distributed catalogs
* Support for OGC-CSW 2.0.2, ISO 1911x and DCAT-AP metadata profiles, OAI-PMH, SRU protocols
* Fine-grained access control with group and user management
* Multi-lingual user interface
* **CDIF JSON-LD harvesting via sitemap** (this fork)

## Documentation

* [agents.md](agents.md) — CDIF harvester architecture, field mappings, and configuration
* [Software Development](/software_development/) — Development environment, building, testing
* [docs.geonetwork-opensource.org](https://docs.geonetwork-opensource.org) — Upstream GeoNetwork manual

## Developer Documentation

Developer documentation located in ``README.md`` files in the code-base:

* General documentation for the project as a whole is in this [README.md](README.md)
* [CDIF Harvester](agents.md) — architecture, field mappings, and configuration for the CDIF metadata harvester
* [Software Development Documentation](/software_development/) provides instructions for setting up a development environment, building GeoNetwork, compiling user documentation, and making a releases.
* Module specific documentation can be found in each module
