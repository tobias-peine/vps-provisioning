#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Paperless-ngx Restore-Test
# Testet ein Backup, ohne das produktive System anzufassen.
# ============================================================

BACKUP="${1:-/opt/backups/paperless/paperless-20261025-132648.tar.gz}"
WORK=/tmp/pl-restore-test
PROJ=pl-restore-test
PORT=8001
[ -f /opt/backups/.restore-test.env ] && set -a && . /opt/backups/.restore-test.env && set +a
: "${PGPW:?PGPW nicht gesetzt — .restore-test.env laden oder exportieren}"

log()  { echo "[$(date '+%F %T')] $*"; }
die()  { echo "[$(date '+%F %T')] FEHLER: $*" >&2; exit 1; }

cleanup() {
  log "Raeume Testprojekt auf ..."
  docker compose -p "$PROJ" -f "$WORK/docker-compose.test.yml" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$WORK"
  log "Aufgeraeumt."
}
trap cleanup EXIT

[ -f "$BACKUP" ] || die "Backup nicht gefunden: $BACKUP"
log "=== Restore-Test startet ==="
log "Backup: $BACKUP"

rm -rf "$WORK"
mkdir -p "$WORK/raw" "$WORK/data" "$WORK/media" "$WORK/export" "$WORK/pgdata"

log "Entpacke Tarball ..."
tar xzf "$BACKUP" -C "$WORK/raw"

[ -s "$WORK/raw/paperless-db.dump" ] || die "DB-Dump fehlt oder ist leer"
log "  DB-Dump: $(du -h "$WORK/raw/paperless-db.dump" | cut -f1)"

log "Entpacke Volumes ..."
tar xzf "$WORK/raw/paperless_data.tar.gz"   -C "$WORK/data"   2>/dev/null || true
tar xzf "$WORK/raw/paperless_media.tar.gz"  -C "$WORK/media"  2>/dev/null || true
tar xzf "$WORK/raw/paperless_export.tar.gz" -C "$WORK/export" 2>/dev/null || true
log "  data:   $(du -sh "$WORK/data"   | cut -f1)"
log "  media:  $(du -sh "$WORK/media"  | cut -f1)"
log "  export: $(du -sh "$WORK/export" | cut -f1)"

cat > "$WORK/docker-compose.test.yml" <<YAML
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: $PGPW
    volumes:
      - $WORK/pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U paperless -d paperless"]
      interval: 3s
      timeout: 3s
      retries: 20

  broker:
    image: redis:7

  webserver:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    depends_on:
      db:     { condition: service_healthy }
      broker: { condition: service_started }
    env_file: [ $WORK/raw/stack.env ]
    environment:
      PAPERLESS_DBHOST: db
      PAPERLESS_DBPORT: "5432"
      PAPERLESS_DBNAME: paperless
      PAPERLESS_DBUSER: paperless
      PAPERLESS_DBPASS: $PGPW
      PAPERLESS_REDIS: redis://broker:6379
      PAPERLESS_URL: http://localhost:$PORT
    ports:
      - "$PORT:8000"
    volumes:
      - $WORK/data:/usr/src/paperless/data
      - $WORK/media:/usr/src/paperless/media
      - $WORK/export:/usr/src/paperless/export
YAML

log "Starte DB ..."
docker compose -p "$PROJ" -f "$WORK/docker-compose.test.yml" up -d db

for i in $(seq 1 30); do
    if docker compose -p "$PROJ" -f "$WORK/docker-compose.test.yml" exec -T db psql -U paperless -d paperless -c 'SELECT 1' >/dev/null 2>&1; then
    log "  DB bereit (Versuch $i)."; break
  fi
  [ "$i" -eq 30 ] && die "DB wurde nicht bereit"
  sleep 2
done

log "Spiele DB-Dump ein ..."
docker compose -p "$PROJ" -f "$WORK/docker-compose.test.yml" cp "$WORK/raw/paperless-db.dump" db:/tmp/paperless-db.dump
docker compose -p "$PROJ" -f "$WORK/docker-compose.test.yml" exec -T db pg_restore -U paperless -d paperless --no-owner --no-privileges /tmp/paperless-db.dump || die "pg_restore fehlgeschlagen"

log "Pruefe DB-Inhalt ..."
PSQL="docker compose -p $PROJ -f $WORK/docker-compose.test.yml exec -T db psql -U paperless -d paperless -At"
DOCS=$($PSQL -c "SELECT count(*) FROM documents_document;")
USERS=$($PSQL -c "SELECT count(*) FROM auth_user;")
TAGS=$($PSQL -c "SELECT count(*) FROM documents_tag;")
log "  Dokumente: $DOCS"
log "  Benutzer:  $USERS"
log "  Tags:      $TAGS"
[ "$DOCS" -ge 1 ] || die "Keine Dokumente in der wiederhergestellten DB"
[ "$USERS" -ge 1 ] || die "Keine Benutzer in der wiederhergestellten DB"

log "Starte Webserver ..."
docker compose -p "$PROJ" -f "$WORK/docker-compose.test.yml" up -d webserver broker

log "Warte auf HTTP ..."
OK=0
for i in $(seq 1 120); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/" || true)
  if [ "$CODE" = "200" ] || [ "$CODE" = "302" ] || [ "$CODE" = "301" ]; then
    OK=1; log "  Webserver antwortet (HTTP $CODE) nach $i Versuchen."; break
  fi
  sleep 2
done
[ "$OK" -eq 1 ] || die "Webserver nicht erreichbar nach 240s"

MEDIA_COUNT=$(find "$WORK/media" -type f 2>/dev/null | wc -l)
log "  Media-Dateien: $MEDIA_COUNT"
[ "$MEDIA_COUNT" -ge 1 ] || die "Keine Media-Dateien im wiederhergestellten Volume"

log "=== OK: RESTORE-TEST ERFOLGREICH ==="
log "Testprojekt laeuft auf http://<server-ip>:$PORT bis Skript endet."
log "Pausiere 60 Sekunden zum Anschauen ..."
sleep 60
