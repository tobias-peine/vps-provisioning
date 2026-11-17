Ein frischer VPS ist in zehn Minuten eingerichtet. Ihn sicher zu betreiben ist keine Checkliste, die man einmal abhakt, sondern eine Reihenfolge: erst Zugriff, dann Angriffsfläche, dann Updates, dann Backups. Wer mit der Firewall anfängt und den SSH-Zugang offen lässt, hat nichts gewonnen.

Diese Checkliste ist keine Compliance-Liste und kein Versprechen. Sie ist die Reihenfolge, in der ich einen einzelnen VPS aufbaue. Die Befehle sind für Debian 12/13 und Ubuntu 24.04 gedacht; mein Server läuft mit Ubuntu 24.04, die hier beschriebenen Stellen sind in beiden Systemen gleich.

## 1. Erst schauen, was überhaupt läuft

Bevor du etwas abschaltest oder blockierst, brauchst du ein Bild vom Ist-Zustand. Sonst sperrst du dich aus oder übersiehst den Dienst, der seit Monaten auf `0.0.0.0` lauscht.

```bash
ss -tulpn
systemctl --failed
systemctl list-units --type=service --state=running
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
apt list --upgradable
```

Notiere dir:

- welche Ports von außen erreichbar sind,
- welche davon tatsächlich gebraucht werden,
- welche Container Ports veröffentlichen,
- welche Dienste als `root` laufen.

Ohne diese Bestandsaufnahme ist jede Firewall-Regel geraten.

## 2. SSH: der größte Hebel

Der SSH-Zugang ist der wichtigste Teil. Ein starker Schlüssel und kein Passwort-Login nehmen den größten Teil der automatisierten Angriffe aus dem Spiel.

Neuen Benutzer anlegen, Schlüssel übernehmen, sudo geben:

```bash
adduser deploy
usermod -aG sudo deploy
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy
```

Dann die eigene SSH-Sitzung **offen lassen** und in einer zweiten Sitzung testen. Erst wenn der neue Zugang funktioniert, die Konfiguration scharf schalten.

```bash
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers deploy
EOF
sudo sshd -t
sudo systemctl reload ssh
```

Wichtig:

- `sshd -t` vor dem Reload. Ein Tippfehler in der Konfiguration kann dich aussperren.
- Die Provider-Konsole kennen, bevor du testest.
- `AllowUsers` nur setzen, wenn der Benutzer wirklich existiert.
- Root-Login per Passwort ist keine „Bequemlichkeit“, sondern ein offenes Tor.

Wenn du nur eine Sache aus diesem Artikel machst: diese.

## 3. Updates und Reboots

Ein Server ohne Updates ist kein Server, sondern eine Sammlung bekannter Lücken. Auf Debian:

```bash
sudo apt update
sudo apt full-upgrade
sudo dpkg --audit
sudo needrestart
sudo reboot
```

`needrestart` zeigt, welche Dienste nach Bibliotheks-Updates neu gestartet werden müssen. Ein Kernel-Update braucht einen Reboot; ein Patchday ohne Reboot ist oft nur ein halber Patchday.

Automatische Sicherheitsupdates sind sinnvoll, aber kein Ersatz für einen regelmäßigen Blick:

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

Ich lasse automatische Sicherheitsupdates laufen und reboote bewusst in einem Fenster. Was ein Reboot über den Server verrät, steht in [Patchday: Was ein Reboot über den Server verrät](/patchday/).

## 4. Firewall – und die Docker-Falle

Eine einfache Variante ist ufw:

```bash
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80,443/tcp
sudo ufw enable
sudo ufw status verbose
```

Nur 22, 80 und 443 nach außen. Datenbanken, Admin-Oberflächen und interne APIs gehören nicht ins offene Netz.

**Die Falle:** Docker veröffentlicht Ports über eigene NAT-Regeln und kann an ufw vorbei. Ein Container mit

```text
0.0.0.0:3306->3306/tcp
```

ist von außen erreichbar, auch wenn `ufw status` etwas anderes suggeriert. Prüfe deshalb immer beides:

```bash
sudo ufw status
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

Wenn ein Dienst nur lokal gebraucht wird, binde ihn an `127.0.0.1`:

```yaml
ports:
  - "127.0.0.1:3306:3306"
```

Für Docker gibt es die `DOCKER-USER`-Kette, um Regeln vor den Container-Regeln zu setzen. Wichtiger als die perfekte Regel ist die Gewohnheit, nach jedem neuen Container die Ports zu prüfen. Mehr zu meinem Setup steht in [Mein Homelab: ein VPS, Docker und die Fehler, die mich am meisten gelehrt haben](/mein-homelab/).

## 5. Dienste reduzieren

Jeder laufende Dienst ist Angriffsfläche, Update-Aufwand und eine mögliche Fehlerquelle. Nach der Bestandsaufnahme:

```bash
systemctl list-unit-files --state=enabled
sudo systemctl disable --now <dienst>
sudo apt remove <paket>
```

Nicht blind deinstallieren, was du nicht kennst. Erst prüfen, ob es zu Docker, dem Reverse Proxy oder dem Boot gehört. Aber alles, was seit der Installation läuft und niemand nutzt, kann weg.

## 6. Docker: praktisch, aber nicht automatisch sicher

Docker macht Dienste reproduzierbar, aber es nimmt dir keine Sicherheitsentscheidung ab.

- **Docker-Gruppe ist praktisch root.** Wer in der Gruppe ist, kann Container mit Host-Rechten starten. Nicht an alle verteilen.
- **Images pinnen.** `latest` ist kein Update-Konzept. Nutze konkrete Versionen und aktualisiere bewusst.
- **Keine unnötigen Rechte.** Kein `privileged: true`, kein `network_mode: host`, keine Host-Pfade, die nicht gebraucht werden.
- **Secrets nicht in die Compose-Datei.** `.env` mit `chmod 600`, nicht ins Repository.
- **Ports prüfen.** Siehe oben: Docker und ufw sind zwei verschiedene Baustellen.

```bash
docker compose config
docker compose pull
docker compose up -d
docker image prune
```

Wenn du Container mit Ansible verwaltest, lohnt der Blick auf [Ansible auf einem VPS: 356 Sekunden und drei Fehler, die nur ein Kaltstart findet](/ansible-356-sekunden/) und [Mein Server als Code: was ich beim Aufschreiben gefunden habe](/ansible-infrastruktur-als-code/). Genau beim Aufschreiben fällt auf, was nur zufällig funktioniert.

## 7. TLS und Reverse Proxy

Nach außen sollte nur der Reverse Proxy sprechen. Er beendet TLS, leitet an die Container weiter und ist die Stelle, an der HSTS und Security-Header gesetzt werden.

- HTTP leitet auf HTTPS um.
- Zertifikate werden automatisch erneuert; der Ablauf wird überwacht.
- Admin-Oberflächen (z. B. der Nginx-Proxy-Manager auf Port 81) sind nicht öffentlich erreichbar.
- HSTS erst aktivieren, wenn HTTPS auf allen Subdomains funktioniert.

Prüfen:

```bash
curl -I https://kisium.de/
curl -I http://kisium.de/
```

Erwartung: HTTPS liefert `200`, HTTP leitet mit `301` auf HTTPS um. Ein Zertifikat, das in 20 Tagen abläuft, ist kein Backup-Problem, sondern ein Monitoring-Problem.

## 8. Backups, die einen Restore überleben

Ein Backup ist erst dann ein Backup, wenn du es zurückgespielt hast. Für einen einzelnen VPS heißt das:

- Datenbank-Dump und Dateien/Volumes getrennt sichern.
- Verschlüsselt aufbewahren.
- Mindestens eine Kopie außerhalb des Servers.
- Regelmäßig einen Restore testen, nicht nur den Backup-Job.

Ich sichere DB und Content in ein lokales Verzeichnis und schiebe das verschlüsselt per restic auf zwei unabhängige Ziele. Wichtiger als das Tool ist die Frage: **Wie lange brauche ich im Ernstfall, bis die Seite wieder läuft?** Der Weg dorthin steht in [Ein Backup-Ziel, das einen Nachmittag gebraucht hat](/ein-backup-ziel-das-einen-nachmittag-gebraucht-hat/).

## 9. Monitoring und Alarmierung

Ein Dashboard, das grün leuchtet, beweist nichts. Entscheidend ist, ob ein Alarm wirklich ankommt.

- Externer Uptime-Check für die Website.
- Prüfung auf Disk-Platz, Zertifikatsablauf und Alter des letzten Backups.
- Ein Alarmkanal, der nicht derselbe Server ist.
- Ein Testalarm, der wirklich klingelt.

Genau daran bin ich gescheitert: [Grün heißt nicht heil: drei stille Ausfälle an einem Tag](/grun-heisst-nicht-heil-drei-stille-ausfalle-an-einem-tag/). Seitdem teste ich den Alarmweg, nicht nur den Dienst.

## 10. Secrets und Rechte

- `.env`-Dateien mit `chmod 600`, im Besitz des Dienst-Benutzers.
- Keine Passwörter, API-Keys oder privaten Schlüssel im Git-Repository.
- API-Keys nur mit den Rechten, die sie brauchen.
- Nicht mehr Root als nötig; sudo gezielt einsetzen.
- Bei Verdacht auf Exposition: Key rotieren, nicht nur löschen.

Ein Klartext-Passwort im Repository ist kein „kleiner Fehler“, sondern ein Zugang. Wie ich das beim Aufschreiben meiner Infrastruktur gefunden habe, steht in [Mein Server als Code](/ansible-infrastruktur-als-code/).

## Die Reihenfolge, wenn du nur eine Stunde hast

1. SSH: Schlüssel, kein Passwort-Login, Root-Login aus.
2. Firewall: 22/80/443, danach Docker-Ports prüfen.
3. Updates: `apt full-upgrade`, `needrestart`, Reboot.
4. Backup: DB und Content, ein Restore-Test.
5. Monitoring: externer Check plus ein Alarm, der ankommt.

Alles andere kann warten. Diese fünf Punkte verhindern die meisten vermeidbaren Ausfälle.

## Was ich bewusst weglasse

- **Port-Knocking und „Security by obscurity“** als Ersatz für Schlüssel und Updates.
- **Ein Antivirus auf jedem Linux-VPS**, wenn die Dienste klar begrenzt sind.
- **30 Tools gleichzeitig**, die niemand wartet.
- **Ein „fertiges“ Sicherheitsversprechen.** Sicherheit ist ein Prozess, kein Skript.

## Fazit

Ein VPS ist schnell aufgesetzt. Die Reihenfolge macht den Unterschied: Zugriff sichern, Angriffsfläche reduzieren, Updates und Reboots ernst nehmen, Backups zurückspielen können und Alarme testen. Wer das einmal sauber aufsetzt, hat später weniger Überraschungen – und mehr Zeit für die interessanten Teile.
