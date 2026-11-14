# Deploying DDE GeoNetwork (geonetwork-DDE)

As of 2026-10-22.

This folder holds everything needed to deploy the DDE catalogue:

| Path | Contents |
| --- | --- |
| `README.md` | This guide: how to build, deploy and verify |
| [HANDOVER.md](HANDOVER.md) | What exists, what is missing, and what must be exported from the old server |
| [harvest-records-2024/](harvest-records-2024/) | The complete 2024 harvest source: 21 files — DDE records, three DDE editor templates, three `DDEInstance*` examples and **four ISO 19139 records** |
| [data-2024/](data-2024/) | Record attachments (`metadata_data/`) and catalogue images (`resources/`) from the 2024 data directory |

## Overview

Build GeoNetwork 4.4.9-0 from [dde-geonetwork2026](https://code.axiomearth.ai/Steve_Geonetwork/dde-geonetwork2026/-/tree/DDEconfig) on the DDE GitLab, branch `DDEconfig`, and run it in Tomcat 9 against PostgreSQL and Elasticsearch 8.14.3. That build already contains everything DDE-specific: the `ddeview` editor, the DDE converters and formatter, the DDE SKOS thesauri and the Elasticsearch mappings. Nothing has to be installed separately.

This guide is the how. [HANDOVER.md](HANDOVER.md) is the what: which artifacts exist, what is missing, and why `DDEconfig` is the recommended starting point. Read its credentials note before you begin.

The deployment has four parts:

| Part | Role | Default port |
| --- | --- | --- |
| Tomcat 9 + `geonetwork.war` | The catalogue application and web UI | 8080 |
| PostgreSQL | System of record: metadata, users, groups, settings, harvester configs | 5432 |
| Elasticsearch 8.14.3 | Search index, rebuilt from the database at any time | 9200 |
| Data directory (`geonetwork.dir`) | Uploaded files, thumbnails, schema plugins, thesauri | n/a |

## Prerequisites

Install these on the build machine and the server (they can be the same machine).

| Component | Version | Notes |
| --- | --- | --- |
| JDK | **[Temurin 11.0.25](https://adoptium.net/temurin/archive/?version=11) or later** (not 12+) | Hard requirement, and the build now enforces it: `pom.xml`'s enforcer carries `requireJavaVersion [11.0.25,12)`. The early 11.0.x builds fail in two ways that never name the JDK — see below. Set `JAVA_HOME` explicitly and confirm with `mvn -version`. |
| Apache Maven | 3.8.3 or later | Build only. |
| Git | any recent | Build only. |
| Apache Tomcat | 9.x | Not Tomcat 10 or later: GeoNetwork 4.4 uses the `javax` servlet API. |
| PostgreSQL | 13 or later | PostGIS is optional. |
| Elasticsearch | 8.14.3 | Match this version; it is pinned in the root `pom.xml` (`es.version`). |
| Kibana | not needed | The fork disables the Kibana health check, so the admin UI works without it. |

Give Tomcat at least 2 GB of heap (`-Xmx2g`) and Elasticsearch at least 1 GB. Allow a few GB of disk for the build and the Maven cache.

### Why the JDK patch version matters

An old Java 11 is not merely untidy; it breaks the catalogue at runtime, and the
symptoms point everywhere except at the JDK. Measured on `jdk-11.0.2`:

- It carries **93 CA roots** against **118** in Temurin 11.0.33, so Maven cannot
  validate some redirect targets and reports it as "peer not authenticated".
- Its **TLS 1.3 session resumption fails** with `No PSK available. Unable to
  resume.` On a deployed catalogue this surfaced as
  `javax.imageio.IIOException: Can't get input stream from URL!` thrown inside
  the Spring Security filter chain — an outbound HTTPS fetch, nothing to do with
  the build.

`<source>11`/`<target>11` only set the bytecode level, so before the enforcer
rule an ancient JDK 11 passed the build silently. On Windows also check the
**scope** of `JAVA_HOME`: a Machine-scope value pointing at a newer JDK is used
whenever the User-scope value is missing or cleared.

## Step 1: Build the war

1. Clone the fork with its submodules (the web UI pulls Bootstrap, Font Awesome and other libraries as submodules, so a plain clone will not build):

```bash
git clone -b DDEconfig --recurse-submodules https://code.axiomearth.ai/Steve_Geonetwork/dde-geonetwork2026.git
cd dde-geonetwork2026
```

2. Point Maven at JDK 11 and confirm it:

```bash
export JAVA_HOME=/path/to/jdk-11      # Windows: set JAVA_HOME=C:\path\to\jdk-11
mvn -version                          # must report Java version 11
```

3. Build, skipping tests (expect 15 to 30 minutes the first time while Maven downloads dependencies):

```bash
mvn clean install -DskipTests -Dprebuild-cache=true
```

**Web asset serving: measured on Tomcat, and the prebuild cache is what matters.**

GeoNetwork serves its UI as wro4j bundles (`lib.js`, `gn_search_default.js`,
`gn_search_default.css`). `GeonetWro4jFilter` intercepts `/static/*` and compiles
a bundle on request when it has no usable cache.

Measured 2026-11-14 on **Tomcat 9.0.85** with the 4.4.9-0 war:

| scenario | `gn_search_default.css` | `gn_search_default.js` |
|---|---|---|
| prebuild cache present, first ever request | 0.0046 s | 0.0090 s |
| no cache at all, cold | 16.4 s | 429.5 s |
| after that cold compile, warm | 0.0067 s | 0.0153 s |

`lib.js` (3.3 MB) serves in about 0.03 s warm.

**Build with `-Dprebuild-cache=true`.** It turns a 16 s + 430 s first-request
cliff into milliseconds. The 19 MB `WEB-INF/prebuilt/wro4j-cache.mv.db` is
adopted on first start and copied to
`<geonetwork.dir>/data/resources/htmlcache/wro4j-cache.mv.db`. Without it, the
cold compile is paid per bundle on first request, by whichever visitor arrives
first.

Earlier revisions of this guide reported that the CSS "never caches, so every
page load carries roughly 8 s" and that the prebuild cache "did not make serving
faster". Both were measured under `mvn jetty:run` and **neither holds for a war
on Tomcat**: the CSS caches like everything else and stays near 5 ms across
restarts. Do not use `jetty:run` numbers to reason about a deployment.

Two real defects remain in the war as built, neither of which affects speed:

1. **`debug=true` ships by default.** `wro.debug` defaults to true in `pom.xml`
   and again in the `env-dev` profile, and **no profile sets it false** — not even
   `env-prod`. Pass `-Dwro.debug=false` for a production war and check the
   *deployed* `WEB-INF/wro.properties`, not the command line: Maven skips
   re-filtering that file when the target is newer than the source, so the flag
   can appear to apply while the packaged war keeps the default. A war built here
   had `debug=false` in `target/geonetwork/` and `debug=true` inside
   `geonetwork.war`.
2. **`wroSources` bakes in a build-machine path.** It resolves to
   `${project.build.directory}/webapp`, an absolute path on the machine that
   built the war, so on a server it names a directory that does not exist.

On Windows the prebuild needs **two** invocations, because `wro4j:run` keeps the
H2 cache file open for the life of the Maven JVM and `maven-war-plugin` then
cannot copy it ("The process cannot access the file because another process has
locked a portion of the file"). This is not caused by a running Jetty; it happens
with nothing else running:

```bash
mvn package -pl web -DskipTests -Dprebuild-cache=true   # builds cache, fails at the war copy
mvn war:war -pl web -Dprebuild-cache=true               # fresh JVM, packages the cache in
```

Three dependency problems must be cleared first, none of which the error names:

1. `oss.sonatype.org` (OSSRH) is **retired** and 302-redirects. `web/pom.xml`
   still routes plugin dependencies through it. The artifacts
   (`org.webjars.npm:wrappy`, `minimatch`, `once`, `inflight`) are on Maven
   Central. A `settings.xml` mirroring that repository id to Central is the
   durable fix.
2. An old JDK 11's truststore cannot validate the redirect target: JDK 11.0.2
   carries **93** roots against **118** in Temurin 11.0.33, and Maven reports
   this unhelpfully as "peer not authenticated". Use a current Temurin 11, which
   the enforcer rule now requires anyway, or pass
   `-Djavax.net.ssl.trustStore` pointing at a modern `cacerts`. (An earlier
   revision gave the comparison as 93 against 152; counted the same way on both
   JDKs — `keytool -list -cacerts` — it is 93 against 118.)
3. `.lastUpdated` markers in `~/.m2` make Maven refuse jars it already has
   ("present, but unavailable"). Delete them for the affected artifacts.

**Recommendation: build the deployable war in CI, not on a workstation.**
`.github/workflows/linux.yml` already provisions a modern Temurin 11 with current
certificates and a clean `~/.m2`, which removes all three dependency problems, and
on Linux the war plugin can copy an open file, which removes the two-invocation
split. Publishing that war as a release asset with a checksum also avoids
repeating the 2024 situation, where the only copy of the deployed binary existed
on one machine.

4. The result is `web/target/geonetwork.war`. Copy it to the server.

On Windows with an early JDK 11 build, Maven downloads can fail with TLS errors. Set `MAVEN_OPTS=-Dhttps.protocols=TLSv1.2 -Djdk.tls.client.protocols=TLSv1.2` and retry.

## Step 2: Set up Elasticsearch and PostgreSQL

### Elasticsearch

Run Elasticsearch 8.14.3 as a single node. With Docker, keeping security on for anything reachable from a network:

```bash
docker run -d --name gn-es --restart unless-stopped \
  -p 127.0.0.1:9200:9200 \
  -e discovery.type=single-node \
  -e ES_JAVA_OPTS="-Xms1g -Xmx1g" \
  -e ELASTIC_PASSWORD='<choose a new password>' \
  -e xpack.security.http.ssl.enabled=false \
  -v gn-es-data:/usr/share/elasticsearch/data \
  docker.elastic.co/elasticsearch/elasticsearch:8.14.3
```

Check it answers: `curl -u elastic:<password> http://localhost:9200`. You do not create indices by hand: GeoNetwork creates `gn-records`, `gn-features` and `gn-searchlogs` on first start from the mappings bundled in the war.

The `es/docker-compose.yml` in the repo turns security off and also starts Kibana. It is fine on a laptop, not on a server. Bring up only the index with `docker compose up -d elasticsearch`; the fork disables the Kibana health check, so Kibana is not needed. Its obsolete `version:` key was removed on 2026-11-14, which silences a Compose v2 warning.

### PostgreSQL

Create an empty database and an owner for it:

```sql
CREATE USER geonetwork WITH PASSWORD '<choose a new password>';
CREATE DATABASE geonetwork OWNER geonetwork ENCODING 'UTF8';
```

If you are restoring the old catalogue, restore the `pg_dump` from the existing server into this database now, before GeoNetwork first starts:

```bash
pg_restore --no-owner --role=geonetwork -d geonetwork geonetwork.dump
```

If you are starting fresh, leave it empty. GeoNetwork creates its tables and default data on first start.

Use new passwords for both services. Do not reuse any credential from the 2024 deployment; [HANDOVER.md](HANDOVER.md) explains why.

## Step 3: Deploy to Tomcat and configure

All connection settings in this build are read from environment variables and Java system properties, so you never need to edit files inside the war. Put them in Tomcat's `bin/setenv.sh` (Linux) or `bin\setenv.bat` (Windows), readable only by the Tomcat user.

1. Create the data directory outside Tomcat, owned by the Tomcat user, for example `/srv/geonetwork_data`. Keeping it outside `webapps/` means redeploying the war never touches it.
2. Create `bin/setenv.sh`:

```bash
# Java
export JAVA_HOME=/path/to/jdk-11
export CATALINA_OPTS="$CATALINA_OPTS -Xms1g -Xmx2g \
  -Dgeonetwork.dir=/srv/geonetwork_data \
  -Dgeonetwork.db.type=postgres \
  -Dfile.encoding=UTF-8"

# PostgreSQL
export GEONETWORK_DB_HOST=localhost
export GEONETWORK_DB_PORT=5432
export GEONETWORK_DB_NAME=geonetwork
export GEONETWORK_DB_USERNAME=geonetwork
export GEONETWORK_DB_PASSWORD='<database password>'

# Elasticsearch
export GEONETWORK_ES_PROTOCOL=http
export GEONETWORK_ES_HOST=localhost
export GEONETWORK_ES_PORT=9200
export GEONETWORK_ES_USERNAME=elastic
export GEONETWORK_ES_PASSWORD='<elasticsearch password>'
```

3. Copy `geonetwork.war` into Tomcat's `webapps/` and start Tomcat. The first start takes a few minutes: GeoNetwork creates the database tables (or migrates a restored database), creates the Elasticsearch indices, and populates the empty data directory with the schema plugins, the DDE thesauri and the index configuration. Measured 2026-11-14 on Tomcat 9.0.85 with a 284 MB war and an empty data directory: **about 65 s** from start to the search page answering, and ~35 s on a later start. If `GEONETWORK_DB_*` are unset, note that the baked fallbacks are `www-data`/`www-data` against an H2 database at `~/gn`, so a missing database configuration starts quietly on the wrong store rather than failing.
4. Watch `logs/catalina.out` and `logs/geonetwork.log` until you see the catalogue start without errors, then open `http://<host>:8080/geonetwork`.
5. Sign in as `admin` / `admin` and change that password immediately (top right menu > your profile > Update password). On a restored database, sign in with an existing administrator account instead.

For public access, put Apache or nginx in front of Tomcat with HTTPS, then set the public URL under **Admin console > Settings > Catalog server** (host, port, protocol) so links in records and API responses are correct.

If you deploy the April 2024 `geonetwork.war` instead of a fresh build, the environment variables above are ignored for Elasticsearch: that war has the old host, username and password written into `WEB-INF/config.properties`. After Tomcat expands it, edit `webapps/geonetwork/WEB-INF/config.properties` and set `es.host`, `es.username` and a new `es.password` before the catalogue is used.

## Step 4: Bring up the DDE features

The DDE schema plugin and thesauri arrive with the war, so this step is checking and loading, not installing.

1. **Confirm the schema plugin.** Go to **Admin console > Metadata and templates**. Three standards are listed: `iso19115-3.2018`, `iso19139` and `csw-record`. Dublin Core and ISO 19110 are deliberately left out of this build. (Verified 2026-11-14 against a running 4.4.9-0 catalogue via `GET /srv/api/standards`.)
2. **Confirm the DDE thesauri.** Go to **Admin console > Classification systems > Thesaurus**. These six should be listed under `local.theme`: `acquisitioncodeskos`, `resourcetypeskos`, `servicetypeskos`, `topiccategoryskos`, `codelist_unit_distance`, `codelist_unit_time`. The DDE editor's keyword pickers use exactly these names, so a missing one shows up as an empty picker.
3. **Load the standard templates.** On **Admin console > Metadata and templates**, select `iso19115-3.2018` and click **Load templates for selected standards**. Skip this on a restored database, which already has its templates.
4. **Load the DDE templates and seed records** (fresh install only). The 21 files in [harvest-records-2024/](harvest-records-2024/) are mostly DDE schema rather than ISO 19115-3, so they must be converted on import; four are ISO 19139, which the same conversion handles. Go to **Contribute > Import new records**, choose **Upload a file from your computer**, and under **Apply XSLT conversion** pick `fromDDE-any`. Import `DDEDatasetTemplate.xml`, `DDEImageTemplate.xml` and `DDEServiceTemplate.xml` with **Type of record** set to **Template**; import the other nine as **Metadata**. A folder harvester works too: **Admin console > Harvesting > Harvest from > Directory**, pointed at a server folder holding the files, with the same `fromDDE-any` conversion.

   The conversion's real identifier is `schema:iso19115-3.2018:convert/fromDDE-any` — `GET /srv/api/site/info/transforms` lists all 29 the catalogue offers. The bare name `fromDDE-any` resolves against `webapp/xsl/conversion/import/` instead, which holds only `Add-gmd-prefix` and `WxS_to_INSPIRE`, and fails with HTTP 404 `resource_not_found`.

   > **On a Windows-hosted catalogue this import does not work, and the cause is upstream.**
   > `MetadataInsertDeleteApi.java:913` calls `FilePathChecker.verify(transformWith)` on the whole
   > identifier *before* `GeonetworkDataDirectory.getXsltConversion` splits it on `:`, and `verify`
   > ends in `Paths.get(...)`. On Windows that throws
   > `InvalidPathException: Illegal char <:> at index 6`, returned as HTTP 400. Confirmed
   > 2026-11-14 on Windows 11 with Temurin 11.0.33, both through the API and by running
   > `Paths.get` directly. On Linux `:` is a legal filename character, so the check passes and
   > nobody notices — which is why a Linux deployment is unaffected.
   >
   > **Workaround on Windows: use the Directory harvester**, not Contribute > Import.
   > `LocalFsHarvesterFileVisitor.java:99` calls `getXsltConversion` *without* the
   > `FilePathChecker.verify` step, so the schema-prefixed identifier resolves correctly. This is
   > also how the 2024 catalogue was actually loaded — two `LocalFilesystemHarvester`s over
   > `C:\tmp\forHarvest` (see the harvest configuration recovered in the repo's CLAUDE.md).
   >
   > Proven 2026-11-14 on a fresh 4.4.9-0 deployment: a Directory harvester over all 21 files of
   > `harvest-records-2024/` reported **21 total, 0 unknownSchema, 0 badFormat, 0 doesNotValidate**
   > and produced 18 distinct records, all indexed as `iso19115-3.2018`.

   Two traps when defining that harvester by hand (via `admin.harvester.add`, which is what the
   admin console posts to):

   - **`ownerGroup` is mandatory.** `LocalFilesystemHarvester.java:212` does
     `Integer.valueOf(params.getOwnerIdGroup())`, so omitting it makes every record fail with
     `An error occurred while harvesting file … Error is: null.` — on Java 11 that is
     `NumberFormatException` whose message is the string `"null"`. The harvester logs only the
     message, so a missing required field reports as `null` and nothing else. Include
     `<site><ownerGroup><id>N</id></ownerGroup></site>` with a real group id (`GET /srv/api/groups`).
   - **Harvester logs go to the process working directory**, not a fixed path, so they land wherever
     Tomcat was started from. That is why the 2024 logs sit in `apache-tomcat-9.0.85/bin/`.
5. **Check the DDE editor.** Open any ISO 19115-3 record and click **Edit**. The editor should open on the **DDE** view with eight tabs, starting at **Basic Metadata**. The upstream Default, Advanced and XML views stay available from the view switcher.
6. **CDIF harvester (optional).** It is a separate harvester type that does nothing unless configured. To use it: **Admin console > Harvesting > Harvest from > Simple URL**, choose the **CDIF Sitemap** preset, set the sitemap URL, and confirm the conversion is `schema:iso19115-3.2018:convert/fromJsonCdif`. Details are in the repo's [agents.md](../agents.md).

## Step 5: Verify

Tick these off before handing the catalogue to users.

- [ ] `http://<host>:8080/geonetwork` loads the home page with no error banner.
- [ ] **Admin console > Statistics & status > Status** shows the database, Elasticsearch and indexing checks green.
- [ ] **Admin console > Tools > Catalog admin tools > Rebuild index** completes, and the record count in search matches the database (on a restored database, compare with `SELECT count(*) FROM metadata;`).
- [ ] `iso19115-3.2018` is listed as a standard, and all six DDE thesauri appear under Classification systems.
- [ ] Editing a record opens the DDE view with eight tabs, and the DDE keyword pickers offer values.
- [ ] `http://<host>:8080/geonetwork/srv/api/records/<uuid>/formatters/dde` returns the DDE rendering of a record.
- [ ] A search for a known seed-record title returns it. Use a title that actually exists: the Arizona record is titled **`US-AZ_AZGS_1M_Lithostratigraphy`**, so a search for "Arizona Lithostratigraphy" matches nothing. Others to try: "50m Multibeam Dataset of Australia 2012", "CHN CGS EN 1:1M Bedrock Lithostratigraphy".
- [ ] The default `admin` password has been changed, and Elasticsearch is not reachable from outside the server.

## Moving content from the old server

If the existing Alibaba Cloud deployment can be exported, restore its database in Step 2 and copy only the file content of its data directory into the new one. Do this before the first start in Step 3, with Tomcat stopped.

| Copy from the old data directory | Why |
| --- | --- |
| `data/metadata_data/` | Attachments and thumbnails uploaded to records |
| `data/resources/` | Logos and other catalogue images |
| `config/encryptor.properties` | Only with a restored database: it decrypts passwords stored in harvester settings |

| Do not copy | Why |
| --- | --- |
| `config/schema_plugins/` | GeoNetwork never overwrites an existing plugin folder, so the old 4.4.4 DDE plugin would silently replace the new one |
| `config/codelist/` | Same rule: a non-empty folder blocks the new thesauri, leaving 4 instead of 12 files. Copy across only thesauri created in the old catalogue's UI, if any |
| `config/index/` | Use the 4.4.9 mappings from the new war |
| `data/backup/`, logs, any `*.mv.db` file | Old exports and an embedded H2 database can hold user records |

The record files from the 2024 test deployment are in [data-2024/](data-2024/), already reduced to `metadata_data/` and `resources/`. Copy both into `data/` under the new data directory; the new war supplies the plugins, thesauri and index mappings.

Then start Tomcat, sign in with an existing administrator account, and run **Rebuild index**. No Elasticsearch snapshot is needed.

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| Build fails with compile errors in unrelated modules | Maven is using a JDK other than 11. Check `mvn -version` and set `JAVA_HOME`. |
| Build fails on `RequireJavaVersion` | Working as intended: the JDK is older than 11.0.25 or newer than 11. Install Temurin 11 and set `JAVA_HOME`. |
| An `/srv/api/*` path returns HTTP 500 `{"error":{"class":"ServiceNotFoundEx","message":"Service not found"}}` | **Almost always a missing `Accept` header, not a broken catalogue.** The API negotiates on content type, and `Accept: */*` — which `curl` sends by default — does not match, so the request falls through and Jeeves reports "Service not found". Add the header: `curl -H "Accept: application/json" .../srv/api/standards`. Verified 2026-11-14: identical requests returned 500 without the header and 200 with it. The 500 is emitted with **no entry in any log**, which makes it easy to misread as a server fault; cost several hours of misdiagnosis here before the two commands were compared. |
| Catalogue log shows `Requested setting with name: … not found. Add it to the settings table.` plus `Unable to retrieve the current GeoNetwork version from the database` | Normal on a genuinely empty database during the first start: Hibernate creates the schema (`hibernate.hbm2ddl.auto` is `update` whenever `db.migration_onstartup=true`), and these probes run before it finishes. Harmless if the catalogue then serves. The matching H2 complaints — `Table "SETTINGS" not found (this database is empty)` and `Column "ID" not found` in `<db>.trace.db` — are the same startup probes and are **not** evidence of a fault. |
| Catalogue starts against the wrong database | With `GEONETWORK_DB_*` unset the baked fallbacks are an **H2** database at `~/gn` with user/password `www-data`. That is a silent success, not an error, so a forgotten setting means the catalogue quietly uses a local H2 file — possibly one an earlier build left behind. Always set `GEONETWORK_DB_*` explicitly and add `-Dgeonetwork.db.type=postgres`; `config-node/srv.xml` imports `config-db/${geonetwork.db.type:h2}.xml`, so h2 is what you get by default. |
| Catalogue log shows `javax.imageio.IIOException: Can't get input stream from URL!` caused by `javax.net.ssl.SSLException: No PSK available. Unable to resume.` | JDK 11.0.2's TLS 1.3 session resumption, breaking an outbound HTTPS fetch at runtime (seen inside the Spring Security filter chain). Use Temurin 11.0.25+, which the enforcer rule now requires. Observed once, not on every request, and it was **not** the cause of the `ServiceNotFoundEx` condition above — do not conflate the two. `-Djdk.tls.client.protocols=TLSv1.2` in `CATALINA_OPTS` was tried and made no observable difference, so it is not a recommended remedy. |
| Build fails in `web-ui` with missing files | Submodules were not cloned. Run `git submodule update --init --recursive`. |
| GeoNetwork starts on H2, not PostgreSQL | `-Dgeonetwork.db.type=postgres` is missing from `CATALINA_OPTS`. |
| Search page says the index is unavailable | Elasticsearch host, port or credentials are wrong in `setenv.sh`, or Elasticsearch is not 8.x. |
| DDE view or DDE thesauri missing | An old `schema_plugins` or `codelist` folder in the data directory blocked the new ones (see above). Stop Tomcat, move those folders aside, restart. |
| DDE XML is rejected on import | No conversion was chosen. Pick `fromDDE-any` under Apply XSLT conversion. |
| Import fails with HTTP 400 `Illegal char <:> at index 6: schema:…:convert/…` | Upstream Windows-only bug (see Step 4.4): `FilePathChecker.verify` runs `Paths.get` on the full `schema:…` identifier before it is split. Use the Directory harvester instead, which skips that check. Unaffected on Linux. |
| Import fails with HTTP 404 `resource_not_found` | The conversion name was given without its `schema:<schema>:convert/` prefix, so it was looked up under `webapp/xsl/conversion/import/`. Use the full identifier from `GET /srv/api/site/info/transforms`. |

## Open questions

- Will the old database and data directory be exported from the Alibaba Cloud server, or is this a fresh catalogue seeded from the 2024 records?
- What public hostname will the catalogue use, and who provides the HTTPS certificate?
- Who will own upstream updates? GeoNetwork is at 4.4.12; this fork is on 4.4.9.
