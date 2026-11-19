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
milliseconds. Build with it. The 19 MB `WEB-INF/prebuilt/wro4j-cache.mv.db` is adopted and copied
to `<geonetwork.dir>/data/resources/htmlcache/wro4j-cache.mv.db`.

**The adoption is lazy, and neither the file's size, its hash nor its timestamp means what it
looks like.** Established 2026-11-19 by reading `GeonetworkWrojManagerFactory` after a deploy was
wrongly declared broken on all three. Three traps, in the order they mislead:

- **It is copied on the first wro4j request, not at startup.** `newCacheStrategy()` runs when
  wro4j first builds its manager. Read the data directory before anything has asked for a bundle
  and you are looking at the file the *previous* container left at shutdown.
- **It cannot be fingerprinted by hash.** `DiskbackedCache.java:87,103` opens that same path as an
  H2 database (`jdbc:h2:<htmlCacheDir>/wro4j-cache`), so it is written the moment the catalogue
  serves anything. Comparing its md5 against the war's pristine copy always differs and proves
  nothing. Compare **sizes** instead, before and after the first bundle request: a jump to within
  one 8 KB H2 page of the war's prebuilt file is the copy happening.
- **The data directory's `git.properties` never names the running build.**
  `GeonetworkWrojManagerFactory.java:112-121` writes it only when it is *absent*, so it is frozen
  at whatever revision first created it. It is therefore useless as a deployment marker, and
  `gitVersionMatch` is false on every start after the first — meaning the prebuilt cache is
  re-copied on every start, discarding anything compiled since. Fixed here, and worth upstreaming.

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

## Three ways a build silently ships the wrong thing

All three were hit for real, and the first was hit **twice** -- recorded in
`deploy/docker/README.md` on 2026-11-16 and repeated on 2026-11-18, because a
file in `deploy/` is only read by someone who goes looking. Check these before
concluding a change "did not work".

1. **`web/target/wro4j-cache.mv.db` survives a non-clean build and is reused.**
   `wro4j:run` keys on group name, not on source content, so a leftover cache
   recompiles nothing and re-emits the previous `gn_search_default.js` and
   `.css`. The war then carries correct raw sources and a stale bundle. On
   2026-11-18 the deployed `CatController.js:734` read `list.html` while the
   served bundle still read `grid.html`. Delete it (and `web/target/wro4j-output`)
   whenever any `.js`, `.less` or `.html` under `web-ui/` changed.

2. **The bundle URL is cache-busted with the git commit sha**
   (`/static/gn_search_default.js?v=<sha>`). Rebuilding the *same* commit serves
   browsers their cached copy from the identical URL, so a verified-correct war
   can still look unchanged. Harmless in production, where every deploy is a new
   commit; while iterating, force the cache
   (`fetch(url, {cache:'reload'})` works when Ctrl+Shift+R does not).

3. **The build formats web-ui sources with `printWidth 90`**
   (`prettier-maven-plugin`, `web-ui/pom.xml:81`), which overrides the `80` in
   `web-ui/.prettierrc.json`. Running bare `npx prettier` therefore reflows
   unrelated code -- 178 lines of `CatController.js` on 2026-11-18. Let the build
   format, then commit what it produced; a build leaves those files modified.

The shared shape: the step reports success, the artifact is valid, and the
change is absent. Verify the *artifact*, not the build log -- `unzip -p` the war
and grep, or grep the cache file, before deploying.

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
- **Elasticsearch mappings**: `records.json` and `features.json` live in **different trees**, which
  is easy to get wrong. `records.json` is tracked at
  `web/src/main/webResources/WEB-INF/data/config/index/records.json`; the copy at
  `web/src/main/webapp/.../records.json` is a build artifact, gitignored at `.gitignore:67`, so an
  edit there is lost on the next clean build. `features.json` is the other way round: tracked at
  `web/src/main/webapp/WEB-INF/data/config/index/features.json`, with no webResources copy.
- **The index mapping grows with the data, and has a ceiling.** `records.json` declares 87
  properties and 22 dynamic templates whose wildcards (`th_*`, `cl_*`, `*Object`, `conformTo_*`
  and the rest) mint a new field per thesaurus, codelist and declared locale. Measured 2026-11-17
  on the deployed catalogue at ~20,000 records: **3,163 field entries across 354 top-level names**,
  of which 268 were created dynamically. `mapping.total_fields.limit` was raised 4000 -> **8000**
  that day, both here and live on the server, because the harvest was at ~3,150 with 10,000
  records still to come and exceeding the limit stops indexing outright.
  **56% of those fields are language variants, and they are orphans.** 1,787 entries carry a
  `.lang<xxx>` suffix across 16 languages, in a suspiciously regular 116-per-language pattern
  (Armenian, Azerbaijani, Georgian, Danish, Romanian on an Australian bedrock catalogue). The
  languages come from each record's own `mdb:defaultLocale`/`mdb:otherLocale`
  (`index-fields/index.xsl:149`), not from a setting, and **no document currently uses them** -- an
  `exists` query returns zero. Mappings are append-only, so records that declared locales they had
  no content for left those fields behind permanently. A delete-and-reindex is what reclaims them;
  a plain reindex does not.

## Key Technical Details

- **Metadata schema**: ISO 19115-3:2018 is the primary schema. Dublin Core and ISO 19110 are
  commented out in **three** places, not one -- the two `<module>` entries in `schemas/pom.xml`,
  and both the `<dependency>` block and the unpack `<artifactItem>` in `web/pom.xml` (around
  `:612` and `:1139`) -- so the war ships neither. Copies found in a *deployed* data directory are
  leftovers from an earlier deployment that GeoNetwork still loads, because plugins are read from
  the data directory rather than the war, and nothing rebuilds them. Re-enabling means
  uncommenting all three. Two things that are easy to get wrong about why you might want them
  (checked 2026-11-18):
  - **CSW does not need `dublin-core`.** `csw-record` owns the `csw:Record` schema and *is* in the
    build, and each ISO plugin emits `csw:Record` from its own
    `present/csw/csw-{brief,summary,full}.xsl`. Neither ISO plugin's `schema-conversions.xml`
    mentions `dublin-core`; they declare only `oai_dc`. In Java, `"dublin-core"` appears solely in
    three test fixtures. The plugin is for *storing* native Dublin Core records.
  - **`iso19110` is the wrong gfc for CDIF data description.** Its autodetect roots are
    `gfc:FC_FeatureType` and `gfc:FC_FeatureCatalogue` in the ISO 19139-era namespace
    `http://www.isotc211.org/2005/gfc`. The iso19115-3.2018 plugin already bundles the 2018-era
    `gfc` 1.1 and `fcc` 1.0 under `schema/standards.iso.org/19110/` (`oasis-catalog.xml:89-93`),
    but declares **no** gfc autodetect root -- so it validates feature-catalogue content inside a
    record (`mdb:contentInfo`) while being unable to hold a standalone feature catalogue. Adding
    `gfc:FC_FeatureCatalogue` to that plugin's roots is the closer fit than re-enabling a module
    that introduces a second, older namespace for the same concept.
- **XSLT version**: All stylesheets use XSLT 2.0 (Saxon processor).
- **CDIF conversion (inbound)**: `fromJsonCdif.xsl` produces XSD-valid ISO 19115-3 output. The XSLT output includes `xsi:schemaLocation` with HTTP URLs for all concrete schemas (mdb, mco, mrc, mrd, mrl, mdq, gfc, fcc). GeoNetwork's `oasis-catalog.xml` resolves these to bundled local schemas at runtime.
- **CDIF conversion (outbound)**: `iso19115-3-to-cdif.xsl` converts ISO 19115-3 back to CDIF JSON-LD. Accessible via `/srv/api/records/{uuid}/formatters/cdif`. Roundtrip validated: 120/121 ADA records pass.
- **JSON-LD framing caveat**: Java `jsonld-java` drops complex fields (`schema:creator` with `@list`,
  `schema:distribution`, `schema:funding`, `schema:contributor`) during framing.
  `recoverDroppedFields()` merges them back from the original input. It lives in
  `simpleurl/CdifJsonPreparer.java`, not in `Harvester.java`, since 5b560019c1 — both the SimpleUrl
  and the Directory harvester call it.
- **CDIF JSON can only be ingested by a harvester, never by Contribute > Import.** Established
  2026-11-19 by reading the code, after the deployed catalogue was thought ready for a one-off CDIF
  import. `MetadataInsertDeleteApi.java:677` parses every non-MEF upload with `Xml.loadStream`, and
  `loadRecord` takes the resulting JDOM `Element`; `transformWith` is then applied by
  `Xml.transform(xmlElement, xslFile)` at `:917`. So the upload is parsed as XML **before** the
  transform is reachable, and a `.json` file dies at the parse with `fromJsonCdif.xsl` never
  consulted. This is **not** the Windows `InvalidPathException` bug recorded under the 2024 seed
  records — that one concerns the `transformWith` identifier for DDE *XML* files, which import
  fine on Linux. Two unrelated obstacles.

  Getting from CDIF to ISO is five steps and the XSLT is only the last, which is why
  the stylesheet cannot be made to cover it: frame against `cdif-frame.jsonld`, strip the nulls
  framing introduces, recover the dropped fields (all three in `CdifJsonPreparer`), synthesise XML
  with `org.json.XML.toString(json, "record")` plus `@`-stripping, colon-to-underscore and an
  injected `<uuid>` (in each harvester), and only then `fromJsonCdif.xsl`. Framing is the step that
  is easy to underrate: JSON-LD has several equivalent serialisations, each of which becomes
  different XML at the synthesis step, and the stylesheet is written against the framed shape alone.

  There is therefore no single-record CDIF import — even one file goes through a harvester. Making
  Import accept CDIF would mean detecting JSON on upload and running the preparer before parsing,
  which is a feature rather than a fix.
- **A containerised Directory harvester can only see the data volume.** `docker-compose.yml` mounts
  exactly one volume into the catalogue, `gn_data:/var/lib/geonetwork_data`, so a directory under
  `/root` harvests **zero files and reports no error** — the path simply is not there. Put records
  inside the volume (`docker compose cp <src> geonetwork:/var/lib/geonetwork_data/<dir>/`) rather
  than adding a bind mount.
- **Dev healthcheck**: `DashboardAppHealthCheck` in `config-service-monitoring.xml` is disabled — it blocks the admin UI when Kibana isn't running.
- **Schema validation**: For local validation in Oxygen XML Editor, use `oxygen-catalog.xml` (repo root) which has absolute `file:///` paths. The GeoNetwork `oasis-catalog.xml` uses relative paths that work in Java but not in standalone Oxygen on Windows.
- **Editor views**: The `ddeview` in config-editor.xml uses GeoNetwork's XML-based view definition system with tabs, sections, fields, actions, and thesaurus pickers.
- **Geologic time**: The extent tab supports geologic age via `gml:TimeInstant` with `gml:timePosition frame="Ma before present"`.
- **DDE codelists**: DDE-specific codelist URLs use `https://www.ddeworld.org/resource/codelist/...`.
- **Build**: Maven multi-module project. Key modules: `core`, `harvesters`, `services`, `schemas`, `web`, `web-ui`.

## Admin login, and how to reset it

**Login checks only the salted hash.** `GeonetworkAuthenticationProvider.java:71` calls
`encoder.matches`, and the encoder is a Spring `StandardPasswordEncoder` constructed with
`${passwordSalt}` (`web/src/main/webapp/WEB-INF/config-security/config-security-core.xml:279`).
That value is the literal `passwordSalt=secret-hash-salt=`, committed at
`web/src/main/webapp/WEB-INF/config-security/config-security.properties:29`, so it is identical in
every build and a salt mismatch is **never** the explanation for a failed login -- check it once
to rule it out, then stop pursuing it. The legacy SHA-1 paths in `PasswordUtil`
(`unsaltedScramble`, `oldScramble`) are reachable only through `matchesAnyHash`, whose own javadoc
says it is not for logging in, so a hand-written SHA-1 hash in `users.password` will not
authenticate.

A `StandardPasswordEncoder` hash is exactly **80 hex characters** -- an 8-byte salt plus a 32-byte
SHA-256 digest, hex-encoded. A `users.password` of any other length was not written by the
encoder.

**Diagnose before resetting.** `users.lastlogindate` updates only on a *successful* login, so a
stale value means the password is being rejected outright rather than a session failing afterwards.
`authtype` empty means local authentication, not LDAP or CAS. A `security` column containing
`UPDATE_HASH_REQUIRED` changes how the stored hash is checked. Most useful of all: **one working
account proves the database, salt, encoder and filter chain are all intact.** On 2026-11-18
`srichard` authenticated while `admin` did not, which localised the fault to a single row and was
the evidence against an intrusion -- an attacker changing the admin password has no reason to
leave another account working, and no accounts had been added.

**Resetting it on the deployed server.** The runtime image is `tomcat:9.0.85-jdk11-temurin`, a
full JDK, and the war ships `spring-security-core`, so the container generates its own hash and
the password never leaves that shell. Write a four-line `Pw.java` that reads the password from
`$PW` and either prints `new StandardPasswordEncoder("secret-hash-salt=").encode(p)` or, given an
argument, `matches(p, args[0])`; compile it with
`javac -cp "/usr/local/tomcat/webapps/geonetwork/WEB-INF/lib/*"`; then one `read -rsp` feeding the
same `$PW` into generate -> `update users set password=... where username='admin'` -> verify.

Taking the password from an environment variable rather than from two separate hidden prompts is
the whole point. The first attempt failed because `System.console().readPassword` echoes nothing,
so a typo is invisible and still yields a well-formed 80-character hash -- for the wrong string.
A `matches` check against the hash actually stored is what distinguishes that from an
authentication-chain problem; a `401` from the API cannot.

Two smaller traps: `java /tmp/Pw.java` single-file source mode does **not** work in that container
(`Could not find or load main class .tmp.Pw.java`), so compile with `javac` and run the class. And
`curl` against the API needs `-H "Accept: application/json"` -- see the API note under Build & Run.

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
| Second copy of both archives | `E:\Toolkit\Backup\geonetwork-2024-deployment\` since 2026-11-18, with the archive's own `README.md` alongside | The 2024 war and data directory cannot be regenerated, and until this copy existed every copy was on `C:`. Checksums verified equal on both drives: war `21c1ee57c2e5c0a5...`, expanded tree `c6a2992737bbf8e8...`. **Private storage only** -- it holds a literal `es.password` and user password hashes. |
| ~~Both of the above, under Tomcat~~ | **deleted 2026-11-18** from `C:\apache-tomcat-9.0.85\webapps-2024-aside\`, freeing 0.63 GB | They had been set aside on 2026-11-14 so Tomcat would not auto-deploy the 2024 app (it reaches for the dead Alibaba hosts) and so the documented `/geonetwork` context was free. **Do not put the 2024 app back under `webapps/`** -- this supersedes the earlier instruction to restore it once the 4.4.9-0 test deployment finished. Nothing was preserved by keeping it there: the war was byte-identical to the archive and the expanded tree is the `.tar.gz`, both checked before deleting. Restoring it would only make Tomcat auto-deploy an app that cannot reach its database on every start, take the `/geonetwork` context from the current build, and put `config.properties` credentials and user password hashes back under an HTTP server. Reproducing the 2024 build is archaeology: do it from the archive, outside `webapps/`. |
| Harvester run logs | `C:\apache-tomcat-9.0.85\bin\harvester_*.log`, archived 2026-11-18 to `E:\Toolkit\Backup\geonetwork-2024-deployment\harvester-logs-2024.tar.gz` | 30 files, 2024-02-09 → 2024-04-02; the source of the configuration below. The archive holds all 30 entries in 38,762,542 bytes — about 18:1, since `harvester_default.log` alone is 715 MB — decompresses cleanly, sha256 `9744d0213e199782…`. |
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
| Harvesters | Two by name, **three by id**: `local DDE` and `clone: local DDE`, both `LocalFilesystemHarvester`, but ids 100, 277 and 313 all appear in `harvesting/id:*/options/status`. One was deleted and recreated, or a third existed and never ran under its own log. |
| Source directory | `C:\tmp\forHarvest`, `recurse = true` |
| Owner | `ownerId = 1` |
| Runs | 29 logged, 2024-02-09 → 2024-04-02 |

**There is no remote harvest endpoint to recover** — no CSW, OAI-PMH or sitemap, and no
credentials. The catalogue was loaded from a folder of files on a workstation, so recreating the
harvester is a few fields in the admin console.

Re-verified 2026-11-16 across all 30 logs, including the 715 MB `harvester_default.log`, because
the three candidate protocols all *appear* in them and none means what it looks like:

| candidate | hits | what it actually is |
|---|---|---|
| `csw` | 8,424 | the **`csw-record` schema plugin** loading at startup, `<csw:BriefRecord xmlns:csw=…>` namespace declarations |
| `sitemap` | 8 | `metadata/url/sitemapLinkUrl` read at startup, **value empty** — GeoNetwork's own setting for *publishing* a sitemap |
| `GetRecords` | 7 | `[geonetwork.csw] - GetRecords getElementNames` — the catalogue **serving** CSW to someone else |

OAI-PMH, WebDAV, Z39.50, THREDDS, WFS and SimpleUrl appear **zero** times. Every harvest is a
`[geonetwork.harvester] - reading file: C:\tmp\forHarvest\…` line in the `filesystem` logs.

**The 2024 catalogue had at least one external CSW consumer.** Those seven `GetRecords` entries
are inbound: something was querying `/srv/eng/csw` on 2024-02-11, 2024-02-12 and 2024-04-02.
Nothing else records that the catalogue was being consumed by a client, and it is worth knowing
before assuming a redeployment has no downstream users.

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
badFormat, 0 doesNotValidate**, producing 18 distinct records, every one indexed as
`iso19115-3.2018`. The 18 was not deduplication of copies: three files collided on two identifiers and were silently discarded. Fixed 2026-11-16 in 71ed4ac004, so a harvest of the current files should now give 21. A dataset and its service shared
`c98705ae-058a-43fb-85a2-7b5209d9a4b3`, and the three `DDEInstance*` files all carried the
placeholder `metadataIdentifier-IDCode0`. `fromDDE-any` really does handle "any" — DDE 1.0, DDE instances, DDE
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
