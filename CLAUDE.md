# CLAUDE.md — Project Instructions for Claude Code

## Project Overview

This is **GeoNetwork-DDE**, a fork of GeoNetwork opensource (v4.4.9) customized for the Deep-time Digital Earth (DDE) programme and extended with a CDIF sitemap harvester. The active development branch is `DDEconfig`.

## Build & Run

```bash
# Full build (Java 11, Maven 3.8.3+)
mvn clean install -DskipTests

# Start Elasticsearch
cd es && docker-compose up -d

# Run GeoNetwork (Jetty, port 8080)
cd web && mvn jetty:run -Penv-dev
```

Hot-reload schema/UI changes: `cd web && mvn process-resources -PschemasCopy`

## Repository Structure

- **DDE customizations** are concentrated in `schemas/iso19115-3.2018/src/main/plugin/iso19115-3.2018/`
  - `layout/config-editor.xml` — Editor views (ddeview is the default, 8 tabs)
  - `layout/layout.xsl`, `layout-custom-fields-date.xsl` — Rendering with DDE additions
  - `convert/` — DDE format converters + `utilityDDE/` (12 shared XSLTs)
  - `formatter/dde/view.xsl` — DDE output format
  - `index-fields/link-utility.xsl` — Indexing with nilReason support
  - `loc/eng/strings.xml` — Help text and labels
- **CDIF harvester** is in `harvesters/src/main/java/.../simpleurl/Harvester.java`
  - Conversion XSLT: `schemas/iso19115-3.2018/.../convert/fromJsonCdif.xsl`
- **DDE SKOS vocabularies**: `web/src/main/webapp/WEB-INF/data/config/codelist/local/thesauri/theme/`
- **Elasticsearch mappings**: `web/src/main/webapp/WEB-INF/data/config/index/records.json` and `features.json`

## Key Technical Details

- **Metadata schema**: ISO 19115-3:2018 is the primary schema. Dublin Core and ISO 19110 are disabled in the build.
- **XSLT version**: All stylesheets use XSLT 2.0 (Saxon processor).
- **Editor views**: The `ddeview` in config-editor.xml uses GeoNetwork's XML-based view definition system with tabs, sections, fields, actions, and thesaurus pickers.
- **Geologic time**: The extent tab supports geologic age via `gml:TimeInstant` with `gml:timePosition frame="Ma before present"`.
- **DDE codelists**: DDE-specific codelist URLs use `https://www.ddeworld.org/resource/codelist/...`.
- **Build**: Maven multi-module project. Key modules: `core`, `harvesters`, `services`, `schemas`, `web`, `web-ui`.

## Conventions

- Branch `DDEconfig` tracks DDE customizations on top of GeoNetwork 4.4.9.
- Branch `main` tracks upstream releases for merging.
- DDE additions are **additive** — upstream functionality is preserved alongside DDE views/converters.
- Schema plugin files follow GeoNetwork's standard plugin directory layout.

## Documentation

- `README.md` — Project overview, DDE editor view, build/deploy instructions
- `agents.md` — CDIF harvester architecture, field mappings, DDE editor customizations, configuration
