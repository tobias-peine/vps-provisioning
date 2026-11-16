#!/usr/bin/env bash
#
# Wrapper: ruft restore-test.sh gegen das neueste Tages-Backup auf.
# Cron: täglich (0 4 * * *), für Dauerbetrieb des Restore-Tests.
#
# Monitoring: Ping an Healthchecks.io am Ende bei ERFOLG.
#   Ping aus  -> Check läuft in "Grace" -> nach 2h Mail.
#   Kein "OK" bei Fehler wird bewusst NIE gesendet.

set -uo pipefail

LOG="/var/log/restore-test.log"
BACKUP_DIR="/opt/backups/paperless"
HC_ENV="/opt/backups/.restore-test-monitor.env"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# --- Env-Datei mit Ping-URL laden, Fail-Fast ---
if [ ! -r "$HC_ENV" ]; then
  echo "[$(timestamp)] FEHLER: $HC_ENV fehlt oder nicht lesbar" >> "$LOG"
  exit 1
fi
# shellcheck disable=SC1090
. "$HC_ENV"

if [ -z "${HC_PING_URL:-}" ]; then
  echo "[$(timestamp)] FEHLER: HC_PING_URL in $HC_ENV leer" >> "$LOG"
  exit 1
fi

# --- Neuestes Tages-Backup finden ---
LATEST="$(ls -1t "$BACKUP_DIR"/paperless-2*.tar.gz 2>/dev/null | head -n 1)"

if [ -z "$LATEST" ]; then
  echo "[$(timestamp)] FEHLER: kein Backup in $BACKUP_DIR gefunden" >> "$LOG"
  exit 1
fi

echo "[$(timestamp)] === Restore-Test START, Backup: $(basename "$LATEST") ===" >> "$LOG"

/opt/backups/restore-test.sh "$LATEST" >> "$LOG" 2>&1
CODE=$?

if [ "$CODE" -eq 0 ]; then
  echo "[$(timestamp)] === Restore-Test OK ===" >> "$LOG"

  # --- Ping nur bei Erfolg ---
  if curl -fsS --retry 3 --max-time 15 "$HC_PING_URL" > /dev/null; then
    echo "[$(timestamp)] Monitoring-Ping OK" >> "$LOG"
  else
    echo "[$(timestamp)] WARNUNG: Monitoring-Ping fehlgeschlagen (Test selbst OK)" >> "$LOG"
  fi
else
  echo "[$(timestamp)] === Restore-Test FEHLER (Exit $CODE) — kein Ping ===" >> "$LOG"
fi

exit "$CODE"
