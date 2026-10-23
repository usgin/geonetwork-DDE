# Deploying DDE GeoNetwork (geonetwork-DDE)

As of 2026-10-22.

This folder holds everything needed to deploy the DDE catalogue:

| Path | Contents |
| --- | --- |
| `README.md` | This guide: how to build, deploy and verify |
| [HANDOVER.md](HANDOVER.md) | What exists, what is missing, and what must be exported from the old server |
| [harvest-records-2024/](harvest-records-2024/) | The nine DDE seed records and three DDE editor templates from the 2024 catalogue |
| [data-2024/](data-2024/) | Record attachments (`metadata_data/`) and catalogue images (`resources/`) from the 2024 data directory |

## Overview

Build GeoNetwork 4.4.9-0 from [usgin/geonetwork-DDE](https://github.com/usgin/geonetwork-DDE/tree/DDEconfig), branch `DDEconfig`, and run it in Tomcat 9 against PostgreSQL and Elasticsearch 8.14.3. That build already contains everything DDE-specific: the `ddeview` editor, the DDE converters and formatter, the DDE SKOS thesauri and the Elasticsearch mappings. Nothing has to be installed separately.

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
| JDK | 11 (e.g. [Temurin 11](https://adoptium.net/temurin/archive/?version=11)) | Hard requirement. Set `JAVA_HOME` to it explicitly; a newer JDK on the `PATH` causes build errors that look unrelated. |
| Apache Maven | 3.8.3 or later | Build only. |
| Git | any recent | Build only. |
| Apache Tomcat | 9.x | Not Tomcat 10 or later: GeoNetwork 4.4 uses the `javax` servlet API. |
| PostgreSQL | 13 or later | PostGIS is optional. |
| Elasticsearch | 8.14.3 | Match this version; it is pinned in the root `pom.xml` (`es.version`). |
| Kibana | not needed | The fork disables the Kibana health check, so the admin UI works without it. |

Give Tomcat at least 2 GB of heap (`-Xmx2g`) and Elasticsearch at least 1 GB. Allow a few GB of disk for the build and the Maven cache.

## Step 1: Build the war

1. Clone the fork with its submodules (the web UI pulls Bootstrap, Font Awesome and other libraries as submodules, so a plain clone will not build):

```bash
git clone -b DDEconfig --recurse-submodules https://github.com/usgin/geonetwork-DDE.git
cd geonetwork-DDE
```

2. Point Maven at JDK 11 and confirm it:

```bash
export JAVA_HOME=/path/to/jdk-11      # Windows: set JAVA_HOME=C:\path\to\jdk-11
mvn -version                          # must report Java version 11
```

3. Build, skipping tests (expect 15 to 30 minutes the first time while Maven downloads dependencies):

```bash
mvn clean install -DskipTests
```

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

The `es/docker-compose.yml` in the repo turns security off and also starts Kibana. It is fine on a laptop, not on a server.

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

3. Copy `geonetwork.war` into Tomcat's `webapps/` and start Tomcat. The first start takes a few minutes: GeoNetwork creates the database tables (or migrates a restored database), creates the Elasticsearch indices, and populates the empty data directory with the schema plugins, the DDE thesauri and the index configuration.
4. Watch `logs/catalina.out` and `logs/geonetwork.log` until you see the catalogue start without errors, then open `http://<host>:8080/geonetwork`.
5. Sign in as `admin` / `admin` and change that password immediately (top right menu > your profile > Update password). On a restored database, sign in with an existing administrator account instead.

For public access, put Apache or nginx in front of Tomcat with HTTPS, then set the public URL under **Admin console > Settings > Catalog server** (host, port, protocol) so links in records and API responses are correct.

If you deploy the April 2024 `geonetwork.war` instead of a fresh build, the environment variables above are ignored for Elasticsearch: that war has the old host, username and password written into `WEB-INF/config.properties`. After Tomcat expands it, edit `webapps/geonetwork/WEB-INF/config.properties` and set `es.host`, `es.username` and a new `es.password` before the catalogue is used.

## Step 4: Bring up the DDE features

The DDE schema plugin and thesauri arrive with the war, so this step is checking and loading, not installing.

1. **Confirm the schema plugin.** Go to **Admin console > Metadata and templates**. `iso19115-3.2018` should be listed alongside `iso19139`. Dublin Core and ISO 19110 are deliberately left out of this build.
2. **Confirm the DDE thesauri.** Go to **Admin console > Classification systems > Thesaurus**. These six should be listed under `local.theme`: `acquisitioncodeskos`, `resourcetypeskos`, `servicetypeskos`, `topiccategoryskos`, `codelist_unit_distance`, `codelist_unit_time`. The DDE editor's keyword pickers use exactly these names, so a missing one shows up as an empty picker.
3. **Load the standard templates.** On **Admin console > Metadata and templates**, select `iso19115-3.2018` and click **Load templates for selected standards**. Skip this on a restored database, which already has its templates.
4. **Load the DDE templates and seed records** (fresh install only). The three DDE templates and nine seed records in [harvest-records-2024/](harvest-records-2024/) are in the DDE schema, not ISO 19115-3, so they must be converted on import. Go to **Contribute > Import new records**, choose **Upload a file from your computer**, and under **Apply XSLT conversion** pick `fromDDE-any`. Import `DDEDatasetTemplate.xml`, `DDEImageTemplate.xml` and `DDEServiceTemplate.xml` with **Type of record** set to **Template**; import the other nine as **Metadata**. A folder harvester works too: **Admin console > Harvesting > Harvest from > Directory**, pointed at a server folder holding the files, with the same `fromDDE-any` conversion.
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
- [ ] A search for a known seed-record title (for example "Arizona Lithostratigraphy") returns it.
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
| Build fails in `web-ui` with missing files | Submodules were not cloned. Run `git submodule update --init --recursive`. |
| GeoNetwork starts on H2, not PostgreSQL | `-Dgeonetwork.db.type=postgres` is missing from `CATALINA_OPTS`. |
| Search page says the index is unavailable | Elasticsearch host, port or credentials are wrong in `setenv.sh`, or Elasticsearch is not 8.x. |
| DDE view or DDE thesauri missing | An old `schema_plugins` or `codelist` folder in the data directory blocked the new ones (see above). Stop Tomcat, move those folders aside, restart. |
| DDE XML is rejected on import | No conversion was chosen. Pick `fromDDE-any` under Apply XSLT conversion. |

## Open questions

- Will the old database and data directory be exported from the Alibaba Cloud server, or is this a fresh catalogue seeded from the 2024 records?
- What public hostname will the catalogue use, and who provides the HTTPS certificate?
- Who will own upstream updates? GeoNetwork is at 4.4.12; this fork is on 4.4.9.
