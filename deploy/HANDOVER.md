# DDE GeoNetwork redeployment handover

As of 2026-10-22.

The complete GeoNetwork application, the DDE schema customizations and the deployment documentation are all available and listed below. The catalogue content — metadata records, users, permissions and settings — is not: it exists only in the PostgreSQL instance on Alibaba Cloud, which USGIN has never had access to, so it has to be exported by whoever administers that server.

One qualification, added after the deployment was examined more closely: the records that originally seeded the catalogue, and the harvester configuration that loaded them, have both been recovered and are supplied in this folder. What remains unrecoverable is anything created or edited in the catalogue after early 2024, together with the users, permissions and settings.

For step-by-step deployment instructions, see [README.md](README.md) in this folder.

## What USGIN can hand over

All of it exists today and is public on GitHub.

**Start from [usgin/geonetwork-DDE](https://github.com/usgin/geonetwork-DDE), branch `DDEconfig`.** Two forks are listed below and it is the first decision to make, so to be explicit: the newer fork is a strict superset of the DDE work. It carries the same 21 DDE plugin files, the same `ddeview` editor configuration and the same `fromDDE` converters as the 2024 fork, plus three times as many DDE vocabularies (12 thesaurus files against 4). Nothing DDE-specific was lost when CDIF support was added, and the CDIF harvester it adds is simply a harvester type you do not configure — it cannot affect a catalogue that does not use it.

The 2024-era fork is frozen on a 4.4.4 *snapshot* from April 2024, roughly two and a half years behind upstream GeoNetwork (now 4.4.12), and nobody will backport fixes to it. Use it only to reproduce the exact deployed build, or to check what the old code did when something in the recovered catalogue looks wrong.

| Item | Where | Notes |
| --- | --- | --- |
| GeoNetwork fork, current | [usgin/geonetwork-DDE](https://github.com/usgin/geonetwork-DDE), branch `DDEconfig` | RECOMMENDED. GeoNetwork 4.4.9-0 plus a CDIF sitemap harvester. Carries every DDE customization the 2024 fork has, and more recent DDE vocabularies. Build the war from it (see [README.md](README.md)). |
| GeoNetwork fork, as deployed 2024 | [usgin/DDEcore-geonetwork](https://github.com/usgin/DDEcore-geonetwork), branch `DDEconfig` | Reference only. 4.4.4-SNAPSHOT, frozen April 2024, matching the deployed build. History was rewritten to strip a 273 MB war that exceeds GitHub's file limit, so commit hashes differ from the original GitLab. |
| The deployed war file | Not published | The April 2024 binary (286 MB) exceeds GitHub's 100 MB file limit and is not needed: build the war from `DDEconfig` instead. Its `WEB-INF/config.properties` carries the 2024 Elasticsearch host and credentials; anyone who does obtain it must set a new password there at deploy. |
| Record files from the 2024 data directory | [data-2024/](data-2024/) | `metadata_data/` (record attachments) and `resources/` (logos and images), scrubbed of `encryptor.properties` and cache databases. Copy these into the new data directory; nothing else from the old data directory is needed. |
| DDE metadata standard | [usgin/dde-metadata](https://github.com/usgin/dde-metadata) | XSD, specification document, worked examples, ISO 19115-3 crosswalks, and the two July 2024 deployment PDFs. |
| DDE vocabularies | In the fork: `web/src/main/webapp/WEB-INF/data/config/codelist/local/thesauri/theme/` | SKOS thesauri as RDF and Turtle: resource type, topic category, acquisition code, unit codelists. |
| Elasticsearch index mappings | In the fork: `web/.../WEB-INF/data/config/index/` | `records.json`, `features.json`, `searchlogs.json`. |
| Harvest configuration and seed records | [harvest-records-2024/](harvest-records-2024/) | Twelve DDE-schema XML files (nine harvested records, three editor templates) plus a sample harvester log. Recovered from the 2024 deployment; see the harvest section below. |

The DDE customizations are concentrated in the ISO 19115-3:2018 schema plugin at `schemas/iso19115-3.2018/src/main/plugin/iso19115-3.2018/` — the editor view, converters, formatter, indexing and labels. Cloning the fork brings all of it.

## What is missing, and why

Three things were asked for that USGIN cannot supply.

**No PostgreSQL backup.** The catalogue database ran on an Alibaba Cloud instance provisioned on the DDE side. USGIN has never had access to that server, and the local test deployment used GeoNetwork's embedded H2 store rather than that PostgreSQL instance, so no copy of the production database was ever held here.

**No Elasticsearch snapshot.** None was ever taken here. This is the least consequential gap: see the next section.

**The original GitLab is gone.** The repositories were hosted at `opencode.deep-time.org`, which now refuses connections on both ports 80 and 443 while the rest of the DDE web estate responds normally — it appears to have been decommissioned. Everything that was on it has been mirrored to GitHub, with one exception: a release copy of the war was stored there using git-LFS, and that LFS object is unrecoverable. It does not matter, because the war can be rebuilt from source.

If a copy of the production database exists anywhere, it is on the Alibaba Cloud instance or with whoever administers it.

## What must be exported from the running deployment

Two exports are needed, both from the existing server, and both only obtainable by whoever has access to it.

1. **The PostgreSQL database**, via `pg_dump` of the GeoNetwork database. This single dump carries metadata records, users, groups, permissions and settings — they all live in these tables. A custom-format dump is easiest to restore: `pg_dump -Fc -d <database> -f geonetwork.dump`.
2. **The GeoNetwork data directory** from the server's filesystem, the path that `geonetwork.dir` points at. Uploaded attachments and browse-graphic images are stored as files here, **not** in the database, so a database dump alone loses them.

**An Elasticsearch snapshot is not required.** GeoNetwork 4 treats Elasticsearch as a derived index, not a system of record: once the database is restored and the application is pointed at a fresh Elasticsearch, the index is rebuilt from the database through the admin console. Plan to reindex rather than to restore a snapshot.

### Credentials

Use new credentials on the new server rather than carrying any across from the 2024 deployment. The two July 2024 deployment notes contain Elasticsearch passwords in plain text, and the 2024 war has them in `WEB-INF/config.properties`. Set new database and Elasticsearch passwords at deploy.

## Harvest configuration, and the records it loaded

Harvest configurations are **database rows**, not files: GeoNetwork moved harvester settings into the database at version 2.11, and they live under the `harvesting/` settings tree (the 2024 logs show paths such as `harvesting/id:277/info/lastRun`). They are therefore in the same PostgreSQL database as the records, and are not in the war file.

Both the configuration and the source records were nevertheless recovered from the 2024 deployment, out of the harvester run logs it left behind.

| Setting | Value |
| --- | --- |
| Harvesters | Two: `local DDE` and `clone: local DDE` |
| Type | `LocalFilesystemHarvester` |
| Source directory | A local folder on a developer workstation, `recurse = true` |
| Schema | `iso19115-3.2018` after conversion (see below) |
| Owner | `ownerId = 1` |
| Active | 2024-02-09 to 2024-04-02, 29 logged runs |

**There is no remote harvest endpoint to recover.** The catalogue was not harvested from a CSW, OAI-PMH or sitemap service: it was loaded from a folder of XML files on a developer workstation. Reproducing the harvester is a matter of creating a local filesystem harvester in the admin console and pointing it at a directory — no URLs, schedules or credentials are involved.

### The seed records

Nine records were harvested. All twelve files below are in [harvest-records-2024/](harvest-records-2024/), together with one sample harvester log.

| File | Harvested |
| --- | --- |
| `ArizonaLithostratigraphyOneGeologyDDE.xml` | yes |
| `CHN-CGS-EN-BedrockLithostratigraphyDDE.xml` | yes |
| `EIPExample_g01065-DDE.xml` | yes |
| `ISO19115-3ServiceExampleDDE.xml` | yes |
| `MultibeamDataAustralia-DDE.xml` | yes |
| `TestingMetadata-DDE.xml` | yes |
| `arctichydrology-DDE.xml` | yes |
| `minimalInstanceDDE.xml` | yes |
| `ddeTransformTest-DDE.xml` | yes (recovered from usgin/dde-metadata `ExampleXML/`) |
| `DDEDatasetTemplate.xml` | no — editor template |
| `DDEImageTemplate.xml` | no — editor template |
| `DDEServiceTemplate.xml` | no — editor template |

**These files are in the DDE schema, not ISO 19115-3.** Their root element is `MD_Metadata` in namespace `https://www.ddeworld.org/resource/standards/dde/ds01/metadata/1.0`, and GeoNetwork converts them on import using the `fromDDE` XSLTs in the DDE schema plugin. A stock GeoNetwork will reject them — re-harvesting requires the fork.

Three limits on what this recovers. The records are **as they were in early 2024**: anything created or edited in the catalogue interface after that exists only in the PostgreSQL database. The three templates were never harvested and are normally loaded as template records rather than ordinary ones, so they need registering as templates after import. And record identifiers assigned by the catalogue on first import will differ from the originals unless the database is restored, which matters if anything external cites them.

## Versions and prerequisites

| Component | As deployed, April 2024 | Current fork |
| --- | --- | --- |
| GeoNetwork | 4.4.4-SNAPSHOT | 4.4.9-0 |
| Java | JDK 11 | JDK 11 |
| Servlet container | Apache Tomcat 9.0.85 | Tomcat 9.x, or Jetty for development |
| Elasticsearch | 8.11.3 | 8.14.3 |
| Kibana | 8.11.3, optional | not required |
| Database | PostgreSQL on Alibaba Cloud | PostgreSQL |
| Build | Apache Maven, `mvn clean install -DskipTests` | same |

JDK 11 is a hard requirement for this GeoNetwork line; a newer JDK on the `PATH` produces build failures that look unrelated to the cause, so set `JAVA_HOME` explicitly. Upstream GeoNetwork is now at 4.4.12, so moving to the current fork and then taking upstream patches is the lower-maintenance path.

Kibana was used only to inspect Elasticsearch during development and is not needed to run the catalogue.

## Restore sequence

The order matters: the database must be in place before the application first starts against it, and the index is built last. [README.md](README.md) gives the commands for each step.

1. Install JDK 11, PostgreSQL, Elasticsearch, and Tomcat 9 on the new server. Start Elasticsearch and confirm it answers.
2. Restore the PostgreSQL dump into an empty database, then create the GeoNetwork database user and grant it ownership.
3. Build the war from the fork with `mvn clean install -DskipTests`, which produces `web/target/geonetwork.war`.
4. Configure the database connection and the Elasticsearch host and credentials, using **new** credentials. With the `DDEconfig` build these are environment variables in Tomcat's `setenv.sh`.
5. Copy only the record content from the old data directory into the new one: `data/metadata_data` (record attachments and thumbnails) and `data/resources` (logos and images). Do not copy `config/schema_plugins`, `config/codelist` or `config/index`: GeoNetwork never overwrites an existing plugin or non-empty thesaurus folder, so old copies would block the DDE plugin and the 12 thesaurus files the new build installs itself. With a restored database, also bring `config/encryptor.properties` from the old server, which decrypts harvester passwords stored in it.
6. Deploy the war to Tomcat's `webapps/` and start Tomcat. The catalogue serves at `http://<host>:8080/geonetwork`.
7. Rebuild the search index from the admin console, then confirm record counts match the database and that the DDE editor view and thesauri load.

The two July 2024 notes in [usgin/dde-metadata](https://github.com/usgin/dde-metadata) walk through steps 1 and 4 in more detail. They describe a Windows development machine, so paths and service management will differ on a Linux server, but the sequence is the same.

### Open questions for the migration team

- Who administers the Alibaba Cloud PostgreSQL and Elasticsearch instances, and can they produce the two exports above?
