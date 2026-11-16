#!/usr/bin/env bash
# Reboot-Fenster: startet den Host neu, wenn ein Reboot ansteht.
# Aktivierung ist bewusst manuell (siehe /etc/cron.d/reboot-window).
# Ein unerwarteter Neustart mit 15 Containern ist schlimmer als ein
# Reboot im Fenster - deshalb laeuft das hier nur, wenn es eingeschaltet ist.
set -euo pipefail

LOG=/var/log/reboot-window.log
log() { printf "[%s] %s\n" "$(date "+%F %T")" "$*" | tee -a "$LOG"; }

if [ ! -f /var/run/reboot-required ]; then
  log "kein Reboot erforderlich"
  exit 0
fi

pkgs=$(tr "\n" " " < /var/run/reboot-required.pkgs 2>/dev/null || true)
log "Reboot erforderlich${pkgs:+ ($pkgs)} - starte neu"
sync
systemctl reboot
