# CLAUDE.md — Project Instructions for Claude Code

## Project Overview

This is **GeoNetwork-DDE**, a fork of GeoNetwork opensource (v4.4.9) customized for the Deep-time Digital Earth (DDE) programme and extended with a CDIF sitemap harvester. The active development branch is `DDEconfig`.

**The normative repository is the DDE GitLab**, decided 2026-11-12:

| Remote | URL | Role |
|---|---|---|
| `origin` | `code.axiomearth.ai/Steve_Geonetwork/dde-geonetwork2026` | **Normative.** `DDEconfig` tracks it. Push here. Holds `DDEconfig` and `main`. |
| `github` | `github.com/usgin/geonetwork-DDE` | Mirror. Push deliberately to keep it current; it is not the source of truth. |
| `upstream` | `github.com/geonetwork/core-geonetwork` | GeoNetwork opensource, for merging releases. |

One repository is normative on purpose. The previous arrangement — a GitLab that went offline, a GitHub mirror, and an archived fork nobody could push to — cost real work to untangle, so do not let the two drift into parallel primaries. Two consequences to keep in mind: the GitHub Actions workflows do not run from GitLab, so CI there is manual or needs a `.gitlab-ci.yml`; and anything that still says "clone from GitHub" is now stale.

## Build & Run

```bash
# Full build (Java 11, Maven 3.8.3+)
mvn clean install -DskipTests                        # dev

# Start Elasticsearch (8.14.3 — see below)
cd es && docker compose up -d elasticsearch

# Run GeoNetwork (Jetty, port 8080)
cd web && mvn jetty:run -Penv-dev
```

**Elasticsearch is 8.14.3 — settled, not a preference.** The upstream manual
(`docs/manual/docs/install-guide/installing-index.md`) marks 8.14.3 *recommended* and **8.14.x the
minimum**; `pom.xml` pins `es.version` to it, and that drives both the bundled Java client and the
`elasticsearch-maven-plugin` used by tests. `es/docker-compose.yml` matches. The stale
`es/elasticsearch-7.15.1` and `-7.17.15` trees were deleted 2026-11-14 (gitignored, nothing tracked);
`es/elasticsearch-8.11.3` remains but is **below the stated minimum** — do not measure anything
against it. `docker-compose.yml`'s obsolete `version:` key was removed the same day, which silences
a Compose v2 warning.

Hot-reload schema/UI changes: `cd web && mvn process-resources -DschemasCopy=true`

`schemasCopy` is a **property**, not a profile id (`web/pom.xml:1109` and `:1175` switch on
`-DschemasCopy=true` / `!true`). `-PschemasCopy`, documented here until 2026-11-13, names a
profile that does not exist: Maven ignores it, reports `BUILD SUCCESS` in a few seconds, and
copies nothing, so edits under `schemas/` never reach the running catalogue. The deployed copy
lives at `web/src/main/webapp/WEB-INF/data/config/schema_plugins/` and is gitignored
(`.gitignore:68`) — a build artifact, not a second source. GeoNetwork caches formatters, so
restart Jetty after copying.

**Web asset serving on Tomcat is fast, and the prebuild cache is what makes it fast.** Measured
2026-11-14 on **Tomcat 9.0.85** with the 4.4.9-0 war — the configuration that matters, which until
then had never been measured:

| scenario | `gn_search_default.css` | `gn_search_default.js` |
|---|---|---|
| prebuild cache present, first ever request | 0.0046 s | 0.0090 s |
| no cache at all, cold | 16.4 s | 429.5 s |
| after that cold compile, warm | 0.0067 s | 0.0153 s |

So `-Dprebuild-cache=true` earns its keep: it turns a 16 s + 430 s first-request cliff into
milliseconds. Build with it. The 19 MB `WEB-INF/prebuilt/wro4j-cache.mv.db` is adopted on first
start and copied to `<geonetwork.dir>/data/resources/htmlcache/wro4j-cache.mv.db`.

**Three earlier conclusions recorded here were wrong**, all from measuring `mvn jetty:run` rather
than a war on Tomcat:

- "The CSS never caches, so every page load costs ~8 s" — a `jetty:run` artifact. On Tomcat the CSS
  caches like everything else and stays near 5 ms across restarts.
- "The prebuild cache did not speed anything up" — `jetty:run` only, and the opposite of what
  Tomcat shows.
- `debug=true` is **not** the cause of anything measured. The war tested had `debug=true` deployed
  and still served in milliseconds.

Still true, and still worth fixing as hygiene: `wro.debug` defaults to **true** (`pom.xml`, and
again in the `env-dev` profile) and **no profile sets it false**, so every war ships with wro4j in
debug mode unless you pass `-Dwro.debug=false`. Separately, `wroSources` bakes
`${project.build.directory}/webapp` — an absolute path on the *build* machine — into the war, so it
names a directory that will not exist on a server.

`deploy/README.md` Step 1 has the Windows two-invocation prebuild recipe and the three dependency
problems (retired `oss.sonatype.org`, stale JDK truststore, `.lastUpdated` markers) that block the
prebuild here.

**JDK: use Temurin 11.0.25 or later, and the build now enforces it.** `pom.xml`'s
maven-enforcer-plugin carries a `requireJavaVersion` rule of `[11.0.25,12)`, added 2026-11-14 and
tested three ways: Temurin 11.0.33 passes, JDK 11.0.2 fails with an explanatory message, JDK 21
fails on the upper bound. Before that rule the build checked only the *Maven* version, so
`<source>/<target>11` — which merely sets the bytecode level — let an ancient JDK 11 through
silently, and every failure it caused pointed somewhere else.

Temurin **11.0.33+10** is installed at `C:\GithubC\jdk\jdk-11.0.33+10` (zip, no installer, no
system-wide change). Point `JAVA_HOME` there.

`C:\Program Files\Java\jdk-11.0.2` is **not** usable — this supersedes the earlier instruction to
leave it alone. It carries **93 CA roots against 118** in 11.0.33, and its TLS 1.3 session
resumption fails with `No PSK available. Unable to resume.` That is a **runtime** fault, not only a
build one: on the deployed catalogue it surfaced as `ImageIO.read(URL)` throwing inside the Spring
Security filter chain. It was observed once, on one outbound fetch — it did **not** break the API,
and `-Djdk.tls.client.protocols=TLSv1.2` made no observable difference, so do not record it as a
remedy.

**The API breakage seen alongside it was not a breakage at all.** `/srv/api/*` returning HTTP 500
`ServiceNotFoundEx` was a missing `Accept` header: the API negotiates on content type and rejects
`Accept: */*`, which is what `curl` sends by default. Identical requests give 500 without
`-H "Accept: application/json"` and 200 with it, and the 500 is logged nowhere. Three wrong
hypotheses were pursued before the two curl commands were compared — the JDK's TLS bug, a stale H2
database, and slow servlet init. None was the cause. Compare your own client invocations before
theorising about the server. (The "152 roots in Temurin 11.0.25" figure once recorded in
`deploy/README.md` does not reproduce; counted the same way on both JDKs it is 93 against 118.)

Still true: the **Machine** scope sets `JAVA_HOME` to `C:\Program Files\OpenJDK\jdk-25`, so a
cleared or missing **User**-scope value silently selects JDK 25 and the build fails with compile
errors that look unrelated. The enforcer rule now catches that case too.

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
- Branch `main` is **not** a working upstream-tracking branch, despite the name. Its tip is
  `1a588c24d9`, dated **2024-03-08**: 948 commits behind `upstream/main` and 5 ahead of it, and
  those 5 are merge commits plus a comment-out/revert pair on the fork's GitHub Actions run
  conditions — no DDE work and no release content. It is also not an ancestor of tag `4.4.9`.
  Pushed to GitLab 2026-11-13 so the normative remote holds a complete copy, but do not treat it
  as a merge base without fast-forwarding it from `upstream` first.
- Merging an upstream release therefore keys off the `upstream` remote and its tags, not off
  `main`. GitLab has no `upstream` remote and no mirroring configured, so that work happens in a
  local clone carrying all three remotes and is then pushed to GitLab.
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
| The deployed war | archived at `C:\GithubC\geonetwork\war-archive\geonetwork-2024-04-10-deployed.war` | 285,820,217 bytes, 2024-04-10 — the binary that actually ran. Was the **only copy** (its git-LFS original died with the `opencode.deep-time.org` GitLab) until backed up 2026-11-14, verified byte-identical, sha256 `21c1ee57c2e5c0a5…`. **Do not publish it**: `WEB-INF/config.properties` holds a literal `es.password`, not a `${…}` placeholder, so it must never become a release asset or LFS object in a public repo. Rebuild from source instead where possible. |
| Full deployed data directory | archived inside `C:\GithubC\geonetwork\war-archive\webapps-geonetwork-expanded-2024-04-10.tar.gz` | 272 MB from 383 MB, 6,951 entries, of which **1,616 are under `WEB-INF/data/`** — the deployed data directory, which had no other copy. Holds `config.properties` credentials and user records with emails and password hashes. **Never commit it, and private storage only.** `deploy/data-2024/` is the scrubbed subset. |
| Both of the above, in place | moved to `C:\apache-tomcat-9.0.85\webapps-2024-aside\` on 2026-11-14 | Set aside so Tomcat would not auto-deploy the 2024 app (it reaches for the dead Alibaba hosts) during the wro4j measurement, and so the documented `/geonetwork` context was free. **Restore them to `webapps/` when the 4.4.9-0 test deployment is finished.** |
| Harvester run logs | `C:\apache-tomcat-9.0.85\bin\harvester_*.log` | 30 files, 2024-02-09 → 2024-04-02; the source of the configuration below. |
| Harvest source directory | `E:\Toolkit\Backup\EMERALD\c\tmp\forHarvest` (21 files) | **The authoritative copy.** The live `C:\tmp\forHarvest` is down to 11 files, having lost 10. `deploy/harvest-records-2024/` now mirrors all 21, so the repo is a complete copy — but that external drive is the only other one. |
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

**The 2024 harvest source was 21 files, not nine, and it was mixed-schema.** Established 2026-11-14
from the backup at `E:\Toolkit\Backup\EMERALD\c\tmp\forHarvest`, which holds all 21. The live
`C:\tmp\forHarvest` has since **lost 10 of them**, so that backup is now the only surviving copy of
those — including the four ISO 19139 records (`KismetQuad`, `freeAirAnomalies`, `grantsPassGravity`,
`homerNYQuad`), three `DDEInstance*` examples, `ArizonaLithostratigraphyServiceDDE.xml` and an
`EIPExample_g01065_-DDE.xml` variant.

`deploy/harvest-records-2024/` now mirrors all 21 (it held 12). The pre-existing 11 are
content-identical to the backup, differing only in line endings.

**One of those 12 was the wrong revision and could not import.** The committed
`ddeTransformTest-DDE.xml` was the copy recovered from `usgin/dde-metadata/ExampleXML/`, in
namespace `…/resource/metadata/0.4`; the harvested original is `…/resource/standards/dde/ds01/metadata/1.0`.
`fromDDE-any` does not handle 0.4, so it harvested as `unknownSchema`. Replaced with the 1.0
original — prefer the EMERALD backup over the dde-metadata examples for anything claiming to be a
2024 artifact.

Three of the 21 (`DDEDatasetTemplate.xml`, `DDEImageTemplate.xml`, `DDEServiceTemplate.xml`) are
editor templates. GeoNetwork loads templates as *template* records, so importing them as metadata
(`recordType=n`) gives ordinary records and the flag has to be set afterwards.

**Verified end to end on 2026-11-14**: a `LocalFilesystemHarvester` over all 21 with
`importxslt = schema:iso19115-3.2018:convert/fromDDE-any` gave **21 total, 0 unknownSchema, 0
badFormat, 0 doesNotValidate**, producing 18 distinct records (some files share a uuid), every one
indexed as `iso19115-3.2018`. `fromDDE-any` really does handle "any" — DDE 1.0, DDE instances, DDE
templates *and* ISO 19139 in a single pass, which is how one harvester loaded a mixed folder in 2024.
`formatters/dde` and `formatters/cdif` both return valid output for the harvested Arizona record.

**These files are DDE-schema, not ISO 19115-3.** Root element `MD_Metadata` in namespace
`https://www.ddeworld.org/resource/standards/dde/ds01/metadata/1.0`, converted on import by the
`fromDDE` XSLTs in this plugin. A stock GeoNetwork rejects them — re-harvesting requires this fork.

**The conversion's identifier is `schema:iso19115-3.2018:convert/fromDDE-any`**, not the bare name;
`GET /srv/api/site/info/transforms` lists all 29 the catalogue offers. The bare name resolves
against `webapp/xsl/conversion/import/` (which holds only `Add-gmd-prefix` and `WxS_to_INSPIRE`) and
404s.

**On Windows, Contribute > Import cannot apply it at all** — an upstream bug, found 2026-11-14.
`MetadataInsertDeleteApi.java:913` calls `FilePathChecker.verify(transformWith)` on the whole
identifier before `getXsltConversion` splits it on `:`, and `verify` ends in `Paths.get(...)`, which
on Windows throws `InvalidPathException: Illegal char <:> at index 6` (HTTP 400). Linux is
unaffected because `:` is a legal filename character there. **Use the Directory harvester instead**:
`LocalFsHarvesterFileVisitor.java:99` resolves the same identifier *without* that check — which is
also how the 2024 catalogue was really loaded.
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
