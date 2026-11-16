#!/usr/bin/env bash
# Zweites Offsite-Backup: Hetzner Storage Box (unabhaengig vom rest-Server).
# Verschluesselt mit eigenem Repo-Passwort.
set -euo pipefail
export HOME=/root

ENV_FILE=/etc/restic/offsite2.env
[ -r "$ENV_FILE" ] || { echo "FEHLT: $ENV_FILE"; exit 2; }
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

case "${RESTIC_REPOSITORY:-}" in
  ""|*TODO*) echo "ABBRUCH: RESTIC_REPOSITORY ist TODO ($ENV_FILE)"; exit 2;;
esac
[ -r "${RESTIC_PASSWORD_FILE:-/nonexistent}" ] || { echo "ABBRUCH: Passwortdatei fehlt"; exit 2; }

echo "[$(date "+%F %T")] starte Offsite-Backup 2 (Storage Box)"
restic backup --quiet /opt/backups /opt/kisium/backups /home/admin/kisium-backups
restic forget --quiet --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check --quiet
echo "[$(date "+%F %T")] fertig"
