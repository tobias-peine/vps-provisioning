#!/usr/bin/env bash
# Offsite-Backup: schiebt die lokalen Backups verschluesselt zu einem
# externen Ziel. Ohne Ziel bricht das Skript ab, statt erfolgreich zu tun.
set -euo pipefail

ENV_FILE=/etc/restic/offsite.env
[ -r "$ENV_FILE" ] || { echo "FEHLT: $ENV_FILE"; exit 2; }
# Zielpfad und Passwortdatei stehen in der Env-Datei des Hosts, nicht im Repo.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

case "${RESTIC_REPOSITORY:-}" in
  ""|*TODO*) echo "ABBRUCH: RESTIC_REPOSITORY ist TODO ($ENV_FILE)"; exit 2;;
esac
[ -r "${RESTIC_PASSWORD_FILE:-/nonexistent}" ] || { echo "ABBRUCH: Passwortdatei fehlt"; exit 2; }

echo "[$(date "+%F %T")] starte Offsite-Backup"
restic backup --quiet /opt/backups /opt/kisium/backups /home/admin/kisium-backups
restic forget --quiet --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check --quiet
echo "[$(date "+%F %T")] fertig"
