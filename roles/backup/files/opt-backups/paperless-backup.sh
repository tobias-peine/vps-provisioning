#!/usr/bin/env bash
#
# Paperless-ngx Backup
# Sichert: PostgreSQL-Dump, Daten-Volume, Media-Volume, Export-Ordner, .env
# Ziel:    /opt/backups/paperless/
# Rotation: 7 Tages-Backups + 4 Wochen-Backups
#
set -euo pipefail

STACK_DIR="/opt/stack"
BACKUP_DIR="/opt/backups/paperless"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
TARBALL="${BACKUP_DIR}/paperless-${STAMP}.tar.gz"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$BACKUP_DIR"

log "=== Backup gestartet: ${STAMP} ==="

# 1) PostgreSQL-Dump
log "DB-Dump ..."
docker compose -f "${STACK_DIR}/docker-compose.yml" exec -T paperless-db \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "${WORK}/paperless-db.dump"
log "  -> $(du -h "${WORK}/paperless-db.dump" | cut -f1)"

# 2) Volumes einpacken
log "data-Volume ..."
docker run --rm \
  -v homeserver_paperless_data:/data:ro \
  -v "${WORK}":/out \
  alpine tar czf /out/paperless_data.tar.gz -C /data .

log "media-Volume ..."
docker run --rm \
  -v homeserver_paperless_media:/data:ro \
  -v "${WORK}":/out \
  alpine tar czf /out/paperless_media.tar.gz -C /data .

# 3) Export-Ordner
log "Export-Ordner ..."
if [ -d /opt/paperless/export ]; then
  tar czf "${WORK}/paperless_export.tar.gz" -C /opt/paperless/export .
else
  log "  WARNUNG: /opt/paperless/export nicht gefunden, übersprungen."
fi

# 4) .env
log ".env ..."
cp "${STACK_DIR}/.env" "${WORK}/stack.env"
chmod 600 "${WORK}/stack.env"

# 5) Compose-Dateien
cp "${STACK_DIR}/docker-compose.yml" "${WORK}/docker-compose.yml" 2>/dev/null || true
cp "${STACK_DIR}/docker-compose.override.yml" "${WORK}/docker-compose.override.yml" 2>/dev/null || true

# 6) Tarball
log "Tarball erstellen ..."
tar czf "$TARBALL" -C "$WORK" .
chmod 600 "$TARBALL"
log "  -> ${TARBALL} ($(du -h "$TARBALL" | cut -f1))"

# 7) Rotation
log "Rotation ..."
cd "$BACKUP_DIR"

if [ "$(date +%u)" -eq 7 ]; then
  WEEKLY="paperless-weekly-$(date +%Y-%W).tar.gz"
  cp "$TARBALL" "${BACKUP_DIR}/${WEEKLY}"
  log "  Wochen-Backup: ${WEEKLY}"
fi

ls -1t paperless-2*.tar.gz 2>/dev/null | tail -n +8 | while read -r old; do
  log "  lösche alt: $old"
  rm -f -- "$old"
done

ls -1t paperless-weekly-*.tar.gz 2>/dev/null | tail -n +5 | while read -r old; do
  log "  lösche alt: $old"
  rm -f -- "$old"
done

log "=== Backup fertig: ${TARBALL} ==="
