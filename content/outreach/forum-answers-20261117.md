# Foren-Antworten (Entwürfe)

Stand 17.11.2026. **Nicht gepostet.** Alle Antworten ohne Link; erst helfen, kein Link-Drop.
Ziel: administrator.de. linux-nerds.org hat aktuell keine passende offene Docker-/Backup-Frage.

## 1. Komisches Verhalten Docker-Portainer-UFW-UFW Docker

- Thread: https://administrator.de/forum/komisches-verhalten-docker-portainer-ufw-ufw-docker-61012880451.html
- Status im Thread: offen; Container trotz ufw-docker von außen erreichbar.
- Antwort:

```text
Moin,

wenn die Container trotz ufw-docker erreichbar sind, würde ich zuerst drei Dinge prüfen:

1. Ist die DOCKER-USER-Kette überhaupt noch aktiv?
   iptables -S DOCKER-USER
   iptables -t nat -S DOCKER
   ufw status verbose

   ufw-docker installiert seine Regeln in DOCKER-USER und schreibt den Einstieg
   in /etc/ufw/after.rules. Nach einem Docker-/UFW-Neustart kann der Einstieg
   fehlen oder die Regeln zeigen auf alte Container-IPs. Dann einmal
   `ufw-docker install` und `ufw reload`, danach die Kette erneut prüfen.

2. Zeigen die Regeln noch auf die richtigen IPs?
   ufw-docker arbeitet mit den Container-IPs. Wenn ein Container neu startet
   und eine andere IP bekommt, greifen die alten Regeln nicht mehr. Abhilfe:
   eigenes Docker-Netz mit festem Subnetz und festen IPs, oder die Regeln nach
   dem Start neu setzen. Die DOCKER-Kette selbst nicht von Hand löschen –
   Docker baut sie beim nächsten Start wieder auf, deine Änderungen sind weg.

3. Gibt es Container im Host-Netz?
   Bei `network_mode: host` gibt es keine Portveröffentlichung über Docker;
   der Dienst lauscht direkt auf dem Host. Dann greifen die normalen
   INPUT-Regeln von ufw, nicht DOCKER-USER. Das muss man getrennt betrachten.

Für Admin-Oberflächen (Portainer, NPM-UI) würde ich den Port gar nicht
veröffentlichen: `127.0.0.1:9000:9000` binden und per SSH-Tunnel oder Tailscale
darauf zugreifen. Das ist unabhängig von ufw-docker und überlebt jedes Update.

Kurz: ufw-docker ist kein „einmal installieren und vergessen“. Nach
Container-Neustarts und Docker-Updates die DOCKER-USER-Regeln prüfen; für
Dienste, die nicht öffentlich sein müssen, gar nicht erst veröffentlichen.
```

## 2. Fragen zu NPM Docker Installation (502 Bad Gateway)

- Thread: https://administrator.de/forum/fragen-zu-npm-docker-installation-42010191581.html
- Status im Thread: 502 nach dem Einrichten; offen.
- Antwort:

```text
Moin,

beim 502 ist fast immer der Upstream im Proxy Host falsch – nicht NPM selbst.
Drei Punkte, die ich der Reihe nach prüfen würde:

1. Steckt NPM im selben Docker-Netz wie der Zielcontainer?
   Nur dann funktioniert der Container-Name als Ziel. Im Proxy Host also
   `app:3000` eintragen, nicht `127.0.0.1:3000`. `127.0.0.1` ist aus Sicht
   des NPM-Containers NPM selbst, nicht der Host.

   Test:
   docker exec -it <npm-container> getent hosts <app-container>
   docker exec -it <npm-container> curl -v http://<app-container>:3000

2. Ist der Port der interne Container-Port?
   Im Proxy Host den Port eintragen, auf dem die App **im Container** lauscht
   (z. B. 3000), nicht den veröffentlichten Host-Port (z. B. 8080).

3. Hängt der Container in mehreren Netzen?
   Dann muss NPM in genau dem Netz sein, in dem der Zielname auflösbar ist.
   `docker network inspect <netz>` zeigt, wer drin ist.

Zum NPM-UI auf Port 81: Den Port nicht auf 0.0.0.0 veröffentlichen. Besser
`127.0.0.1:81:81` binden und per SSH-Tunnel zugreifen:
ssh -L 8181:127.0.0.1:81 user@server
Dann ist das UI nur über die SSH-Verbindung erreichbar.

Feste Container-IPs brauchst du für NPM selbst nicht, solange du über
Container-Namen arbeitest. Für ufw-docker-Regeln ist ein eigenes Netz mit
festem Subnetz sinnvoller als feste IPs pro Container.
```

## 3. UFW im Heimnetzwerk sinnvoll?

- Thread: https://administrator.de/forum/ufw-im-heimnetzwerk-sinnvoll-21369302178.html
- Status im Thread: Diskussion; keine eindeutige Antwort.
- Antwort:

```text
Moin,

ich würde die ufw auf dem Pi aktivieren – aber mit klaren Erwartungen:

- Sie ersetzt nicht die Fritzbox. Der Router bleibt die Grenze nach außen.
- Sie hilft gegen laterale Bewegung im LAN: ein kompromittiertes Gerät soll
  nicht einfach auf DNS, SSH oder Admin-Ports des Pi zugreifen können.
- Sie kostet kaum Leistung; der Aufwand ist die Pflege der Regeln.

Wichtig bei Docker: veröffentlichte Container-Ports gehen an der INPUT-Kette
vorbei. Wenn AdGuard oder andere Dienste nur im LAN erreichbar sein sollen,
dann `127.0.0.1` oder die LAN-IP binden und nicht `0.0.0.0`. Für den
DNS-Dienst brauchst du natürlich eine Freigabe für das LAN.

Mein Minimal-Setup wäre:
- default deny incoming, allow outgoing
- SSH nur aus dem LAN
- DNS (53) nur aus dem LAN
- Admin-Oberflächen nur per SSH-Tunnel oder Tailscale
- Docker-Ports explizit prüfen: `ss -lntp` und `docker ps`

Die ufw ist hier also kein Overkill, sondern die Host-Absicherung. Die
eigentliche Segmentierung bleibt Aufgabe des Routers.
```

## Nach dem Posten

- Status und Datum in `docs/seo/outreach-targets-20261117.md` eintragen.
- Keine Links in den Antworten; Profil erst später ausfüllen.
- Nicht alle drei in derselben Minute posten; zwei bis drei Antworten reichen.
