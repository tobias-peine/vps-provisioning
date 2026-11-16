#!/usr/bin/env bash
# Tagesbackup fuer die Dienste, die in den bestehenden Jobs fehlen:
# n8n (Workflows + Credentials, Key liegt in /opt/stack/.env) und Home Assistant.
# Zusaetzlich die Compose-/env-/cron-Konfiguration als Rollback-Punkt.
# Bestehende Jobs bleiben unveraendert: paperless 03:30, kisium 03:00,
# kisium-tv 03:30, Restore-Test 04:00.
set -euo pipefail
umask 077

ROOT=/opt/backups
STAMP=$(date +%Y%m%d)
KEEP=14
log() { printf "[%s] %s\n" "$(date "+%F %T")" "$*"; }
size() { du -h "$1" | cut -f1; }

mkdir -p "$ROOT/n8n" "$ROOT/homeassistant" "$ROOT/config"

# n8n kurz stoppen: die SQLite-DB soll konsistent im Archiv landen.
log "n8n: stoppe Container"
docker stop n8n >/dev/null
trap 'docker start n8n >/dev/null 2>&1 || true' EXIT
tar czf "$ROOT/n8n/n8n-$STAMP.tar.gz" -C /var/lib/docker/volumes/homeserver_n8n _data
docker start n8n >/dev/null
trap - EXIT
log "n8n: $(size "$ROOT/n8n/n8n-$STAMP.tar.gz")"

log "homeassistant: sichere config/"
tar czf "$ROOT/homeassistant/homeassistant-$STAMP.tar.gz" -C /opt/homeassistant config
log "homeassistant: $(size "$ROOT/homeassistant/homeassistant-$STAMP.tar.gz")"

log "config: sichere Compose-, env- und cron-Dateien"
tar czf "$ROOT/config/config-$STAMP.tar.gz" \
  /opt/stack/docker-compose.yml /opt/stack/docker-compose.override.yml /opt/stack/.env \
  /opt/homepage/docker-compose.yml /opt/homepage/.env \
  /opt/homeassistant/compose.yaml \
  /opt/kisium/docker-compose.yml /opt/kisium/docker-compose.override.yml /opt/kisium/.env \
  /home/admin/kisium-tv/docker-compose.yml /home/admin/kisium-tv/.env \
  /etc/cron.d /etc/ssh/sshd_config.d 2>/dev/null
log "config: $(size "$ROOT/config/config-$STAMP.tar.gz")"

find "$ROOT/n8n" "$ROOT/homeassistant" "$ROOT/config" -type f -name "*.tar.gz" -mtime +$KEEP -delete
log "fertig, Rotation: $KEEP Tage"
