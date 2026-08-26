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

**JDK:** the build targets Java 11, but the JDK on `PATH` on this machine is Temurin 21. Point `JAVA_HOME` at a JDK 11 install before running Maven — the ambient default is wrong and the failure surfaces as unrelated compile errors.

## Repository Structure

- **DDE customizations** are concentrated in `schemas/iso19115-3.2018/src/main/plugin/iso19115-3.2018/`
  - `layout/config-editor.xml` — Editor views (ddeview is the default, 8 tabs)
  - `layout/layout.xsl`, `layout-custom-fields-date.xsl` — Rendering with DDE additions
  - `convert/` — DDE format converters + `utilityDDE/` (12 shared XSLTs)
  - `formatter/dde/view.xsl` — DDE output format
  - `index-fields/link-utility.xsl` — Indexing with nilReason support
  - `loc/eng/strings.xml` — Help text and labels
- **CDIF harvester** is in `harvesters/src/main/java/.../simpleurl/Harvester.java`
  - JSON-LD framing: `schemas/iso19115-3.2018/.../convert/cdif-frame.jsonld`
  - Inbound XSLT: `schemas/iso19115-3.2018/.../convert/fromJsonCdif.xsl` (CDIF → ISO 19115-3)
  - Outbound XSLT: `schemas/iso19115-3.2018/.../formatter/cdif/iso19115-3-to-cdif.xsl` (ISO 19115-3 → CDIF)
  - Key Harvester.java methods: `recoverDroppedFields()` (merges fields dropped by jsonld-java framing), `removeNulls()` (strips null values from framed JSON)
  - Schema catalog (GeoNetwork): `schemas/iso19115-3.2018/.../oasis-catalog.xml`
  - Schema catalog (Oxygen validation): `oxygen-catalog.xml` (repo root, machine-specific absolute paths)
- **DDE SKOS vocabularies**: `web/src/main/webapp/WEB-INF/data/config/codelist/local/thesauri/theme/`
- **Elasticsearch mappings**: `web/src/main/webapp/WEB-INF/data/config/index/records.json` and `features.json`

## Key Technical Details

- **Metadata schema**: ISO 19115-3:2018 is the primary schema. Dublin Core and ISO 19110 are disabled in the build.
- **XSLT version**: All stylesheets use XSLT 2.0 (Saxon processor).
- **CDIF conversion (inbound)**: `fromJsonCdif.xsl` produces XSD-valid ISO 19115-3 output. The XSLT output includes `xsi:schemaLocation` with HTTP URLs for all concrete schemas (mdb, mco, mrc, mrd, mrl, mdq, gfc, fcc). GeoNetwork's `oasis-catalog.xml` resolves these to bundled local schemas at runtime.
- **CDIF conversion (outbound)**: `iso19115-3-to-cdif.xsl` converts ISO 19115-3 back to CDIF JSON-LD. Accessible via `/srv/api/records/{uuid}/formatters/cdif`. Roundtrip validated: 120/121 ADA records pass.
- **JSON-LD framing caveat**: Java `jsonld-java` drops complex fields (`schema:creator` with `@list`, `schema:distribution`, `schema:funding`, `schema:contributor`) during framing. `recoverDroppedFields()` in Harvester.java merges them back from the original input.
- **Dev healthcheck**: `DashboardAppHealthCheck` in `config-service-monitoring.xml` is disabled — it blocks the admin UI when Kibana isn't running.
- **Schema validation**: For local validation in Oxygen XML Editor, use `oxygen-catalog.xml` (repo root) which has absolute `file:///` paths. The GeoNetwork `oasis-catalog.xml` uses relative paths that work in Java but not in standalone Oxygen on Windows.
- **Editor views**: The `ddeview` in config-editor.xml uses GeoNetwork's XML-based view definition system with tabs, sections, fields, actions, and thesaurus pickers.
- **Geologic time**: The extent tab supports geologic age via `gml:TimeInstant` with `gml:timePosition frame="Ma before present"`.
- **DDE codelists**: DDE-specific codelist URLs use `https://www.ddeworld.org/resource/codelist/...`.
- **Build**: Maven multi-module project. Key modules: `core`, `harvesters`, `services`, `schemas`, `web`, `web-ui`.

## Conventions

- Branch `DDEconfig` tracks DDE customizations on top of GeoNetwork 4.4.9 (`pom.xml` version `4.4.9-0`).
- Branch `main` tracks upstream releases for merging.
- **Upstream drift:** GeoNetwork opensource is at **4.4.12** (released 2026-07-08); this fork is three patch releases behind on the same 4.4 line. The local `upstream/main` ref is stale — its tip predates 4.4.10 and no 4.4.10+ tags are fetched — so start any rebase with `git fetch upstream --tags`.
- DDE additions are **additive** — upstream functionality is preserved alongside DDE views/converters.
- Schema plugin files follow GeoNetwork's standard plugin directory layout.

## Related repositories (DDE source material)

The DDE half of this fork originated in two GitLab repos at `C:\GithubC\DDE`
(`opencode.deep-time.org`), which are archival but remain **authoritative for the DDE standard
itself**. Nothing below is duplicated in this repo — go there for it:

- **DDE XML Schema** — `dde-metadata/DDEMetadataXSD_20240103.xsd` (namespace
  `https://www.ddeworld.org/resource/standards/dde/ds01/metadata/1.0`, root `metadata:MD_Metadata`),
  plus the two earlier revisions for reading older instances.
- **Normative spec** — `DDE_Metadata_standard_editversion2.docx`; the frozen 2023-11-07 release is in
  `release20231107/`.
- **Round-trip fixtures** — `dde-metadata/ExampleXML/`, the same records in matched DDE / ISO 19139 /
  ISO 19115-3 form. These are the only regression corpus for the DDE crosswalks; use them when
  changing anything in `convert/utilityDDE/`.
- **Ancestors of the DDE converters** — the original `ddeTo*` / `*ToDDE` stylesheets and an earlier
  copy of this schema plugin. Useful as history when a mapping decision looks arbitrary.
- **SKOS vocabulary sources** — the `.rdf` / `.ttl` / `.xml` originals behind
  `web/.../thesauri/theme/` (`TopicCategorySKOS`, `resourceTypeSKOS`, `serviceTypeSKOS`,
  `acquisitionCodeSKOS`) live on the `main` and `geonetwork` branches of `dde-metadata` — **not** on
  its checked-out `GeoNetworkConfiguration` branch. `git ls-tree --name-only main` there before
  concluding a file is missing.

Each of those directories has its own `CLAUDE.md` with the details.

## Documentation

- `README.md` — Project overview, DDE editor view, build/deploy instructions
- `agents.md` — CDIF harvester architecture, field mappings, DDE editor customizations, configuration
