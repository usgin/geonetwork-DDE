# VM requirements for the DDE-GeoNetwork deployment

A specification for a machine to host the GeoNetwork 4.4.9-0 catalogue. Every figure below is
derived from measurements of a running GeoNetwork deployment, not from generic sizing.

The catalogue is deployed as a Docker Compose stack — see [`docker/README.md`](docker/README.md) —
so the host needs Docker and little else.

> Host-specific material — addresses, hostnames, and findings about the machine currently running
> the catalogue — is **not in this repository**. It is in `deploy/site-notes/`, which is gitignored
> because this repository is public. Read that alongside this file; send it by mail, not by commit.

## Summary

| | request | minimum | basis |
|---|---|---|---|
| vCPU | 4 | 2 | the existing deployment runs on 4 and copes; the peaks are reindexing and harvesting |
| **RAM** | **16 GB** | **8 GB** | see below — 8 GB is the floor, not the target |
| Disk | 100 GB SSD | 50 GB | ~3.5 GB of images, a 285 MB war, plus uploads and index growth |
| Swap | 4 GB | — | a JVM heap spike with no swap gets something killed |
| OS | Ubuntu 24.04 LTS | Ubuntu 22.04 LTS / Debian 12 | 20.04 left standard support in April 2025 |
| Architecture | x86_64 (amd64) | — | avoids surprises with ARM instance types |
| Docker | Engine 24+ **with the Compose v2 plugin** | — | see the note below; this is easy to get wrong |
| Backups | provider snapshots enabled before cutover | — | |

### Where the RAM figure comes from

Measured from a running GeoNetwork deployment of comparable scope:

| process | heap | resident |
|---|---|---|
| GeoNetwork Tomcat 9 | `-Xms2g -Xmx2g` | 2.9 GB |
| Elasticsearch 8.x | `-Xms2g -Xmx2g` | 2.6 GB |

Elasticsearch wants filesystem cache for Lucene on top of its heap, and this stack adds PostgreSQL
and nginx. So:

```
  3 GB  catalogue (Tomcat, 2 GB heap)
  3 GB  Elasticsearch (2 GB heap plus cache)
  1 GB  PostgreSQL
  1 GB  OS and Docker daemon
 ------
  8 GB  in use with nothing spare
```

That makes **8 GB the floor**. 16 GB is the number that survives a reindex, a harvest and a
`docker build` without swapping.

### Docker: ask for the official packages

Ubuntu's own `docker.io` packages do **not** include the Compose v2 plugin — `docker compose` is not
a recognised command with them. Either:

- install from Docker's own apt repository (`docker-ce` + `docker-compose-plugin`), or
- state that Docker is not required and we will install it.

Do **not** mix Docker's apt repo with the distribution's packages on the same host; that causes
package conflicts. The deprecated `docker-compose` v1 (hyphenated, Python) is not sufficient: it
requires a `version:` key that Compose v2 treats as obsolete, and it will misread our compose file.

## Network

| direction | port | exposure |
|---|---|---|
| inbound | 443 | public |
| inbound | 80 | public, redirect to 443 only |
| inbound | 22 | restricted to known source addresses if possible |
| outbound | 443 | required |
| — | 9200, 5432 | **never public** |

Outbound HTTPS is needed for harvesting remote CDIF sitemaps, resolving `w3id.org` conformance
URIs, and pulling container images. Elasticsearch and PostgreSQL stay on the private Docker
network and must not be published.

Also needed: a public IP, **DNS control for a hostname**, and either an existing certificate or the
ability to issue one. If a certificate is to be issued automatically, port 80 must be reachable
from the internet. Confirm that the chosen hostname's DNS record actually points at the new machine
before cutover — a name pointing at the wrong host is indistinguishable from an outage.

## Access

- `root`, or an account with full `sudo`
- **SSH key authentication rather than a password.** A password-authenticated root account on a
  public address is the single highest-risk configuration a host of this kind can have.

## Why a dedicated machine

This is the substantive request; the hardware figures are the easy part.

The catalogue's current host is shared, and the catalogue is not its largest tenant: unrelated
services hold more memory than the catalogue and its search engine combined, a third-party agent
runs under another user account, and provider backup jobs compete for I/O on the root filesystem.
`deploy/site-notes/` has the specifics.

All of that shares a blast radius with the catalogue: a restart, an OOM kill or a compromise of any
tenant affects the others, and none of it is ours to manage. A separate machine is cheaper than the
first incident.

## Questions to answer alongside the machine

**1. Where is the current catalogue's database?** This decides the migration plan and is not
answerable from outside the host. On the running deployment, `config.properties` carries no JDBC
settings and the Tomcat command line shows no `-Dgeonetwork.db.type` — which defaults to **H2** —
so the catalogue may be running on an embedded H2 file on that disk. If so the entire export is a
file copy. If it is a managed PostgreSQL instance instead, we need the endpoint and credentials.

`HANDOVER.md` has described the database and the data directory as obtainable only from whoever
administers the hosting account. Whoever that is should answer this one.

**2. A maintenance window** for cutover. Stopping the existing Tomcat service and its Elasticsearch
container is a brief outage on a public site.

**3. Who owns the other services on the current host**, if the new catalogue is to share a machine
after all.

## Migration constraints

**`db.migration_onstartup=true`, and GeoNetwork's schema migration is one-way.** The deployed war
is a 4.4.4-era build; this stack is 4.4.9-0. Pointing 4.4.9-0 at the existing database would
migrate its schema with no downgrade path, after which the old war could no longer read it. So the
migration must **restore a copy** into this stack's own PostgreSQL and leave the original untouched.
That is what preserves the ability to roll back by restarting the old service.

**The Elasticsearch index is derived, not authoritative.** GeoNetwork 4 rebuilds it, so no snapshot
is needed and the new stack should reindex from scratch into 8.14.3 rather than migrating an index
from an older Elasticsearch.

**Attachments and browse graphics are files, not rows.** A database dump alone loses them; they
live in the data directory and belong in the stack's `gn_data` volume.

## If no new machine is available

The fallback works. Cutting over on the existing host frees the memory held by the old Tomcat and
Elasticsearch the moment they stop, which is enough for the new stack. The costs are a shared blast
radius, no margin to run both deployments side by side for comparison, and a rollback that depends
on nothing else having claimed the memory in the meantime.
