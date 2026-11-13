#!/bin/bash
# Uptime-Wache: prueft die oeffentlichen Hosts, die RustDesk-Ports, den Zustand
# der Container und den Platz auf /. Meldet nur Zustandswechsel per ntfy -
# sonst kaeme alle fuenf Minuten dieselbe Nachricht.
#
# Das ntfy-Thema steht nicht im Repo, sondern in /opt/backups/.ntfy-topic
# (root, 0600), weil es dort schon von den Backup-Checks benutzt wird.
set -uo pipefail

STATE_FILE="${STATE_FILE:-/run/uptime-check.state}"
TOPIC_FILE="${TOPIC_FILE:-/opt/backups/.ntfy-topic}"
# Ueberschreibbar (Leerzeichen-getrennt) - praktisch fuer einen Testlauf, ohne
# die Liste im Skript anzufassen.
read -r -a HOSTS <<< "${UPTIME_HOSTS:-kisium.de ha.kisium.de chat.kisium.de \
search.kisium.de paperless.kisium.de n8n.kisium.de dash.kisium.de lunaria.kisium.de}"
PORTS=(21115 21116 21117)

fail=()

for h in "${HOSTS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://$h/" 2>/dev/null)
  case "$code" in
    2*|3*|401) ;;
    *) fail+=("$h: HTTP ${code:-000}") ;;
  esac
done

for p in "${PORTS[@]}"; do
  timeout 3 bash -c "</dev/tcp/127.0.0.1/$p" 2>/dev/null || fail+=("RustDesk Port $p: zu")
done

unhealthy=$(docker ps --filter health=unhealthy --format '{{.Names}}' 2>/dev/null | paste -sd' ' -)
[ -n "$unhealthy" ] && fail+=("unhealthy: $unhealthy")

use=$(df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9')
[ -n "$use" ] && [ "$use" -ge 90 ] && fail+=("Disk /: ${use}%")

if [ "${#fail[@]}" -eq 0 ]; then
  now=ok
  msg=""
else
  now=fail
  msg=$(printf '%s; ' "${fail[@]}")
  msg=${msg%; }
fi

prev=$(cat "$STATE_FILE" 2>/dev/null || true)
echo "$now" > "$STATE_FILE"

notify() {
  [ -r "$TOPIC_FILE" ] || return 0
  topic=$(tr -d '[:space:]' < "$TOPIC_FILE")
  [ -n "$topic" ] || return 0
  curl -fsS --max-time 15 -H "Title: $1" -H "Priority: high" \
    -d "$2" "https://ntfy.sh/$topic" >/dev/null 2>&1 || true
}

if [ "$now" = fail ] && [ "$prev" != fail ]; then
  notify "Homelab: Stoerung" "$msg"
elif [ "$now" = ok ] && [ "$prev" = fail ]; then
  notify "Homelab: wieder ok" "Alle Pruefungen laufen wieder."
fi

# Liveness-Ping an healthchecks.io: meldet, dass die Wache selbst laeuft. Faellt
# der Host aus, bleibt der Ping aus und der externe Dienst alarmiert - das kann
# ntfy nicht, weil es auf demselben Host laeuft. Bewusst auch bei Befunden:
# dieser Check misst "Wache lebt", nicht "alles gesund".
MON_ENV="${MON_ENV:-/opt/backups/.uptime-check-monitor.env}"
if [ -r "$MON_ENV" ]; then
  # shellcheck disable=SC1090
  . "$MON_ENV"
  if [ -n "${UPTIME_PING_URL:-}" ]; then
    curl -fsS -m 5 -o /dev/null "$UPTIME_PING_URL" || true
  fi
fi

if [ "$now" = ok ]; then
  echo "OK"
else
  echo "FEHLER: $msg"
  exit 1
fi
