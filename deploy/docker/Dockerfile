# GeoNetwork-DDE 4.4.9-0 — build the war, then serve it on Tomcat.
#
# Build context is the REPOSITORY ROOT, not this directory, because the war is
# built from the whole multi-module tree:
#
#   docker build -f deploy/docker/Dockerfile -t dde-geonetwork:4.4.9-0 .
#
# or, normally, through deploy/docker/docker-compose.yml, which sets that up.
#
# The build asserts two things about the war it produced rather than trusting
# that the flags took effect — see the ASSERT steps in the builder stage. Both
# are properties that fail silently and expensively if lost.

# ---------------------------------------------------------------------------
# Stage 1: build the war
# ---------------------------------------------------------------------------
# Temurin 11: pom.xml's enforcer requires [11.0.25,12), so this stage fails
# loudly on an image carrying an older 11 or a newer major. That check is the
# reason this does not need to pin a patch version here.
FROM maven:3.9.9-eclipse-temurin-11 AS builder

# Maven settings mirroring the retired oss.sonatype.org to Central. web/pom.xml
# still routes four org.webjars.npm artifacts (wrappy, minimatch, once,
# inflight) through OSSRH, which is retired and 302-redirects; without this the
# build fails on a redirect whose error names neither the repository nor the
# artifacts. See deploy/README.md Step 1.
COPY deploy/docker/maven-settings.xml /usr/share/maven/conf/settings.xml

WORKDIR /build
COPY . .

# -Dprebuild-cache=true  builds the wro4j web-resource cache and packages it at
#                        WEB-INF/prebuilt/wro4j-cache.mv.db. Measured on Tomcat
#                        9.0.85: without it the first ever request for
#                        gn_search_default.css takes 16.4 s and the .js 429.5 s,
#                        against ~5 ms with it. A container starts cold every
#                        time, so this is not optional here.
# -Dwro.debug=false      wro.debug defaults to true in pom.xml and NO profile
#                        sets it false, so every war ships in debug mode unless
#                        this is passed. It lands in WEB-INF/wro.properties.
RUN set -eux; \
    mvn --batch-mode --no-transfer-progress package \
        -pl web -am -DskipTests \
        -Dprebuild-cache=true -Dwro.debug=false

# ASSERT 1: the wro4j cache is actually inside the war.
# The prebuild runs in the prepare-package phase and the cache is copied in as a
# web resource; if either step is skipped the war is still valid and still
# deploys, and the cost only appears as a 7-minute first request in production.
RUN set -eux; \
    war=/build/web/target/geonetwork.war; \
    test -f "$war" || { echo "FAIL: $war was not produced"; exit 1; }; \
    unzip -l "$war" | grep -q 'WEB-INF/prebuilt/wro4j-cache.mv.db' \
      || { echo "FAIL: wro4j prebuild cache missing from the war."; \
           echo "      -Dprebuild-cache=true did not take effect."; exit 1; }; \
    echo "OK: wro4j prebuild cache is packaged"

# ASSERT 2: wro4j is not in debug mode.
RUN set -eux; \
    cd /tmp && rm -rf wrocheck && mkdir wrocheck && cd wrocheck; \
    unzip -o -q /build/web/target/geonetwork.war 'WEB-INF/wro.properties'; \
    grep -E '^debug[[:space:]]*=[[:space:]]*false[[:space:]]*$' WEB-INF/wro.properties \
      || { echo "FAIL: WEB-INF/wro.properties does not say debug=false:"; \
           grep -E '^debug' WEB-INF/wro.properties || true; exit 1; }; \
    echo "OK: wro.debug=false is baked in"

# ---------------------------------------------------------------------------
# Stage 2: runtime
# ---------------------------------------------------------------------------
# 9.0.85 is the version the wro4j timings above were measured on.
FROM tomcat:9.0.85-jdk11-temurin

# Tomcat's own sample applications are not wanted on a public server.
RUN rm -rf /usr/local/tomcat/webapps/*

# curl for the HEALTHCHECK below. Installed rather than assumed: whether the
# tomcat image ships it is not something to find out from a container that
# reports unhealthy while working perfectly.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl; \
    rm -rf /var/lib/apt/lists/*

# The data directory holds uploaded files, thumbnails, schema plugins, the DDE
# thesauri and the index configuration. It lives outside webapps/ so that
# redeploying the war never touches it, and is a named volume in compose.
ENV GN_DATA_DIR=/var/lib/geonetwork_data
RUN mkdir -p "$GN_DATA_DIR"

COPY --from=builder /build/web/target/geonetwork.war /usr/local/tomcat/webapps/geonetwork.war
COPY deploy/docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Heap. Overridable per deployment; sized for a host with 8 GB once
# Elasticsearch and PostgreSQL have taken their share.
ENV GN_HEAP="-Xms1g -Xmx2g"

EXPOSE 8080

# A 200 from the search endpoint, which exercises Tomcat, the database and
# Elasticsearch together — unlike a request for the landing page, which would
# pass while the catalogue was broken underneath. start-period covers first
# start, measured at about 65 s on 9.0.85 with an empty data directory (table
# creation, index creation, data directory population).
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
  CMD curl -fsS -H 'Accept: application/json' \
      'http://localhost:8080/geonetwork/srv/api/search/records/_search?bucket=bucket' \
      -X POST -H 'Content-Type: application/json' -d '{"size":0}' > /dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["catalina.sh", "run"]
