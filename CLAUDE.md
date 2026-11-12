# CLAUDE.md — Project Instructions for Claude Code

## Project Overview

This is **GeoNetwork-DDE**, a fork of GeoNetwork opensource (v4.4.9) customized for the Deep-time Digital Earth (DDE) programme and extended with a CDIF sitemap harvester. The active development branch is `DDEconfig`.

**The normative repository is the DDE GitLab**, decided 2026-11-12:

| Remote | URL | Role |
|---|---|---|
| `origin` | `code.axiomearth.ai/Steve_Geonetwork/dde-geonetwork2026` | **Normative.** `DDEconfig` tracks it. Push here. |
| `github` | `github.com/usgin/geonetwork-DDE` | Mirror. Push deliberately to keep it current; it is not the source of truth. |
| `upstream` | `github.com/geonetwork/core-geonetwork` | GeoNetwork opensource, for merging releases. |

One repository is normative on purpose. The previous arrangement — a GitLab that went offline, a GitHub mirror, and an archived fork nobody could push to — cost real work to untangle, so do not let the two drift into parallel primaries. Two consequences to keep in mind: the GitHub Actions workflows do not run from GitLab, so CI there is manual or needs a `.gitlab-ci.yml`; and anything that still says "clone from GitHub" is now stale.

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
- **Upstream drift**, verified 2026-11-12. The fork sits on **4.4.9** (tagged 2025-10-06): that tag is an ancestor of `DDEconfig` and **4.4.10 is not merged**. The newest upstream release is still **4.4.12** (2026-07-08) — there is no 4.4.13 and no newer release line — so the gap is three patch releases and **224 upstream commits** between `4.4.9..4.4.12`. `upstream/main` is active well past that (tip 2026-11-09), so main carries unreleased work too; rebase onto the **tag**, not main, unless you want that.
  Tags 4.4.10–4.4.12 are now fetched locally, so `git log 4.4.9..4.4.12` works offline. Re-run `git fetch upstream --tags` before trusting the figures above. That fetch warns `Could not access submodule 'plugins/datahub-integration/geonetwork-ui'` — expected, and harmless unless you build that plugin.
- DDE additions are **additive** — upstream functionality is preserved alongside DDE views/converters.
- Schema plugin files follow GeoNetwork's standard plugin directory layout.

## Related repositories (DDE source material)

The DDE half of this fork originated in two repos at `C:\GithubC\DDE`, which are archival but remain
**authoritative for the DDE standard itself**. They were hosted on `opencode.deep-time.org`; that
GitLab is now offline (connections refused, while `deep-time.org` and `ddeworld.org` are up), so both
were mirrored to `usgin/dde-metadata` and `usgin/dde-medata` on 2026-08-26, along with the 2024 fork
`usgin/DDEcore-geonetwork`. Nothing below is duplicated in this repo — go there for it:

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

## The 2024 deployment, and what survives of it

The pre-CDIF DDE catalogue ran on Alibaba Cloud against **external** PostgreSQL and Elasticsearch
instances provisioned on the DDE side. USGIN has never had access to those, so the catalogue's
records, users, permissions and settings are not held here and cannot be exported from here. In
2026-10 the DDE programme asked for backups to migrate to another cloud server.

**The handover package is in `deploy/`** (PR #2, merged 2026-11) — read it before anything here:

- `deploy/HANDOVER.md` — what can and cannot be handed over, what the migration team must export
  from the running server, versions, and the restore sequence
- `deploy/README.md` — step-by-step redeployment: build the war, Elasticsearch and PostgreSQL,
  Tomcat, then the DDE features
- `deploy/harvest-records-2024/` — the 12 seed records
- `deploy/data-2024/` — the scrubbed slice of the deployed data directory: record attachments,
  harvester and node logos, map viewer config

This section carries only what those files do not: where the originals still live, and the facts
that are easy to get wrong.

**Use this fork, not `usgin/DDEcore-geonetwork`.** The 2024-era fork is frozen on a 4.4.4 *snapshot*
from April 2024 and gets no backports. This fork is a strict superset of its DDE work — same 21
DDE-named plugin files, same `ddeview`, same `fromDDE` converters, and 12 thesaurus files against its
4. The CDIF harvester this fork adds is a harvester *type* nobody has to configure, so it cannot
affect a catalogue that does not use it. Treat the 2024 fork as archaeology: reproducing the exact
deployed build, or checking what the old code did.

### What is NOT in the repo, and where it is

| Item | Where | Why not committed |
|---|---|---|
| The deployed war | `C:\apache-tomcat-9.0.85\webapps\geonetwork.war` | 285,820,217 bytes, 2024-04-10 — the binary that actually ran, and **the only copy**: its git-LFS original died with the `opencode.deep-time.org` GitLab. Over GitHub's 100 MB file limit, so it needs LFS or a release asset. Rebuild from source instead where possible. |
| Full deployed data directory | `…\webapps\geonetwork\WEB-INF\data` | Holds `config.properties` with database and Elasticsearch credentials, and user records with emails and password hashes. **Never commit it.** `deploy/data-2024/` is the scrubbed subset. |
| Harvester run logs | `C:\apache-tomcat-9.0.85\bin\harvester_*.log` | 30 files, 2024-02-09 → 2024-04-02; the source of the configuration below. |
| Harvest source directory | `C:\tmp\forHarvest` | The originals; `deploy/harvest-records-2024/` is the committed copy. |
| The catalogue database | Alibaba Cloud PostgreSQL | No USGIN access. Records, users, permissions, settings and **harvester definitions** are all in it. |

That deployment had **no embedded catalogue database** — the only `.mv.db` under it is a wro4j
web-resource cache — which is the on-disk confirmation that the catalogue DB was the external
PostgreSQL. Note `C:\Users\smrTu\gn.mv.db` (modified 2026-02-28) is a *different* instance, almost
certainly this fork's own dev run; it is not the 2024 deployment and holds none of its data.

### Harvest configuration, recovered from the logs

Harvester definitions are **database rows**, not files: GeoNetwork moved them into the settings tree
at 2.11 (`WEB-INF/classes/setup/sql/migrate/v2110/MoveHarvesterSettings.java` is in the war), and the
logs show paths like `harvesting/id:277/info/lastRun`. The war carries only harvester *machinery* —
78 entries of admin UI templates and XSLTs, one file per harvester type — so the configuration is
never in it. The logs preserved it anyway:

| Setting | Value |
|---|---|
| Harvesters | Two, both `LocalFilesystemHarvester`: `local DDE` and `clone: local DDE` |
| Source directory | `C:\tmp\forHarvest`, `recurse = true` |
| Owner | `ownerId = 1` |
| Runs | 29 logged, 2024-02-09 → 2024-04-02 |

**There is no remote harvest endpoint to recover** — no CSW, OAI-PMH or sitemap, and no credentials.
The catalogue was loaded from a folder of files on a workstation, so recreating the harvester is a
few fields in the admin console.

### The seed records

Nine records were harvested. Eight source files survive in `C:\tmp\forHarvest`;
`ddeTransformTest-DDE.xml` does not, but it is in `usgin/dde-metadata` under `ExampleXML/`. Three
further files there (`DDEDatasetTemplate.xml`, `DDEImageTemplate.xml`, `DDEServiceTemplate.xml`) were
never harvested — they are editor templates, and GeoNetwork loads templates as *template* records, so
importing them needs that flag set afterwards.

**These files are DDE-schema, not ISO 19115-3.** Root element `MD_Metadata` in namespace
`https://www.ddeworld.org/resource/standards/dde/ds01/metadata/1.0`, converted on import by the
`fromDDE` XSLTs in this plugin. A stock GeoNetwork rejects them — re-harvesting requires this fork.
The records are as of early 2024; anything created or edited in the catalogue UI afterwards exists
only in that PostgreSQL, and identifiers assigned on a fresh import will differ from the originals.

### Not recoverable, and what to do instead

- **PostgreSQL dump** — only obtainable from the Alibaba instance, by whoever administers it:
  `pg_dump -Fc`. One dump carries records, users, groups, permissions and settings together.
- **The server's data directory** — attachments and browse graphics are files, not rows, so a
  database dump alone loses them.
- **Elasticsearch snapshot** — never taken, and **not needed**: GeoNetwork 4 treats the index as
  derived, so point a restored instance at a fresh Elasticsearch and reindex from the admin console.

### Credentials

Treat every credential from that deployment as compromised. The two July 2024 deployment notes in
`usgin/dde-metadata` contain Elasticsearch passwords in plain text and that repository is **public**.
Rotate anything still live rather than carrying it to a new server.

**This repository is public too.** Checked 2026-11-12: `deploy/` contains no `.properties` file, the
password mentions in `HANDOVER.md` and `README.md` are placeholders with no literal values, and
neither of the two Elasticsearch passwords from the 2024 notes appears anywhere in the repo. Re-run
that check before committing anything else out of a deployed instance — a GeoNetwork data directory
is full of material that must not be published.

## Documentation

- `README.md` — Project overview, DDE editor view, build/deploy instructions
- `agents.md` — CDIF harvester architecture, field mappings, DDE editor customizations, configuration
