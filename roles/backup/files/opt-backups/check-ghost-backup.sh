#!/usr/bin/env bash
# Prüft das Alter des neuesten Ghost-Backups und alarmiert per ntfy.
#
#   ./scripts/check-backup-age.sh
#   BACKUP_DIR=/opt/kisium/backups MAX_AGE_H=26 ./scripts/check-backup-age.sh
#
# Cron auf dem Server:
#   0 5 * * * root /opt/backups/check-ghost-backup.sh >> /var/log/ghost-backup-check.log 2>&1
#
# Exit 0 = frisch, Exit 1 = fehlt/zu alt (und ntfy-Nachricht).
set -Eeuo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/kisium/backups}"
TOPIC_FILE="${TOPIC_FILE:-/opt/backups/.ntfy-topic}"
MAX_AGE_H="${MAX_AGE_H:-26}"

[ -r "$TOPIC_FILE" ] || { echo "FEHLER: $TOPIC_FILE fehlt"; exit 1; }
TOPIC="$(tr -d '[:space:]' < "$TOPIC_FILE")"
[ -n "$TOPIC" ] || { echo "FEHLER: ntfy-Thema leer"; exit 1; }

LATEST="$(ls -1t "$BACKUP_DIR"/ghost-db-*.sql.gz 2>/dev/null | head -n 1 || true)"
CONTENT="$(ls -1t "$BACKUP_DIR"/ghost-content-*.tar.gz 2>/dev/null | head -n 1 || true)"
if [ -z "$LATEST" ] || [ -z "$CONTENT" ]; then
  MSG="Homelab: Ghost-Backup unvollständig (DB: ${LATEST:-fehlt}, Content: ${CONTENT:-fehlt})"
  curl -fsS --max-time 15 -d "$MSG" "https://ntfy.sh/$TOPIC" >/dev/null || true
  echo "FEHLER: $MSG"
  exit 1
fi

DB_TS="$(stat -c %Y "$LATEST")"
CONTENT_TS="$(stat -c %Y "$CONTENT")"
if [ "$CONTENT_TS" -lt $((DB_TS - 60)) ]; then
  curl -fsS --max-time 15 -d "Homelab: Ghost-Content aelter als DB-Dump" "https://ntfy.sh/$TOPIC" >/dev/null || true
  echo "FEHLER: Content aelter als DB ($(basename "$CONTENT"))"
  exit 1
fi

AGE_H=$(( ( $(date +%s) - DB_TS ) / 3600 ))
if [ "$AGE_H" -gt "$MAX_AGE_H" ]; then
  curl -fsS --max-time 15 -d "Homelab: Ghost-Backup ist ${AGE_H}h alt" "https://ntfy.sh/$TOPIC" >/dev/null || true
  echo "FEHLER: Ghost-Backup zu alt: ${AGE_H}h ($LATEST)"
  exit 1
fi

echo "ok: $(basename "$LATEST") + $(basename "$CONTENT") (${AGE_H}h)"
