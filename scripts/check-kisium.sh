#!/usr/bin/env bash
# Read-only health check for kisium.de. Run on the VPS (root recommended).
set -u
fail=0
ok() { printf 'OK   %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*"; fail=1; }

apex=$(curl -sI --http2 --max-time 10 https://kisium.de/ 2>/dev/null | head -1 | tr -d '\r')
code=$(printf '%s' "$apex" | awk '{print $2}')
if [ "$code" = "200" ] && printf '%s' "$apex" | grep -q 'HTTP/2'; then
  ok "apex HTTP/2 200"
else
  bad "apex: ${apex:-keine Antwort}"
fi

www_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://www.kisium.de/ 2>/dev/null || true)
www_loc=$(curl -sI --max-time 10 https://www.kisium.de/ 2>/dev/null | awk 'tolower($1)=="location:"{print $2}' | tr -d '\r' | head -1)
if [ "$www_code" = "301" ] && [ "$www_loc" = "https://kisium.de/" ]; then
  ok "www 301 -> apex"
else
  bad "www: ${www_code:-?} ${www_loc:-ohne Location}"
fi

cert=$(echo | openssl s_client -servername kisium.de -connect kisium.de:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$cert" ]; then
  end=$(date -d "$cert" +%s 2>/dev/null || echo 0)
  days=$(( (end - $(date +%s)) / 86400 ))
  if echo | openssl s_client -servername kisium.de -connect kisium.de:443 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -q 'DNS:www.kisium.de'; then
    san=yes
  else
    san=no
  fi
  if [ "$days" -ge 21 ] && [ "$san" = "yes" ]; then
    ok "TLS ${days} Tage, SAN www"
  else
    bad "TLS: ${days} Tage, SAN www=${san}"
  fi
else
  bad "TLS: Zertifikat nicht lesbar"
fi

for c in kisium-ghost npm; do
  h=$(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null || echo missing)
  if [ "$h" = "healthy" ]; then
    ok "$c healthy"
  else
    bad "$c: $h"
  fi
done

if [ "$(id -u)" -eq 0 ]; then
  latest=$(find /opt/backups/ghost -maxdepth 1 -name 'ghost-db-*.sql.gz' -mmin -1560 -print -quit 2>/dev/null || true)
else
  latest=$(sudo -n find /opt/backups/ghost -maxdepth 1 -name 'ghost-db-*.sql.gz' -mmin -1560 -print -quit 2>/dev/null || true)
fi
if [ -n "$latest" ]; then
  ok "Backup <26h: $(basename "$latest")"
else
  bad "kein Ghost-DB-Backup <26h"
fi

use=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ "${use:-100}" -lt 85 ]; then
  ok "Disk ${use}%"
else
  bad "Disk ${use}%"
fi

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$fail"
