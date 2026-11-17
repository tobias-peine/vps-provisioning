# Docker umgeht ufw: Was auf einem VPS wirklich hilft

`ufw status` sagt `deny (incoming)`. Der Port ist trotzdem aus dem Internet erreichbar. Dieses Rätsel habe ich auf meinem ersten VPS mit einem MySQL-Container erlebt: `docker run -p 3306:3306 mysql` – und wenig später antwortete die Datenbank von außen.

Die Erklärung ist unangenehm einfach: **Docker schreibt seine eigenen iptables-/nftables-Regeln.** Der veröffentlichte Port wird per DNAT und FORWARD verarbeitet, nicht über die INPUT-Kette, in der ufw seine Regeln stehen hat. ufw ist deshalb nicht falsch konfiguriert – es wird von Docker schlicht umgangen.

## Erst prüfen, was wirklich lauscht

Bevor man an der Firewall dreht, sollte man sich den Ist-Zustand ansehen:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
ss -lntp | grep -E '3306|8080'
```

`0.0.0.0:3306->3306/tcp` bedeutet: Docker veröffentlicht auf allen Interfaces. `127.0.0.1:3306->3306/tcp` bedeutet: nur lokal. Der Unterschied ist entscheidend.

Ein externer Test ist ebenfalls sinnvoll – von einem anderen Host aus:

```bash
nc -vz example.org 3306
```

Wenn das offen ist, obwohl ufw „deny“ sagt, hat man den Docker-Effekt gefunden.

## Weg 1: Nur an Loopback binden

Die einfachste Lösung ist, den Port gar nicht öffentlich zu machen:

```yaml
services:
  app:
    image: nginx:alpine
    ports:
      - "127.0.0.1:8080:80"
```

Der Reverse Proxy auf dem Host übernimmt 80/443 und leitet intern an `127.0.0.1:8080` weiter. Für Datenbanken und Admin-Oberflächen ist das fast immer die bessere Variante: Sie brauchen keinen öffentlichen Listener.

Wichtig: `EXPOSE` im Dockerfile veröffentlicht nichts. Erst `-p` oder `ports:` macht den Port erreichbar. Und `network_mode: host` hebt die Trennung komplett auf – dann lauscht der Dienst direkt auf dem Host.

## Weg 2: DOCKER-USER als vorgeschaltete Kette

Docker legt eine eigene Kette `DOCKER-USER` an. Regeln dort werden vor den Docker-Regeln ausgewertet. Damit lässt sich der Zugriff auf ein Netz begrenzen:

```bash
iptables -I DOCKER-USER -p tcp --dport 3306 \
  ! -s 100.64.0.0/10 -j DROP
```

Das erlaubt Port 3306 nur aus dem Tailscale-Netz (`100.64.0.0/10`) und verwirft alles andere. Die Regel muss **vor** den Docker-Regeln stehen; `-I` setzt sie nach oben. Wer sie falsch setzt, sperrt sich selbst aus – also vorher eine zweite SSH-Sitzung offen halten.

Das ist kein ufw-Ersatz, sondern eine Ergänzung. Die Regel muss außerdem persistent sein, sonst ist sie nach einem Reboot weg. Bei IPv6 gilt `ip6tables` separat; Docker und die Firewall müssen beide Familien abdecken.

## Weg 3: ufw-docker als Hilfsmittel

Für häufige Fälle gibt es das Projekt `ufw-docker`. Es installiert Regeln in `DOCKER-USER` und bietet Befehle wie:

```bash
ufw-docker install
ufw-docker allow nginx 80
```

Das ist bequem, aber ein zusätzliches Werkzeug mit eigenen Annahmen. Vor dem Einsatz: Regeln sichern, auf einem Testsystem prüfen, danach `/etc/ufw/after.rules` bzw. die erzeugten Regeln kontrollieren. Wer bereits eine komplexe Firewall hat, sollte lieber die wenigen Regeln selbst schreiben, als sich eine weitere Abstraktion ins Boot zu holen.

## Weg 4: Tailscale statt öffentlicher Ports

Wenn der Dienst nur für dich erreichbar sein soll, brauchst du oft gar keinen öffentlichen Port. Binde den Container an die Tailscale-Adresse oder nutze `tailscale serve` für HTTPS im Tailnet. Dann bleibt der Port auf dem öffentlichen Interface zu – und die Frage „ufw oder Docker?“ stellt sich erst gar nicht.

## Was ufw wirklich schützt

ufw schützt den Host-Verkehr, den es sieht. Docker-Publishing läuft daran vorbei. Deshalb gilt:

- `ufw status` ist **kein** Beweis, dass ein Container-Port zu ist.
- `docker ps` und `ss -lntp` zeigen, was wirklich lauscht.
- Ein externer Portscan zeigt, was von außen erreichbar ist.
- Für Datenbanken: gar nicht veröffentlichen, nur Loopback oder Tailnet.
- Für öffentliche Webdienste: Reverse Proxy, nur 80/443 nach außen.

Die vollständige Debian-Checkliste für den VPS steht auf [kisium.de](https://kisium.de/vps-absichern-debian-checkliste/). Wer nur einen Satz mitnimmt: **Docker veröffentlicht Ports an ufw vorbei – prüfe die Bindung, nicht nur die Firewall.**
