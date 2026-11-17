# Change-Log — kisium.de

Dieses Protokoll enthält ausschließlich verifiziert bestandene Änderungen.
Geplante oder verworfene Maßnahmen werden hier nicht geführt.

## 2026-11-17 — Welle 1

### W1.2 — HTTP/2 für kisium.de
- NPM-Host 8: `http2_support` von 0 auf 1 gesetzt; in `8.conf` `http2 off;` durch `http2 on;` ersetzt.
- `nginx -t` erfolgreich, anschließend `nginx -s reload` (kein Container-Neustart).
- **Verifiziert:** `curl -sI --http2 https://kisium.de/` → `HTTP/2 200`.
- Rollback: DB-Wert 0, in `8.conf` `http2 off;`, `nginx -t && nginx -s reload`.

### W1.1 — www.kisium.de und Zertifikat
- NPM-Host 8 um `www.kisium.de` erweitert; 301-Redirect auf `https://kisium.de$request_uri`.
- Let's-Encrypt-Zertifikat `npm-9` um `www.kisium.de` erweitert (ECDSA, gültig bis 2027-02-15).
- **Verifiziert:** SAN enthält beide Namen; `https://www.kisium.de/...` → 301 auf Apex (Pfad bleibt erhalten); Apex 200; HSTS unverändert; NPM und Stichproben anderer Vhosts healthy.
- **NPM-UI:** vom Betreiber geprüft und bestätigt (Host zeigt beide Domains, HTTP/2 an, Zertifikat mit beiden Namen, Redirect sichtbar).
- Rollback: DB und Config aus Backup zurücksetzen, `nginx -t && nginx -s reload`; Zertifikats-Rollback nur mit Backup und Freigabe.

### W1.3 — Lighthouse-Baseline
- Vier Läufe: Startseite und Beitrag, jeweils mobil und desktop; Lighthouse 13.6.0, lokaler Headless-Chromium.
- **Verifiziert:** Reports unter `reports/lighthouse/20261117-baseline/`.
- Kernergebnisse: Startseite mobil Performance 77 (TBT ~1.066 ms), Beitrag SEO 92 (Meta-Description fehlt), Accessibility 95/96 (Kontrast; Heading-Order im Beitrag).
- Hinweis: Laborwerte, keine Felddaten.

### F5 — Ghost-Image gepinnt
- `docker-compose.yml`: `ghost:6-alpine` → `ghost:6.77.0`; Tag auf Docker Hub vorhanden; `docker compose config --no-interpolate -q` erfolgreich.
- **Verifiziert:** Laufender Container unverändert (`ghost:6-alpine`), kein Neustart.

### Sicherung vor den Eingriffen
- NPM-Datenbank, Let's-Encrypt-Verzeichnis, `8.conf` und Compose-Datei gesichert (Pfade im Arbeitsprotokoll vom 17.11.2026).
- Vor W2: Ghost-Datenbank und Content-Volume gesichert (`/opt/backups/ghost/ghost-db-20261117-130910.sql.gz`, `content-20261117-130910.tar.gz`).

### W2.2b — SEO-Metadaten ergänzt
- 14 fehlende Meta-Descriptions ergänzt: 2 Beiträge, 2 Seiten, 9 Tags, 1 Autor.
- 3 zu lange Meta-Titel gekürzt (Ansible-VPS, Bewerbung, Server-als-Code).
- **Verifiziert:** erneuter Audit über 27 URLs — 27/27 Meta-Descriptions, 0 fehlende H1, 0 Heading-Order-Verletzungen, 0 Canonical-Abweichungen.
- Rollback: Ghost-DB-Backup einspielen.

### W2.1b — Theme `kisium` aktiviert
- Casper 5.12.5 plus Patch als Theme `kisium` installiert; `active_theme=kisium`; ein Ghost-Restart.
- **Verifiziert:** Tag-/Autor-Seiten mit H1, Beitrags-Byline als `<p>`, 27/27 H1, 0 Heading-Order-Verletzungen, HTTP/2 200, Ghost healthy.
- Rollback: `active_theme=casper` setzen, Ghost neu starten, `kisium`-Ordner entfernen.

### W1.2b — Ghost-Container auf 6.77.0 neu erstellt
- `docker compose up -d --no-deps ghost`; Image `ghost:6-alpine` → `ghost:6.77.0`; MySQL unverändert; kurze Downtime.
- Healthcheck nach Debian-Wechsel von `nc` auf Node umgestellt; Compose-Backup `/opt/backups/ghost/docker-compose.yml.bak-20261117-131909`.
- **Verifiziert:** Ghost healthy, HTTP/2 200, www 301, Theme `kisium`, 27/27 SEO, MySQL/NPM healthy.
- Rollback: Compose-Backup und altes Image; DB-/Content-Backup.

### W3.1 — Restore-Test bestanden
- Frisches Backup `20261117-131545`; isolierte temporäre DB und temporärer Container; Produktion unverändert.
- **Verifiziert:** HTTP 200, 16 Beiträge, 3 Mitglieder, `active_theme=kisium`; Cleanup danach.
- Runbook: `docs/runbooks/ghost-backup-restore.md`.

### W3.2/W3.3 — Runbooks und Check-Skript
- `docs/runbooks/ghost-update.md`, `docs/runbooks/monitoring.md`, `scripts/check-kisium.sh`.
- **Verifiziert:** Check-Skript auf dem VPS 7/7 PASS (HTTP/2, www-Redirect, TLS/SAN, Container, Backup-Alter, Disk).

### W3.3 — Health-Check als Cron installiert
- `/etc/cron.d/kisium-health-check` (alle 30 Minuten), Log `/var/log/kisium-health.log`, `logger` bei Fehler; Skript unter `/opt/kisium/check-kisium.sh`.
- **Verifiziert:** manueller Lauf als root rc=0, 7/7 PASS.
- Rollback: Cron-Datei und optional Skript entfernen.

### W2.1c — TBT: Portal lazy, Theme-Settings zurückgesetzt
- `default.hbs`: `{{ghost_head exclude="portal"}}` plus Lazy-Loader; Portal lädt erst bei Sign-in/Signup oder Direktlink `#/portal/...`; Suche bleibt initial (liefert den Content-Key).
- Theme-Aktivierung hatte Custom-Settings auf Defaults gesetzt: Cover an (119-KB-Logo als LCP), Header zentriert, moderne Schrift. Auf Casper-Werte zurückgesetzt: `show_publication_cover=false`, `header_style=Left aligned`, `title_font=Elegant serif`; Defaults im Patch angepasst.
- **Verifiziert:** initial kein Portal-Script-Tag, 0 Portal-Requests; Klick und Direktlink öffnen Portal; Suche funktioniert. Lighthouse mobil, 3 Läufe: TBT 0/119/140 ms (Median 119 ms) vs. Baseline 1.066 ms; CLS 0; Score 98–99; LCP 2.065–2.118 ms (Baseline 1.596 ms, noch darüber, im guten Bereich). Labor, keine Felddaten.
- Rollback: `default.hbs` aus `/opt/backups/ghost/default.hbs.bak-*`, Theme-Settings zurücksetzen oder `active_theme=casper`.

## Grenzen
- **Feld-CWV:** PSI/CrUX am 17.11.2026 mit Key geprüft: PSI 200, aber 0 Metriken; CrUX 404 für URL/Origin, Phone/Desktop. Keine Felddaten verfügbar. Bericht: `docs/field-cwv-20261117.md`.
