# Ghost-Update — kisium.de

Stand: 17.11.2026.

## Ist-Zustand

- Ghost **6.77.0**, Image `ghost:6.77.0` (in Compose gepinnt).
- MySQL 8.4, Container `kisium-mysql`.
- Theme `kisium` (Casper 5.12.5 + Patch `themes/kisium-casper.patch`).
- Healthcheck in Compose nutzt Node, weil dem Debian-Image `nc` fehlt.

## Grundsätze

- Patch-/Minor-Update: mit Backup und Wartungsfenster.
- Major-Update: eigener Auftrag, eigene Freigabe, vorher Restore-Test.
- Theme-Fork wird **manuell** gepflegt; Casper-Updates werden nicht automatisch übernommen.
- Kein Update ohne frisches DB- und Content-Backup.

## Vorbereitung

1. Release Notes und Breaking Changes lesen.
2. Ziel-Tag auf Docker Hub prüfen.
3. Backups anlegen (siehe `ghost-backup-restore.md`).
4. Compose-Datei sichern:
   ```bash
   sudo cp /opt/kisium/docker-compose.yml /opt/backups/ghost/docker-compose.yml.bak-$(date +%Y%m%d-%H%M%S)
   ```
5. Plattenplatz und RAM prüfen.

## Ablauf

1. Image ziehen:
   ```bash
   docker pull ghost:<ZIEL-TAG>
   ```
2. In `/opt/kisium/docker-compose.yml` das Image auf `<ZIEL-TAG>` setzen (root-only Datei).
3. Auflösung prüfen:
   ```bash
   cd /opt/kisium
   sudo docker compose config --images
   ```
4. Nur Ghost neu erstellen:
   ```bash
   sudo docker compose up -d --no-deps ghost
   ```
5. Health abwarten:
   ```bash
   docker inspect kisium-ghost --format '{{.Config.Image}} {{.State.Health.Status}}'
   ```
6. Smoke-Tests:
   - `https://kisium.de/` = HTTP/2 200
   - `https://www.kisium.de/` = 301 auf Apex
   - Tag-Seite: H1 vorhanden
   - Beitrag: Byline `<p class="author-name">`, Meta-Description vorhanden
   - Ghost und NPM `healthy`
   - Admin-Login (falls Zugang vorhanden)

## Rollback

1. Compose-Backup zurückkopieren.
2. `sudo docker compose up -d --no-deps ghost`.
3. Falls die neue Version die DB migriert hat: DB-Backup einspielen (Downgrade ohne DB-Restore kann scheitern).
4. Health und Smoke-Tests erneut.

## Healthcheck-Hinweis

`ghost:6.77.0` basiert auf Debian und enthält kein `nc`. Der Compose-Check nutzt deshalb Node:

```yaml
test: ["CMD", "node", "-e", "require('http').get('http://127.0.0.1:2368/',r=>process.exit(r.statusCode>=200&&r.statusCode<400?0:1)).on('error',()=>process.exit(1))"]
```

Bei einem Image-Wechsel prüfen, ob `node` vorhanden ist; sonst Check anpassen.

## Theme-Fork

- Basis: Casper 5.12.5.
- Patch: `themes/kisium-casper.patch`.
- Casper-Update: Patch gegen die neue Casper-Version prüfen/neu anwenden, dann Tag-H1 und Beitrags-Byline testen.
- Bei größeren Casper-Änderungen: Fork neu aufbauen, nicht blind patchen.

## Nicht Teil dieses Runbooks

- `docker compose up -d` ohne `--no-deps` (würde auch MySQL anfassen).
- Major-Upgrades ohne separaten Restore-Test.
