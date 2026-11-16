#!/usr/bin/env bash
# Stuendlicher Check: Zertifikate, Container-Health, Reboot-Bedarf, Disk.
# Exit 1 = mindestens ein Befund.
#
# Alarmierung nach dem Dead-Man-Prinzip wie beim Restore-Test:
#   Erfolg -> Ping an die Healthchecks.io-URL (Datei unten), Check bleibt gruen.
#   Fehler -> KEIN Ping, der Check laeuft in "Grace" und meldet sich per Mail.
# Solange die Datei fehlt, wird nur ins Journal geloggt.
set -euo pipefail

WARN_DAYS=14
DISK_MAX=85
MON_ENV=/opt/backups/.health-check-monitor.env
status=0
now=$(date +%s)

cert_dir=/opt/npm/letsencrypt/live
if [ -d "$cert_dir" ]; then
  while IFS= read -r crt; do
    name=$(basename "$(dirname "$crt")")
    end=$(openssl x509 -enddate -noout -in "$crt" | cut -d= -f2)
    days=$(( ($(date -d "$end" +%s) - now) / 86400 ))
    if [ "$days" -lt "$WARN_DAYS" ]; then
      echo "WARN zertifikat $name laeuft in $days Tagen ab"
      status=1
    fi
  done < <(find "$cert_dir" -name fullchain.pem 2>/dev/null)
fi

unhealthy=$(docker ps --filter health=unhealthy --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$unhealthy" ]; then
  echo "WARN unhealthy: $unhealthy"
  status=1
fi

exited=$(docker ps -a --filter status=exited --filter status=dead --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$exited" ]; then
  echo "WARN gestoppte container: $exited"
  status=1
fi

if [ -f /var/run/reboot-required ]; then
  pkgs=$(tr "\n" " " < /var/run/reboot-required.pkgs 2>/dev/null || echo "")
  echo "WARN reboot erforderlich${pkgs:+ ($pkgs)}"
  status=1
fi

disk=$(df --output=pcent / | tail -1 | tr -dc "0-9")
if [ "$disk" -ge "$DISK_MAX" ]; then
  echo "WARN disk / bei ${disk}%"
  status=1
fi


# Backup-Frische: letzter Snapshot je Restic-Repo (Warnung ab 36 h)
for envf in /etc/restic/offsite.env /etc/restic/offsite2.env; do
  [ -r "$envf" ] || continue
  age=$( (
      set -a
      # shellcheck disable=SC1090
      . "$envf"
      set +a
      restic snapshots --latest 1 --json 2>/dev/null
    ) | python3 -c '
import sys, json, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    print(999); raise SystemExit
if not d:
    print(999); raise SystemExit
t = datetime.datetime.fromisoformat(d[-1]["time"].replace("Z", "+00:00"))
print(int((datetime.datetime.now(datetime.timezone.utc) - t).total_seconds() // 3600))
' 2>/dev/null || echo 999)
  if [ "${age:-999}" -gt 36 ]; then
    echo "WARN backup $(basename "$envf"): letzter Snapshot ${age}h alt"
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "ok: zertifikate > ${WARN_DAYS} Tage, container healthy, kein reboot, disk ${disk}%"
  if [ -r "$MON_ENV" ]; then
    # shellcheck disable=SC1090
    . "$MON_ENV"
    if [ -n "${HEALTHCHECK_PING_URL:-}" ]; then
      if curl -fsS -m 5 -o /dev/null "$HEALTHCHECK_PING_URL"; then
        echo "monitor: ping ok"
      else
        echo "WARN monitor: ping fehlgeschlagen"
      fi
    fi
  else
    echo "hinweis: $MON_ENV fehlt, kein monitoring-ping"
  fi
fi
exit "$status"
