# GeoNetwork-DDE in Docker

Three services: the catalogue (built from this fork's war), Elasticsearch 8.14.3, PostgreSQL 15.

```bash
cd deploy/docker
cp .env.example .env            # edit it; compose refuses to start otherwise
docker compose up -d --build
```

Then `http://<host>:8080/geonetwork`. First start takes a few minutes: GeoNetwork creates the
database tables, creates the Elasticsearch indices, and populates the data directory with the schema
plugins, the DDE thesauri and the index configuration. About **65 s** measured on Tomcat 9.0.85 with
an empty data directory, and ~35 s on later starts; the healthcheck allows 180 s.

## Why not the composition already in `docker/gn-postgres/`

That one is upstream's, labelled "for development and debugging", and it cannot be adapted:

- **Elasticsearch 7.6.2**, below this fork's stated 8.14.x minimum.
- `mdillon/postgis`, abandoned years ago.
- The obsolete `version:` key, which Compose v2 warns about.
- Most importantly, **different environment variable names** — `POSTGRES_DB_HOST`, `DATA_DIR`,
  `ES_HOST` — which only the official `geonetwork` image understands, because its entrypoint
  translates them. This image is built from this fork's war and takes the real names.

Upstream points production users at `geonetwork/docker-geonetwork`. That builds from a released war,
so it carries neither the DDE schema plugin nor the CDIF harvester, and it has no wro4j prebuild
cache.

## The five things that fail silently, and which are actually checked

`deploy/README.md` documents these for a bare-metal deployment. In a container three of them become
failures you cannot miss, and two remain configuration you should understand.

| # | hazard | how it is handled |
|---|---|---|
| 1 | wro4j cache missing from the war | **build fails** — `unzip -l` must find `WEB-INF/prebuilt/wro4j-cache.mv.db` |
| 2 | wro4j left in debug mode | **build fails** — `WEB-INF/wro.properties` must say `debug=false` |
| 3 | `GEONETWORK_DB_PORT` unset | **container refuses to start** — entrypoint requires all five `GEONETWORK_DB_*` |
| 4 | silent fallback to H2 | entrypoint sets `-Dgeonetwork.db.type=postgres` and requires the five vars; **verify after first start**, below |
| 5 | `wroSources` absolute build-machine path | entrypoint reads the path out of the deployed `wro.properties` and creates it |

**1. The wro4j cache is not optional here.** Measured on Tomcat 9.0.85: the first ever request for
`gn_search_default.css` takes **16.4 s** and for `gn_search_default.js` **429.5 s** without the
cache, against ~5 ms with it. A container starts cold every time, so a war built without
`-Dprebuild-cache=true` would make every fresh container unusable for seven minutes. The build
asserts the cache is inside the war rather than trusting the flag, because a war missing it is still
valid and still deploys.

**2.** `wro.debug` defaults to `true` in `pom.xml` and **no profile sets it false**, so the flag has
to be passed explicitly. It lands in `WEB-INF/wro.properties`, which is where the build checks it.

**3 and 4 are the same trap seen from two sides.** GeoNetwork reads its database settings from two
mechanisms:

- **Environment variables** — `GEONETWORK_DB_HOST`, `_PORT`, `_NAME`, `_USERNAME`, `_PASSWORD`.
  Spring resolves these with `#{systemEnvironment['...']}`, so passing them as `-D` does *nothing*.
- **`-D` system properties** — `geonetwork.db.type`, `geonetwork.dir`, `file.encoding`.

`GEONETWORK_DB_PORT` has **no baked default**. Unset, the URL comes out as
`jdbc:postgresql://localhost:/geonetwork?` and the error names `org.postgresql.Driver` — pointing at
the driver rather than the missing port. And with the variables unset altogether the fallbacks are an
**H2 file at `~/gn`** with user and password `www-data`, while `config-node/srv.xml` imports
`config-db/${geonetwork.db.type:h2}.xml`. So a missing setting is a silent success on the wrong
database, not an error. The entrypoint therefore refuses to start rather than letting that happen.

**Verify PostgreSQL is really in use** after the first start, because the failure mode is a catalogue
that works:

```bash
docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\dt' | head
```

Tables such as `metadata`, `users`, `settings` mean GeoNetwork is using PostgreSQL. An empty list
after a successful start means it is on H2 instead.

## What is verified, and what is not

Verified before committing: both base image tags resolve from the registry, `docker compose config`
parses, `docker build --check` reports no warnings, and the entrypoint passes `sh -n`. The two
build-time assertions and the entrypoint's refusal to start are mechanical, so they either hold or
the build and the container stop.

**Not yet verified: the image has never been built or run.** The full build needs the submodules and
a long Maven run, and the wro4j prebuild has only ever been exercised on Windows, where it needs two
Maven invocations because `wro4j:run` holds the cache file open and `maven-war-plugin` then cannot
copy it. On Linux a single `package` is expected to work; if ASSERT 1 fails with the war present,
that is the same lock problem and the fix is to split the step:

```dockerfile
RUN mvn --batch-mode package -pl web -am -DskipTests -Dprebuild-cache=true -Dwro.debug=false || true
RUN mvn --batch-mode war:war -pl web -Dprebuild-cache=true -Dwro.debug=false
```

The `HEALTHCHECK` endpoint is also unproven. It POSTs to the search API with
`Accept: application/json`, which matters: GeoNetwork's content negotiation **rejects
`Accept: */*`**, which is what curl sends by default, and returns HTTP 500 `ServiceNotFoundEx`
logged nowhere. If the container reports unhealthy while the catalogue answers in a browser, check
that endpoint by hand first rather than assuming the catalogue is broken.

## Upgrading to a new image

Nothing you configured is lost. Settings, users, the admin password, harvester definitions and
records all live in PostgreSQL; attachments and `encryptor.properties` live in the `gn_data`
volume. Only the `geonetwork` container is replaced, so there is no reconfiguration to redo.

**But a new image does not, by itself, update the schema plugin.** That is the step to get right,
and getting it wrong looks like the fix not working rather than like a mistake.

Schemas are loaded from the data directory, not from the war:

```
[geonetwork.schemamanager] - Loading schema /var/lib/geonetwork_data/config/schema_plugins/iso19115-3.2018/...
```

and `GeonetworkDataDirectory` copies them there only on a first start:

```java
Path schemaCatFile = configDir.resolve(Geonet.File.SCHEMA_PLUGINS_CATALOG);
if (!Files.exists(schemaCatFile)) {          // only when the catalogue is ABSENT
    ...
    if (!Files.exists(destDir)) {            // and only plugins that are MISSING
        IO.copyDirectoryOrFile(next, destDir, false);
```

Both guards have to be false for a plugin to be refreshed. On an upgrade the catalogue file exists,
so the outer block never runs and the **old XSLTs stay in the volume**. Anything in
`schemas/iso19115-3.2018/` — the DDE converters, the CDIF formatter, the editor view, the indexing
fields — will appear not to have changed.

So the upgrade is: load the image, remove the catalogue file and the plugin, start.

```bash
cd /root/docker && docker compose stop geonetwork
```

```bash
docker compose run --rm --entrypoint sh geonetwork -c 'rm -f /var/lib/geonetwork_data/config/schemaplugin-uri-catalog.xml && rm -rf /var/lib/geonetwork_data/config/schema_plugins/iso19115-3.2018'
```

```bash
docker compose up -d && docker compose logs -f geonetwork
```

**Check for `- Copying schema plugin catalogue ...` in the log.** That line is the confirmation the
plugin was re-copied. Without it the new XSLTs are not live, whatever the image says.

Only `iso19115-3.2018` is deleted, so the other schema plugins stay and GeoNetwork re-copies just
the missing one. Nothing user-created lives in that directory: it is a build artifact, and the DDE
thesauri are elsewhere, under `config/codelist/`.

A full reindex is not needed for a formatter change, since `/formatters/cdif` reads the record
rather than the index. It *is* needed after a change to `index-fields/`, from Admin > Tools.

## Host prerequisites

Elasticsearch 8 needs this on the **host**, not in the container:

```bash
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf
```

Memory: Elasticsearch wants ≥1 GB heap, GeoNetwork ~2 GB, plus PostgreSQL and the OS. **8 GB is
comfortable**; on 4 GB set `GN_HEAP=-Xms512m -Xmx1g` and `ES_JAVA_OPTS=-Xms512m -Xmx512m` in `.env`.
Disk: the war is ~285 MB, the three images and the Maven build cache run to several GB.

## Build notes

The build context is the **repository root**, since the war is built from the whole module tree;
`.dockerignore` at the root keeps the context from including the 888 MB of git history and every
module's `target/`.

`maven-settings.xml` mirrors the retired `oss.sonatype.org` to Central. `web/pom.xml` still routes
four `org.webjars.npm` artifacts through OSSRH, which 302-redirects, and Maven reports it as an
authentication error naming neither the repository nor the artifacts.

The builder image is `maven:3.9.9-eclipse-temurin-11`. `pom.xml`'s enforcer requires
`[11.0.25,12)`, so the build fails loudly if that image ever carries an older Java 11 or a newer
major — which is why no patch version is pinned here.

**Submodules must be checked out** before building, or the UI build fails on missing assets:

```bash
git submodule update --init --recursive
```

`plugins/datahub-integration/geonetwork-ui` will warn that it cannot be accessed. That is expected
and harmless unless you are building that plugin.

## TLS

GeoNetwork on Tomcat can terminate TLS itself, with a keystore on a `:443` connector. This stack
terminates it in an nginx container instead, so the catalogue image carries no certificates and
renewal is a file swap. It is an optional profile:

```bash
docker compose --profile tls up -d
```

If you are migrating from a Tomcat TLS connector, convert its PKCS12 keystore to the PEM pair
nginx wants — nginx cannot read PKCS12 directly:

```bash
mkdir -p deploy/docker/tls
openssl pkcs12 -in keystore.pfx -clcerts -nokeys  -out deploy/docker/tls/fullchain.pem
openssl pkcs12 -in keystore.pfx -cacerts -nokeys -chain >> deploy/docker/tls/fullchain.pem
openssl pkcs12 -in keystore.pfx -nocerts -nodes   -out deploy/docker/tls/privkey.pem
chmod 600 deploy/docker/tls/privkey.pem
```

`deploy/docker/tls/` is gitignored. Check the expiry before relying on it:

```bash
openssl x509 -in deploy/docker/tls/fullchain.pem -noout -subject -dates -ext subjectAltName
```

**Then set the public URL in the catalogue**, or it will build `http://` links into an `https://`
page and the browser will block them as mixed content. `X-Forwarded-Proto` from the proxy is
necessary but not sufficient: go to **Admin > Settings > System > Server** and set the host to the
public name and the port to 443 with HTTPS. The `nodeUrl` setting is what the CDIF formatter uses to
build `@id` values, so getting it wrong puts the wrong base URL into every exported record.

The proxy also gives a redirect that a Tomcat connector does not. `redirectPort` on an HTTP
connector is **not** an HTTP-to-HTTPS redirect: it applies only to requests for a resource that
declares a `CONFIDENTIAL` transport guarantee in `web.xml`, so everything else is served over plain
HTTP. If you are replacing such a setup, check what `:8080` has been exposing. The nginx `:80`
block is an unconditional 301.

## Security

- `.env` is gitignored and must stay that way. **This repository is public.**
- Elasticsearch and PostgreSQL ports are deliberately **not published**; they are reachable only on
  the compose network. If you publish 9200, turn `xpack.security.enabled` back on and set
  credentials.
- Behind a reverse proxy, bind the catalogue to localhost: `GN_PORT=127.0.0.1:8080` in `.env`.
- **Treat every credential from the 2024 Alibaba deployment as compromised.** Two July 2024
  deployment notes in the public `usgin/dde-metadata` repository contain Elasticsearch passwords in
  plain text. Generate new ones: `openssl rand -base64 24`.

## Restoring the 2024 catalogue

A `pg_dump -Fc` dump carries records, users, groups, permissions and settings together:

```bash
docker compose cp dump.pgc postgres:/tmp/dump.pgc
docker compose exec postgres pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean /tmp/dump.pgc
docker compose restart geonetwork
```

The Elasticsearch index is **derived** — GeoNetwork 4 rebuilds it, so no snapshot is needed. Reindex
from Admin > Tools after restoring.

Attachments and browse graphics are *files*, not rows, so a database dump alone loses them; they
belong in the `gn_data` volume. `deploy/data-2024/` holds the scrubbed subset that survives.

## Harvesting the seed records

On Linux, **Contribute > Import works** with the full transform identifier:

```
schema:iso19115-3.2018:convert/fromDDE-any
```

The upstream bug that blocks this is Windows-only — `MetadataInsertDeleteApi.java:913` calls
`FilePathChecker.verify` on the whole identifier before it is split on `:`, and `verify` ends in
`Paths.get()`, which throws `InvalidPathException` on Windows. `:` is a legal filename character on
Linux, so the check passes. The Directory harvester, which bypasses that check, also works and is
how the 2024 catalogue was really loaded.

To get the 21 records in: `docker compose cp ../harvest-records-2024 geonetwork:/tmp/forHarvest`,
then configure a Directory harvester over `/tmp/forHarvest` with that transform and an `ownerGroup`.
Omitting `ownerGroup` gives `added=0` with `Error is: null` — a `NumberFormatException` from
`Integer.valueOf(null)`, whose message is the string `"null"`.
