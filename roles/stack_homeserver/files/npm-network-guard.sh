#!/bin/sh
# Haengt den NPM-Container an das Compose-Netz homeserver_default, falls der
# Anschluss beim Boot verloren geht (beobachtet am 13.11.2026: der Container kam
# nur mit kisium-net hoch, alle homeserver-Domains antworteten mit 502).
#
# Idempotent: laeuft der Anschluss schon, passiert nichts. Der Netzwerk-Anschluss
# wird per CLI gesetzt, weil Docker ihn nicht ueber "docker update" aendern kann
# und ein Recreate des Proxys unnoetig Downtime kostet.
set -u

# Auf den Container warten - beim Boot startet Docker die Container asynchron.
for _ in $(seq 1 90); do
  [ "$(docker inspect -f '{{.State.Running}}' npm 2>/dev/null)" = "true" ] && break
  sleep 2
done

if ! docker inspect npm --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null \
     | grep -q homeserver_default; then
  docker network connect homeserver_default npm >/dev/null 2>&1
  # Nginx hat die Upstream-Namen beim Start aufgeloest; ohne Reload bleibt es
  # bei 502, obwohl das Netz wieder steht.
  docker exec npm nginx -s reload >/dev/null 2>&1
fi

exit 0
