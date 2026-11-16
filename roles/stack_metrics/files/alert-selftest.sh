#!/usr/bin/env bash
# Verwaltet von Ansible (Rolle stack_metrics).
# Woechentlicher Selbsttest der Alarmkette: feuert einen Alarm ueber die
# Alertmanager-API, wartet, bis er durch alle Empfaenger gelaufen ist, und
# loest ihn wieder auf. So faellt ein toter Kanal auf, bevor es ernst wird -
# Alertmanager protokolliert nur FEHLGESCHLAGENE Zustellungen, eine stille
# Regression (wie der local_only-Fehler am 16.11.) bleibt sonst unbemerkt.
set -euo pipefail

AM="http://127.0.0.1:9093/api/v2/alerts"
NAME="Selbsttest"
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SUMMARY="Woechentlicher Selbsttest der Alarmkette (HA, ntfy, E-Mail) - kein Handlungsbedarf."

payload() {
  local ends="$1"
  printf '[{"labels":{"alertname":"%s","severity":"info","instance":"selbsttest"},"annotations":{"summary":"%s"},"startsAt":"%s"%s}]' \
    "$NAME" "$SUMMARY" "$START" "$ends"
}

post() {
  curl -s -o /dev/null -w '%{http_code}' -X POST "$AM" \
    -H 'Content-Type: application/json' -d "$1"
}

code=$(post "$(payload '')")
echo "[$(date '+%F %T')] Selbsttest ausgeloest, Alertmanager HTTP ${code}"
[ "$code" = "200" ] || exit 1

# group_wait ist 30 s; 180 s geben jedem Empfaenger Zeit, inklusive Retry.
sleep 180

ENDE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
code=$(post "$(payload ",\"endsAt\":\"${ENDE}\"")")
echo "[$(date '+%F %T')] Selbsttest aufgeloest, Alertmanager HTTP ${code}"
[ "$code" = "200" ]
