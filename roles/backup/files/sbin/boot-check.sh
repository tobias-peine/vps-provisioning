#!/usr/bin/env bash
# Nach dem Boot: warten, dann pruefen, ob alle Container wiederkommen.
# Loggt nur - ein automatischer Rollback waere bei Containern nicht moeglich.
set -euo pipefail

WAIT=${BOOT_WAIT:-180}
LOG=/var/log/boot-check.log
sleep "$WAIT"

total=$(docker ps -q | wc -l)
unhealthy=$(docker ps --filter health=unhealthy --format "{{.Names}}" | tr "\n" " " || true)
exited=$(docker ps -a --filter status=exited --filter status=dead --format "{{.Names}}" | tr "\n" " " || true)

line="container=$total"
[ -n "$unhealthy" ] && line="$line unhealthy=[$unhealthy]"
[ -n "$exited" ] && line="$line gestoppt=[$exited]"
printf "[%s] %s\n" "$(date "+%F %T")" "$line" >> "$LOG"
