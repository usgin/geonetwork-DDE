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
an empty data directory, and \~35 s on later starts; the healthcheck allows 180 s.



## Why not the composition already in `docker/gn-postgres/`

That one is upstream's, labelled "for development and debugging", and it cannot be adapted:

* **Elasticsearch 7.6.2**, below this fork's stated 8.14.x minimum.
* `mdillon/postgis`, abandoned years ago.
* The obsolete `version:` key, which Compose v2 warns about.
* Most importantly, **different environment variable names** — `POSTGRES\_DB\_HOST`, `DATA\_DIR`,
`ES\_HOST` — which only the official `geonetwork` image understands, because its entrypoint
translates them. This image is built from this fork's war and takes the real names.

Upstream points production users at `geonetwork/docker-geonetwork`. That builds from a released war,
so it carries neither the DDE schema plugin nor the CDIF harvester, and it has no wro4j prebuild
cache.





## Five things that fail silently, and which are actually checked

`deploy/README.md` documents these for a bare-metal deployment. In a container three of them become
failures you cannot miss, and two remain configuration you should understand.

|#|hazard|how it is handled|
|-|-|-|
|1|wro4j cache missing from the war|**build fails** — `unzip -l` must find `WEB-INF/prebuilt/wro4j-cache.mv.db`|
|2|wro4j left in debug mode|**build fails** — `WEB-INF/wro.properties` must say `debug=false`|
|3|`GEONETWORK\_DB\_PORT` unset|**container refuses to start** — entrypoint requires all five `GEONETWORK\_DB\_\*`|
|4|silent fallback to H2|entrypoint sets `-Dgeonetwork.db.type=postgres` and requires the five vars; **verify after first start**, below|
|5|`wroSources` absolute build-machine path|entrypoint reads the path out of the deployed `wro.properties` and creates it|

1. **The wro4j cache is not optional here.** Measured on Tomcat 9.0.85: the first ever request for
`gn\_search\_default.css` takes **16.4 s** and for `gn\_search\_default.js` **429.5 s** without the
cache, against \~5 ms with it. A container starts cold every time, so a war built without
`-Dprebuild-cache=true` would make every fresh container unusable for seven minutes. The build
asserts the cache is inside the war rather than trusting the flag, because a war missing it is still
valid and still deploys.
2. `wro.debug` defaults to `true` in `pom.xml` and **no profile sets it false**, so the flag has
to be passed explicitly. It lands in `WEB-INF/wro.properties`, which is where the build checks it.
3. &#x20;**and 4 are the same trap seen from two sides.** GeoNetwork reads its database settings from two
mechanisms:
* **Environment variables** — `GEONETWORK\_DB\_HOST`, `\_PORT`, `\_NAME`, `\_USERNAME`, `\_PASSWORD`.
Spring resolves these with `#{systemEnvironment\['...']}`, so passing them as `-D` does *nothing*.
* **`-D` system properties** — `geonetwork.db.type`, `geonetwork.dir`, `file.encoding`.



`GEONETWORK\_DB\_PORT` has **no baked default**. Unset, the URL comes out as
`jdbc:postgresql://localhost:/geonetwork?` and the error names `org.postgresql.Driver` — pointing at
the driver rather than the missing port. And with the variables unset altogether the fallbacks are an
**H2 file at `\~/gn`** with user and password `www-data`, while `config-node/srv.xml` imports
`config-db/${geonetwork.db.type:h2}.xml`. So a missing setting is a silent success on the wrong
database, not an error. The entrypoint therefore refuses to start rather than letting that happen.

**Verify PostgreSQL is really in use** after the first start, because the failure mode is a catalogue
that works:

```bash
docker compose exec postgres psql -U "$POSTGRES\_USER" -d "$POSTGRES\_DB" -c '\\dt' | head
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
`Accept: \*/\*`**, which is what curl sends by default, and returns HTTP 500 `ServiceNotFoundEx`
logged nowhere. If the container reports unhealthy while the catalogue answers in a browser, check
that endpoint by hand first rather than assuming the catalogue is broken.





## Where the build has to happen, and why

**The war is built on a developer machine, not on the server and not inside the image.**

The self-contained multi-stage `Dockerfile` exists and is the right thing when it works, but it
cannot be relied on: this project pulls roughly 390 artifacts from `repo.osgeo.org`, including the
whole GeoTools stack and `saxon:9.1.0.8b-patch`, the XSLT engine the schema plugin runs on. None of
them is on Maven Central — `gt-main`, `gt-metadata` and `saxon` all return 404 there, checked
directly. When OSGeo is down, as it was on 2026-11-16 returning 502, a build on any machine with a
cold Maven cache dies at `gn-common` and cannot recover.

A warm `~/.m2` is then the only reachable copy of the dependency set, which makes `mvn -o` on a
machine that has one the fallback, and `Dockerfile.prebuilt` the image recipe. See the comment at
the top of that file.

**Delete `web/target/wro4j-cache.mv.db` before building, or a change to any `.less` or `.js`
file will not reach the war.** `wro4j:run` reuses an existing cache wholesale: it keys on group
name, not on source content or mtime, so with a cache left over from an earlier build it recompiles
nothing and silently emits the previous CSS. This cost a whole deploy cycle on 2026-11-16 — the
image, the schema plugin and the formatter cache were all correctly refreshed, the XSLT changes were
live, and the CSS change was absent because it had never been compiled. The served
`gn_search_default.css` was byte-identical to the previous build, which is the tell:

```bash
rm -f web/target/wro4j-cache.mv.db && rm -rf web/target/wro4j-output
```

`mvn clean` also does it, at the cost of a full rebuild.

**Pass `-DschemasCopy=true` whenever anything under `schemas/` changed, or the war ships the
previous version of it.** Without that property the `schemas-unpack` profile activates and the
schema plugins come from installed Maven *artifacts*, not from the working tree, so an edited XSLT
is simply absent from the war. Worse, that unpack sets `overWrite=false` against
`web/src/main/webapp/WEB-INF/data/config/schema_plugins/`, so rebuilding the artifact does not
refresh a directory that already exists — the stale copy wins twice over. Delete the plugin first
and let the copy write it fresh:

```bash
rm -rf web/src/main/webapp/WEB-INF/data/config/schema_plugins/iso19115-3.2018
```

Then always check the war actually contains the change before building an image, naming a string
only the new version has:

```bash
unzip -p web/target/geonetwork.war WEB-INF/data/config/schema_plugins/iso19115-3.2018/index-fields/index.xsl | grep -c dde-bg
```

This has the same shape as the wro4j cache above, and the same symptom: a deploy that succeeds,
restarts cleanly, and serves the old behaviour. Both are silent, so verify the artifact rather than
the exit code.

The build is then two Maven invocations, not one, because `wro4j:run` holds the H2 cache file open
for the life of the Maven JVM and `maven-war-plugin` then cannot copy it into the war. The first
invocation builds the cache and fails at packaging; the second, in a fresh JVM, packages it:

```bash
mvn -o package -pl web -am -DskipTests -DschemasCopy=true -Dprebuild-cache=true -Dwro.debug=false
```

```bash
mvn -o war:war -pl web -DschemasCopy=true -Dprebuild-cache=true -Dwro.debug=false
```

**If any Java changed, `mvn install` the modules that own it first, or the war ships the previously
installed jar.** The second invocation is `-pl web` alone, so there is no reactor sibling to take
`gn-core` and the rest from, and offline resolution falls back to `~/.m2`. Schema and web-UI edits
survive this because the war plugin copies those from the working tree -- the `webResources` lines
in its log say so -- but a jar dependency does not. On 2026-11-18 a one-line fix in
`EsSearchManager` was compiled correctly by the first invocation, at `core/target/gn-core-4.4.9-0.jar`,
and the war still carried a copy five days old. Nothing failed; the war was simply built around the
old jar.

Find the modules and install them:

```bash
git log --since=<date of the installed jars> --name-only --pretty=format: | grep -E '\.java$' | sed 's#/src/.*##' | sort -u
```

```bash
mvn -o install -pl core,harvesters -DskipTests
```

Then re-run `war:war`. Verify the jar rather than the build log, because this failure is silent too
-- a method name from the change is in the class file's constant pool:

```bash
unzip -p web/target/geonetwork.war WEB-INF/lib/gn-core-4.4.9-0.jar > /tmp/c.jar && unzip -p /tmp/c.jar org/fao/geonet/kernel/search/EsSearchManager.class | grep -c hasIndexingError
```

Then the image, from the repository root:

```bash
docker build -f deploy/docker/Dockerfile.prebuilt -t dde-geonetwork:4.4.9-0 .
```

```bash
docker save dde-geonetwork:4.4.9-0 | gzip -1 > ../dde-geonetwork-4.4.9-0.tar.gz
```

About 713 MB as an image, 486 MB compressed. Both build-time assertions run on the way through, so
a war missing the wro4j cache or built without `-Dwro.debug=false` is rejected here rather than
deployed.

### Enabling builds elsewhere

The practical answer is **don't build elsewhere** — distribute the image. Everything below is for
when someone genuinely needs to build.

| option | size | notes |
|---|---|---|
| **GitLab Container Registry** | 486 MB per image | Best. Colleagues `docker pull` and deploy; nobody needs Maven, a JDK, or the dependency set. Needs a runner or a manual `docker push`. |
| **GitLab Maven Package Registry**, OSGeo subset only | **185 MB** | Purpose-built for this. Publish the 392 OSGeo-sourced artifacts, point `settings.xml` at the registry. No git bloat, proper Maven semantics. |
| Tarball of the OSGeo subset as a GitLab generic package | 185 MB | Cruder but simple: extract into `~/.m2/repository`. |
| A Maven proxy (Nexus, Artifactory) | — | The real answer if this recurs. Proxies OSGeo and caches it, so an outage stops mattering. Needs hosting. |
| **The whole `~/.m2` in git** | **4.4 GB, 2611 jars** | No. Git handles large binary trees badly and every clone pays. Most of it is Central content that is reachable anyway. |

Only the OSGeo-sourced 185 MB is actually scarce; the other 4.2 GB is ordinary Central content.
Colleagues in mainland China should also mirror Central through
`https://maven.aliyun.com/repository/public` for speed — but note that does **not** cover the OSGeo
artifacts, which is the whole difficulty.

## Upgrading to a new image

Nothing you configured is lost. Settings, users, the admin password, harvester definitions and
records all live in PostgreSQL; attachments and `encryptor.properties` live in the `gn\_data`
volume. Only the `geonetwork` container is replaced, so there is no reconfiguration to redo.

**But a new image does not, by itself, update the schema plugin.** That is the step to get right,
and getting it wrong looks like the fix not working rather than like a mistake.

Schemas are loaded from the data directory, not from the war:



```
\[geonetwork.schemamanager] - Loading schema /var/lib/geonetwork\_data/config/schema\_plugins/iso19115-3.2018/...
```



and `GeonetworkDataDirectory` copies them there only on a first start:



```java
Path schemaCatFile = configDir.resolve(Geonet.File.SCHEMA\_PLUGINS\_CATALOG);
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
cd /root/docker \&\& docker compose stop geonetwork
```

```bash
docker compose run --rm --entrypoint sh geonetwork -c 'rm -f /var/lib/geonetwork\_data/config/schemaplugin-uri-catalog.xml \&\& rm -rf /var/lib/geonetwork\_data/config/schema\_plugins/iso19115-3.2018'
```

```bash
docker compose up -d \&\& docker compose logs -f geonetwork
```

**Check for `- Copying schema plugin catalogue ...` in the log.** That line is the confirmation the
plugin was re-copied. Without it the new XSLTs are not live, whatever the image says.

Only `iso19115-3.2018` is deleted, so the other schema plugins stay and GeoNetwork re-copies just
the missing one. Nothing user-created lives in that directory: it is a build artifact, and the DDE
thesauri are elsewhere, under `config/codelist/`.

### The full sequence

One on the build machine, the rest on the server.

```bash
scp dde-geonetwork-4.4.9-0.tar.gz root@<server>:/root/
```

```bash
cd /root && gunzip -c dde-geonetwork-4.4.9-0.tar.gz | docker load && docker images dde-geonetwork
```

Check the image ID is the one you just built. If the tag still points at the old image, everything
after this is pointless.

```bash
cd /root/docker && docker compose exec -T postgres pg_dump -Fc -U geonetwork geonetwork > /root/geonetwork-$(date +%F).dump
```

```bash
cd /root/docker && docker compose stop geonetwork
```

```bash
cd /root/docker && docker compose run --rm --entrypoint sh geonetwork -c 'rm -f /var/lib/geonetwork_data/config/schemaplugin-uri-catalog.xml && rm -rf /var/lib/geonetwork_data/config/schema_plugins/iso19115-3.2018'
```

```bash
cd /root/docker && docker compose run --rm --entrypoint sh geonetwork -c 'rm -rf /var/lib/geonetwork_data/data/resources/htmlcache/formatter-cache && ls /var/lib/geonetwork_data/data/resources/htmlcache/'
```

**Clearing the formatter cache is as necessary as replacing the plugin, and is easy to miss
because everything looks right without it.** GeoNetwork caches rendered formatter output under
`<data dir>/data/resources/htmlcache/formatter-cache`, so after an upgrade `/formatters/cdif` is
served from a copy made by the old XSLT. On 2026-11-16 the plugin refresh succeeded and the new
XSLT was verifiably in the volume, yet a record returned byte-identical broken output until this
directory was removed.

The `ls` prints what remains. **Leave `wro4j-cache.mv.db`**: that is the prebuild cache, and
deleting it costs a 16 s first request for the CSS and 430 s for the JS.

```bash
cd /root/docker && docker compose up -d && docker compose logs -f geonetwork
```

`docker compose run` reads `.env`, so it must be run from the compose directory or it will fail on
a missing `ENCRYPTOR_PASSWORD`.

```bash
cd /root/docker && docker compose ps && curl -s -o /dev/null -w 'catalog: %{http_code}\n' -H 'Accept: application/json' http://localhost:8080/geonetwork/srv/eng/catalog.search
```

A full reindex is not needed for a formatter change, since `/formatters/cdif` reads the record
rather than the index. It *is* needed after a change to `index-fields/`, from Admin > Tools, and
after changing the server host, because stored link fields embed the old base URL.



## Host prerequisites

Elasticsearch 8 needs this on the **host**, not in the container:

```bash
sudo sysctl -w vm.max\_map\_count=262144
echo 'vm.max\_map\_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf
```

Memory: Elasticsearch wants ≥1 GB heap, GeoNetwork \~2 GB, plus PostgreSQL and the OS. **8 GB is
comfortable**; on 4 GB set `GN\_HEAP=-Xms512m -Xmx1g` and `ES\_JAVA\_OPTS=-Xms512m -Xmx512m` in `.env`.
Disk: the war is \~285 MB, the three images and the Maven build cache run to several GB.



## Build notes

The build context is the **repository root**, since the war is built from the whole module tree;
`.dockerignore` at the root keeps the context from including the 888 MB of git history and every
module's `target/`.

`maven-settings.xml` mirrors the retired `oss.sonatype.org` to Central. `web/pom.xml` still routes
four `org.webjars.npm` artifacts through OSSRH, which 302-redirects, and Maven reports it as an
authentication error naming neither the repository nor the artifacts.

The builder image is `maven:3.9.9-eclipse-temurin-11`. `pom.xml`'s enforcer requires
`\[11.0.25,12)`, so the build fails loudly if that image ever carries an older Java 11 or a newer
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

* `.env` is gitignored and must stay that way. **This repository is public.**
* Elasticsearch and PostgreSQL ports are deliberately **not published**; they are reachable only on
the compose network. If you publish 9200, turn `xpack.security.enabled` back on and set
credentials.
* Behind a reverse proxy, bind the catalogue to localhost: `GN\_PORT=127.0.0.1:8080` in `.env`.
* **Treat every credential from the 2024 Alibaba deployment as compromised.** Two July 2024
deployment notes in the public `usgin/dde-metadata` repository contain Elasticsearch passwords in
plain text. Generate new ones: `openssl rand -base64 24`.



## Restoring the 2024 catalogue

A `pg\_dump -Fc` dump carries records, users, groups, permissions and settings together:

```bash
docker compose cp dump.pgc postgres:/tmp/dump.pgc
docker compose exec postgres pg\_restore -U "$POSTGRES\_USER" -d "$POSTGRES\_DB" --clean /tmp/dump.pgc
docker compose restart geonetwork
```

The Elasticsearch index is **derived** — GeoNetwork 4 rebuilds it, so no snapshot is needed. Reindex
from Admin > Tools after restoring.

Attachments and browse graphics are *files*, not rows, so a database dump alone loses them; they
belong in the `gn\_data` volume. `deploy/data-2024/` holds the scrubbed subset that survives.



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

