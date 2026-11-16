#!/usr/bin/env bash
# Verwaltet von Ansible (Rolle stack_metrics).
# Schreibt den Zeitpunkt des letzten Snapshots beider Restic-Repos als
# Prometheus-Textdatei. node-exporter liest sie ueber den textfile-Collector ein;
# die Regel BackupZuAlt wertet sie aus.
set -euo pipefail
export HOME=/root

OUT_DIR=/opt/metrics/textfile
OUT="$OUT_DIR/restic.prom"

mkdir -p "$OUT_DIR"
# Erst in eine temporaere Datei schreiben und dann umbenennen: sonst kann
# node-exporter eine halb geschriebene Datei einlesen und den Alarm ausloesen.
TMP=$(mktemp "$OUT_DIR/.restic.XXXXXX")
trap 'rm -f "$TMP"' EXIT

last_epoch() {
  local envf=$1
  (
    set -a
    # shellcheck disable=SC1090
    . "$envf"
    set +a
    restic snapshots --latest 1 --json 2>/dev/null
  ) | python3 -c '
import sys, json, datetime
try:
    data = json.load(sys.stdin)
except Exception:
    print(0)
    raise SystemExit
if not data:
    print(0)
    raise SystemExit
stamp = datetime.datetime.fromisoformat(data[-1]["time"].replace("Z", "+00:00"))
print(int(stamp.timestamp()))
'
}

{
  echo "# HELP restic_snapshot_timestamp_seconds Zeitpunkt des letzten Snapshots (Unix-Zeit)"
  echo "# TYPE restic_snapshot_timestamp_seconds gauge"
  for entry in "rest:/etc/restic/offsite.env" "storagebox:/etc/restic/offsite2.env"; do
    repo=${entry%%:*}
    envf=${entry#*:}
    [ -r "$envf" ] || continue
    stamp=$(last_epoch "$envf" || echo 0)
    echo "restic_snapshot_timestamp_seconds{repo=\"${repo}\"} ${stamp:-0}"
  done
} > "$TMP"

chmod 644 "$TMP"
mv "$TMP" "$OUT"
trap - EXIT
