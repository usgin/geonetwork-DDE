#!/usr/bin/env bash
#
# Redeploy GeoNetwork-DDE on the server from a war or a saved image.
#
#   ./redeploy.sh /root/geonetwork.war
#   ./redeploy.sh /root/dde-geonetwork-4.4.9-0.tar.gz
#
# Run it from the compose directory, or pass --compose-dir. Everything it does
# by hand is in README.md under "Upgrading to a new image"; this just does it in
# the right order and refuses to continue when a step did not actually work.
#
# The steps that look optional and are not:
#
#   * Schema plugins are loaded from the DATA DIRECTORY, not the war, and
#     GeonetworkDataDirectory only copies a plugin in when it is missing. A
#     plugin left in the volume keeps its old XSLTs while everything else looks
#     correct. Delete every plugin the release changed -- see --plugins.
#   * The formatter cache serves rendered output from the old XSLTs.
#   * The wro4j cache is NOT deleted. GeonetworkWrojManagerFactory:133 replaces
#     it when the war's git.commit.id differs from the one in the data
#     directory, so a new build refreshes it; deleting it costs a 16 s first
#     request for the CSS and 430 s for the JS.
#   * API calls need `Accept: application/json`. The API negotiates on content
#     type and answers `*/*` -- curl's default -- with a 500 that is logged
#     nowhere.

set -euo pipefail

IMAGE_TAG="dde-geonetwork:4.4.9-0"
COMPOSE_DIR="$(pwd)"
PLUGINS="iso19115-3.2018 iso19139"
GN_PORT="8080"
SKIP_BACKUP="no"
ARTIFACT=""

DATA_DIR="/var/lib/geonetwork_data"

usage() {
  cat <<'EOF'
Usage: redeploy.sh <artifact> [options]

  <artifact>              a .war to build an image from, or a .tar.gz to load

  --compose-dir DIR       directory holding docker-compose.yml and .env
                          (default: the current directory)
  --plugins "A B"         schema plugins to remove from the data directory
                          (default: "iso19115-3.2018 iso19139"; "" removes none)
  --image TAG             image tag to build or expect (default: dde-geonetwork:4.4.9-0)
  --port PORT             published catalogue port for the checks (default: 8080)
  --skip-backup           do not run pg_dump first
  -h, --help              this text
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --compose-dir) COMPOSE_DIR="$2"; shift 2 ;;
    --plugins)     PLUGINS="$2"; shift 2 ;;
    --image)       IMAGE_TAG="$2"; shift 2 ;;
    --port)        GN_PORT="$2"; shift 2 ;;
    --skip-backup) SKIP_BACKUP="yes"; shift ;;
    -h|--help)     usage; exit 0 ;;
    -*)            echo "unknown option: $1" >&2; usage; exit 2 ;;
    *)             ARTIFACT="$1"; shift ;;
  esac
done

step() { printf '\n== %s\n' "$*"; }
die()  { printf '\nFAILED: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight

[ -n "$ARTIFACT" ] || { usage; exit 2; }
[ -f "$ARTIFACT" ] || die "no such file: $ARTIFACT"
[ -f "$COMPOSE_DIR/docker-compose.yml" ] || die "no docker-compose.yml in $COMPOSE_DIR"
command -v docker >/dev/null || die "docker is not on PATH"

cd "$COMPOSE_DIR"

step "Artifact"
ls -l "$ARTIFACT"
sha256sum "$ARTIFACT"

# ---------------------------------------------------------------- backup

if [ "$SKIP_BACKUP" = "yes" ]; then
  step "Database backup SKIPPED at your request"
else
  DUMP="$PWD/gn-db-$(date +%Y-%m-%dT%H%M%S).dump"
  step "Backing up the database to $DUMP"
  # Credentials come from the container's own environment, so nothing is typed
  # here and nothing lands in the shell history.
  docker compose exec -T postgres \
    sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$DUMP"
  [ -s "$DUMP" ] || die "the dump is empty"
  PG_IMAGE="$(docker compose images -q postgres)"
  docker run --rm -v "$PWD:/backup:ro" "$PG_IMAGE" \
    pg_restore -l "/backup/$(basename "$DUMP")" > /dev/null \
    || die "pg_restore cannot read the dump -- it is not a backup"
  echo "verified: $(du -h "$DUMP" | cut -f1), table of contents reads cleanly"
fi

# ---------------------------------------------------------------- image

case "$ARTIFACT" in
  *.war)
    [ -f Dockerfile.prebuilt ] || die "Dockerfile.prebuilt is not in $COMPOSE_DIR"
    step "Building $IMAGE_TAG from $(basename "$ARTIFACT")"
    BUILD_CTX="$(mktemp -d)"
    trap 'rm -rf "$BUILD_CTX"' EXIT
    cp "$ARTIFACT" "$BUILD_CTX/geonetwork.war"
    cp Dockerfile.prebuilt entrypoint.sh "$BUILD_CTX/"
    docker build -f "$BUILD_CTX/Dockerfile.prebuilt" -t "$IMAGE_TAG" "$BUILD_CTX" \
      || die "image build failed -- its own assertions cover the wro4j cache and wro.debug"
    ;;
  *.tar.gz|*.tgz|*.tar)
    step "Loading $(basename "$ARTIFACT")"
    docker load -i "$ARTIFACT"
    ;;
  *)
    die "expected a .war or a .tar.gz, got $(basename "$ARTIFACT")"
    ;;
esac

step "Image now tagged $IMAGE_TAG"
docker images "${IMAGE_TAG%%:*}" --no-trunc --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
  | grep -F "$IMAGE_TAG" || die "$IMAGE_TAG is not in the image store"

# ---------------------------------------------------------------- swap

step "Stopping the catalogue (Postgres and Elasticsearch keep running)"
docker compose stop geonetwork

step "Clearing derived files from the data directory"
# One throwaway container so the volume name never has to be guessed.
# shellcheck disable=SC2016
docker compose run --rm --entrypoint sh geonetwork -c '
  set -eu
  d="'"$DATA_DIR"'"
  rm -f "$d/config/schemaplugin-uri-catalog.xml"
  for p in '"$PLUGINS"'; do
    echo "removing plugin $p"
    rm -rf "$d/config/schema_plugins/$p"
  done
  rm -rf "$d/data/resources/htmlcache/formatter-cache"
  echo "--- plugins left in place:"
  ls "$d/config/schema_plugins"
  echo "--- htmlcache (wro4j-cache.mv.db must still be here):"
  ls -l "$d/data/resources/htmlcache"
' || die "could not clear the data directory"

step "Starting the catalogue"
docker compose up -d

# ---------------------------------------------------------------- verify

step "Waiting for the catalogue to answer"
ready="no"
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' \
    -H 'Accept: application/json' \
    "http://localhost:$GN_PORT/geonetwork/srv/api/site" || true)"
  if [ "$code" = "200" ]; then ready="yes"; break; fi
  sleep 5
done
[ "$ready" = "yes" ] || die "no 200 from /srv/api/site after 5 minutes -- check: docker compose logs geonetwork"
echo "/srv/api/site answered 200"

step "Checking the plugins were re-copied from the new war"
# shellcheck disable=SC2016
docker compose exec -T geonetwork sh -c '
  set -eu
  d="'"$DATA_DIR"'"
  ls "$d/config/schema_plugins"
  ls -l "$d/config/schemaplugin-uri-catalog.xml"
'
for p in $PLUGINS; do
  docker compose exec -T geonetwork test -d "$DATA_DIR/config/schema_plugins/$p" \
    || die "plugin $p was not re-copied -- the new XSLTs are not live"
done
echo "every removed plugin is back"

cat <<EOF

== Done

The catalogue is up on port $GN_PORT with $IMAGE_TAG.

A reindex is needed after a change to index-fields/, or after changing the
server host. It is NOT needed for a formatter or web-asset change. Run it
against the container rather than through the admin console: the request is
synchronous, so a full rebuild outlasts nginx's proxy_read_timeout and the
console reports "rebuildIndexError" and a 504 while the reindex carries on.

  curl -s -c /tmp/c.txt -u admin -H "Accept: application/json" \\
    http://localhost:$GN_PORT/geonetwork/srv/api/me > /dev/null \\
  && T=\$(awk '/XSRF-TOKEN/ {print \$7}' /tmp/c.txt) \\
  && curl -s -X PUT -b /tmp/c.txt -H "X-XSRF-TOKEN: \$T" \\
       -u admin -H "Accept: application/json" \\
       "http://localhost:$GN_PORT/geonetwork/srv/api/site/index?reset=false&asynchronous=true"

reset=false matters: the parameter defaults to true, which drops and recreates
the index instead of updating documents in place.
EOF
