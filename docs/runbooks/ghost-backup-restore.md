# Ghost-Backup und Restore — kisium.de

Stand: 17.11.2026. Der isolierte Restore-Test wurde am 17.11.2026 bestanden (siehe unten).

## Komponenten

- Ghost-MySQL: Container `kisium-mysql`, Datenbank `ghost`.
- Content-Volume: `kisium_ghost_content` (Bilder, Themes, Apps).
- Compose: `/opt/kisium/docker-compose.yml` und `/opt/kisium/.env` (nur root lesbar).
- NPM: `/opt/npm/data/database.sqlite`, `nginx/proxy_host/8.conf`, `letsencrypt/`.

## Automatische Sicherung

- `/etc/cron.d/kisium-backup` → täglich 03:00 Uhr, `/opt/kisium/backup.sh`, Aufbewahrung 16 Tage.
- `/etc/cron.d/ghost-backup-check` → täglich 05:00 Uhr, Prüfung der Backups.
- `/etc/cron.d/restore-test` → täglich 04:00 Uhr; betrifft **Paperless**, nicht Ghost.
- `/etc/cron.d/kisium-tls-renew` → TLS-Erneuerung.
- Manuelle Ghost-Backups: `/opt/backups/ghost/` (root).
- NPM-Backups: `/opt/backups/npm/`.

## Frisches Backup vor Änderungen

```bash
TS=$(date +%Y%m%d-%H%M%S)
sudo mkdir -p /opt/backups/ghost
sudo tar -C /var/lib/docker/volumes/kisium_ghost_content/_data \
  -czf /opt/backups/ghost/content-$TS.tar.gz .
docker exec kisium-mysql sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers ghost' \
  | gzip > /tmp/ghost-db-$TS.sql.gz
sudo mv /tmp/ghost-db-$TS.sql.gz /opt/backups/ghost/
sudo gzip -t /opt/backups/ghost/ghost-db-$TS.sql.gz
sudo tar -tzf /opt/backups/ghost/content-$TS.tar.gz >/dev/null
```

## Restore-Test (isoliert, ohne Produktion)

Prinzip: temporäre Datenbank + temporärer Ghost-Container auf `127.0.0.1:2369`; Produktions-DB und -Container bleiben unberührt.

1. Temporäre DB und Benutzer anlegen (Name z. B. `ghost_restore_test`).
2. Dump importieren.
3. In der **temporären** DB `settings.url` auf `http://127.0.0.1:2369` setzen.
4. Content-Backup in ein temporäres Verzeichnis entpacken.
5. `ghost:6.77.0` mit diesem Content und der temporären DB starten.
6. Prüfen: `/` = 200, Titel, ein Beitrag, ein Tag, Beitragszahl, Mitgliederzahl, `active_theme`.
7. Container, temporäre DB, Benutzer und Verzeichnis wieder entfernen.

**Verifiziert am 17.11.2026** mit Backup `20261117-131545`:

- HTTP 200 auf `/`, Titel „Kisium – Vom Koch zum Cloud-Sysadmin“
- Beitrag und Tag je 200
- 16 veröffentlichte Beiträge, 3 Mitglieder, `active_theme=kisium`
- Produktion währenddessen unverändert

## Offsite-Backup (verifiziert 17.11.2026)

Zwei unabhängige Ziele, beide verschlüsselt mit restic:

- **REST-Server auf dem Monitoring-Host:** `/etc/cron.d/restic-offsite`, täglich 05:30, `/usr/local/sbin/restic-offsite.sh`, Env `/etc/restic/offsite.env`.
- **Hetzner Storage Box:** `/etc/cron.d/restic-offsite2`, täglich 06:30, `/usr/local/sbin/restic-offsite2.sh`, Env `/etc/restic/offsite2.env`.

Beide sichern `/opt/backups`, `/opt/kisium/backups`, `/home/[BENUTZER]/kisium-backups` und `/home/[BENUTZER]/monitor-secrets`; Retention 7 täglich / 4 wöchentlich / 6 monatlich; danach `restic check`.

**Verifiziert am 17.11.2026:** manueller Lauf beider Jobs um 14:26; Storage-Box-Snapshot `3f3e5c67` enthält `ghost-db-20261117-142614.sql.gz` und `ghost-content-20261117-142614.tar.gz`; DB-Gzip, Content-Tar sowie die Theme-Dateien `default.hbs`/`partials/post-card.hbs` geprüft.

Manuell anstoßen:

```bash
sudo /usr/local/sbin/restic-offsite.sh
sudo /usr/local/sbin/restic-offsite2.sh
```

Snapshots prüfen (Passwort bleibt in der Env-Datei):

```bash
sudo sh -c 'set -a; . /etc/restic/offsite2.env; restic snapshots'
```

## Produktions-Restore (Wartungsfenster)

1. Wartungsfenster ankündigen und aktuellen Zustand sichern.
2. Ghost stoppen:
   ```bash
   sudo docker compose -f /opt/kisium/docker-compose.yml stop ghost
   ```
3. Datenbank einspielen:
   ```bash
   sudo gunzip -c /opt/backups/ghost/ghost-db-<TS>.sql.gz \
     | docker exec -i kisium-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" ghost'
   ```
4. Content zurückspielen (überschreibt; vorher sichern):
   ```bash
   sudo tar -C /var/lib/docker/volumes/kisium_ghost_content/_data \
     -xzf /opt/backups/ghost/content-<TS>.tar.gz
   ```
5. Ghost starten:
   ```bash
   sudo docker compose -f /opt/kisium/docker-compose.yml up -d --no-deps ghost
   ```
6. Health und Smoke-Tests: `check-kisium.sh`, Startseite, Beitrag, Tag, Theme.

## Rollback

- Datenbank: vorheriges Dump einspielen.
- Content: vorheriges Content-Backup zurückspielen.
- Compose: Backup `docker-compose.yml.bak-<TS>` zurückkopieren.
- Theme: `active_theme=casper`, Ghost neu starten, `kisium`-Ordner entfernen.

## Hinweise

- `.env` und Backups sind root-only; mit `sudo` arbeiten.
- Ein Restore überschreibt die Produktion. Immer erst isoliert testen.
- Keine Passwörter in Tickets oder Chat kopieren.
