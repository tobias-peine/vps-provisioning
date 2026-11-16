#!/usr/bin/env bash
# DB-Dump + Ghost-Inhalte nach $BACKUP_DIR (Standard: neben diesem Skript).
set -euo pipefail
BACKUP_DIR="${BACKUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"
TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

docker exec kisium-mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction --quick --routines --events ghost' \
  | gzip > "$BACKUP_DIR/ghost-db-$TS.sql.gz"
log "DB: ghost-db-$TS.sql.gz"

VOL="$(docker volume ls -q | grep -E 'ghost_content$' | head -n1 || true)"
if [[ -n "$VOL" ]]; then
  docker run --rm -v "$VOL":/data:ro -v "$BACKUP_DIR":/backup \
    alpine:3.20 tar czf "/backup/ghost-content-$TS.tar.gz" -C /data .
  log "Content: ghost-content-$TS.tar.gz"
fi

find "$BACKUP_DIR" -type f -name 'ghost-*' -mtime +"$KEEP_DAYS" -delete
log "Fertig."
