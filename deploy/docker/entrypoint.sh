#!/bin/sh
# Assemble CATALINA_OPTS, then refuse to start if the database configuration is
# the kind that fails silently.
#
# GeoNetwork reads its database settings from TWO mechanisms, and mixing them up
# produces a catalogue that starts perfectly on the wrong store:
#
#   environment variables   GEONETWORK_DB_HOST / PORT / NAME / USERNAME /
#                           PASSWORD. Spring resolves these with
#                           #{systemEnvironment['...']}, so passing them as -D
#                           does nothing at all.
#   -D system properties    geonetwork.db.type, geonetwork.dir, file.encoding.
#
# With GEONETWORK_DB_* unset the baked fallbacks are an H2 file at ~/gn with
# user and password www-data, and config-node/srv.xml imports
# config-db/${geonetwork.db.type:h2}.xml — so a missing setting is a silent
# success on H2, not an error. That is why the checks below are hard failures.
set -e

fail() { echo "ERROR: $*" >&2; exit 1; }

# --- the database configuration must be complete ---------------------------
# GEONETWORK_DB_PORT has NO baked default. Unset, it yields the URL
# jdbc:postgresql://localhost:/geonetwork? and an error that names
# org.postgresql.Driver — pointing at the driver rather than the missing port.
for v in GEONETWORK_DB_HOST GEONETWORK_DB_PORT GEONETWORK_DB_NAME \
         GEONETWORK_DB_USERNAME GEONETWORK_DB_PASSWORD; do
  eval "value=\${$v:-}"
  [ -n "$value" ] || fail "$v is not set. All five GEONETWORK_DB_* variables are
       required: unset ones fall back to an H2 file at ~/gn with user www-data,
       which starts successfully and silently on the wrong database.
       GEONETWORK_DB_PORT in particular has no default at all."
done

# The encryptor key. Without it GeoNetwork writes a random one into the data
# directory and that file becomes irreplaceable: lose the volume and every
# stored credential is undecryptable, database dump or not. Checked here as
# well as in compose so that running the image directly cannot skip it.
[ -n "${ENCRYPTOR_PASSWORD:-}" ] || fail "ENCRYPTOR_PASSWORD is not set. GeoNetwork would
       generate a random key into <data dir>/config/encryptor.properties, which
       then has to be backed up separately for the volume to be restorable."

: "${GEONETWORK_DB_TYPE:=postgres}"
if [ "$GEONETWORK_DB_TYPE" != "postgres" ]; then
  echo "WARNING: GEONETWORK_DB_TYPE=$GEONETWORK_DB_TYPE, not postgres." >&2
  echo "         This image is built for PostgreSQL; h2 is for throwaway use." >&2
fi

# --- Elasticsearch ---------------------------------------------------------
: "${GEONETWORK_ES_PROTOCOL:=http}"
: "${GEONETWORK_ES_HOST:=elasticsearch}"
: "${GEONETWORK_ES_PORT:=9200}"
export GEONETWORK_ES_PROTOCOL GEONETWORK_ES_HOST GEONETWORK_ES_PORT

# --- the directory the war names for its wro4j sources ---------------------
# web/pom.xml sets build.webapp.resources to ${project.build.directory}/webapp,
# and WEB-INF/wro.properties is filtered with it, so the deployed war names an
# absolute path on the BUILD machine — a directory that does not exist here.
# Harmless while the prebuilt cache answers every request, but a cache miss
# would reach for it, so create whatever the war actually asks for rather than a
# path hardcoded here.
WRO_PROPS=/usr/local/tomcat/webapps/geonetwork/WEB-INF/wro.properties
if [ -f "$WRO_PROPS" ]; then
  wro_sources=$(sed -n 's/^wroSources[[:space:]]*=[[:space:]]*//p' "$WRO_PROPS" | head -1)
  case "$wro_sources" in
    /*) wro_dir=$(dirname "$wro_sources")
        if [ ! -d "$wro_dir" ]; then
          echo "INFO: creating $wro_dir, the build-machine path baked into wro.properties"
          mkdir -p "$wro_dir" || echo "WARNING: could not create $wro_dir" >&2
        fi ;;
  esac
fi

# --- CATALINA_OPTS ---------------------------------------------------------
CATALINA_OPTS="${CATALINA_OPTS:-} ${GN_HEAP:--Xms1g -Xmx2g}"
CATALINA_OPTS="$CATALINA_OPTS -Dgeonetwork.dir=${GN_DATA_DIR:-/var/lib/geonetwork_data}"
CATALINA_OPTS="$CATALINA_OPTS -Dgeonetwork.db.type=${GEONETWORK_DB_TYPE}"
CATALINA_OPTS="$CATALINA_OPTS -Dfile.encoding=UTF-8"
export CATALINA_OPTS

echo "GeoNetwork-DDE starting"
echo "  database   ${GEONETWORK_DB_TYPE} at ${GEONETWORK_DB_HOST}:${GEONETWORK_DB_PORT}/${GEONETWORK_DB_NAME} as ${GEONETWORK_DB_USERNAME}"
echo "  search     ${GEONETWORK_ES_PROTOCOL}://${GEONETWORK_ES_HOST}:${GEONETWORK_ES_PORT}"
echo "  data dir   ${GN_DATA_DIR:-/var/lib/geonetwork_data}"
echo "  heap       ${GN_HEAP:--Xms1g -Xmx2g}"
echo "  encryptor  key supplied from ENCRYPTOR_PASSWORD (value not printed)"
echo "  (the password is not printed; check it in .env if authentication fails)"

exec "$@"
