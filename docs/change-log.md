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

### W2.1d — LCP: erstes Post-Bild eager/high
- `partials/post-card.hbs`: erstes Bild `loading="eager"` + `fetchpriority="high"`, übrige Bilder bleiben `loading="lazy"`.
- **Verifiziert:** HTML erstes Bild eager/high, übrige lazy; Lighthouse mobil, 5 Läufe: TBT 440/75/44/94/286 ms (Median 94), LCP 2.427/1.257/1.248/1.139/2.207 ms (Median 1.257); CLS 0/0/0,109/0/0; Score 87–100. Baseline TBT 1.066, LCP 1.596. Zwei Ausreißer (Lauf 1/5), Median belastbarer.
- Rollback: Zeile in `partials/post-card.hbs` auf `loading="lazy"` zurück, oder `active_theme=casper`.

### W3.4 — E-Mail-Alarm verifiziert
- `check-kisium.sh` ruft bei `FAIL` `/opt/kisium/send-alert.py` auf; SMTP aus `/opt/kisium/.env`; 6h-Cooldown, State `/var/lib/kisium-health.last-alert`.
- **Verifiziert:** Testmail `alert_sent`, zweiter Lauf `alert_suppressed`; State danach zurückgesetzt; Check weiter `PASS`.
- Rollback: Helper und Aufruf entfernen; Cron bleibt reines Logging.

### W2.1e — Portal-Mitglieder-Login E2E
- Temporären Member per Admin-API angelegt, Signin-Link (`/members/:id/signin_urls`) erzeugt, mit Playwright eingelöst; Header zeigte den Account-Link; Member danach gelöscht.
- **Verifiziert:** Login erfolgreich; keine dauerhafte Mitgliederänderung (Bestand wieder 3).

### W3.5 — Offsite-Backup verifiziert
- Bestehende restic-Ziele: REST-Server (05:30) und Hetzner Storage Box (06:30); beide liefen am 17.11. erfolgreich.
- Manueller Lauf 14:26; Snapshot `3f3e5c67` enthält `ghost-db-20261117-142614.sql.gz` und `ghost-content-20261117-142614.tar.gz`; DB-Gzip, Content-Tar sowie Theme-Dateien und `custom_theme_settings` geprüft.
- Keine neue Konfiguration nötig; Runbook ergänzt.

### W2.1f — SERP-Metadaten + Autor-Schema
- 12 Posts: `meta_title`/`meta_description` gesetzt; H1 und URLs unverändert; keine doppelten Titles; Längen 45–56 (Title), 126–150 (Description).
- Autor: `website=https://github.com/tobias-peine`, LinkedIn-Handle `tobias-peine`; Article-`author.sameAs` enthält GitHub und LinkedIn; Autorenseite verlinkt beide.
- Admin-API-Tokens dürfen `/users/` nicht ändern (403); Profil daher per DB gesetzt. Backups: `/opt/backups/kisium-meta-20261117-1435.json`, `/opt/backups/kisium-user-20261117-1438.json` (600, root).
- **Verifiziert:** `<title>`/Description auf allen 12 Seiten, `sameAs` im Article-Schema, Autorenseite. Matrix: `docs/seo/meta-titles-20261117.md`.
- Plan: `docs/seo/content-plan-30d.md`, Search Console/Bing: `docs/seo/search-console-bing.md`.

### W2.1g — Pillar „VPS absichern“ veröffentlicht
- Neuer Post: `https://kisium.de/vps-absichern-debian-checkliste/`; 13. Post in der Sitemap; Tags `VPS`, `Sicherheit`, `Homelab`; 12 Codeblöcke, 7 interne Links; eigenes 44-KB-Cover.
- Kein Newsletter-Versand (`email_recipient_filter=none`).
- **Verifiziert:** HTTP 200, Title/Description/H1, Codeblöcke, Sitemap 13 Posts, Startseite erstes Bild eager; Lighthouse mobil 3 Läufe: TBT 177/75/26 ms (Median 75), LCP 2.088/2.032/1.242 ms (Median 2.032), CLS 0/0,109/0,109.
- Tag-Seiten `VPS` und `Sicherheit` mit Meta-Title/Description ergänzt; SEO-Audit danach **30/30**.

### W3.6 — Mastodon-Auto-Poster
- Neuer Artikel aus `https://kisium.de/rss/` → einmaliger öffentlicher Post auf `@kisium`; Baseline beim ersten Lauf, max. 1 Post/Tag, `Idempotency-Key`, State `/var/lib/kisium-mastodon/state.json`.
- Installiert: `/opt/kisium/mastodon-autopost.py` (700), `/etc/kisium/mastodon.token` (600 root), Cron alle 15 Minuten, Logrotate wöchentlich.
- **Verifiziert:** Baseline 13 Artikel ohne Post; Dry-Run danach „keine neuen Artikel“; Caption 310 Zeichen; Cron aktiv; Log leer.
- Rollback: `/etc/cron.d/kisium-mastodon` entfernen; Details: `docs/runbooks/mastodon-autopost.md`.

### W2.1h — Zertifikat-Post datengetrieben ausgebaut
- Search-Console-Baseline: `/zertifikate/` Position 7,73 (Query „google it support zertifikat“ 9,33).
- Ergänzt: „Lohnt sich das Google IT Support Zertifikat 2026?“, Entscheidungsmatrix, Alternativen (CompTIA A+/Network+, LPI, AWS/Azure), drei neue FAQ; interne Links zu IT-Berufen, Quereinstieg und Bewerbung.
- Meta-Description auf 140 Zeichen aktualisiert; H1 unverändert. Ist-Post gesichert: `/opt/backups/kisium-post-zertifikate-20261117-1540.json`.
- **Verifiziert:** HTTP 200, H1=1, H2=15, H3=12, 2 Tabellen; SEO-Audit 30/30; DB-Backup enthält den neuen Abschnitt.

### W2.1i — Einheitliche Titelbilder
- Alle 13 Posts erhalten neue 1600×880-Cover aus einem Raster: dunkles Grid, eine Akzentfarbe, Kategorie-Chip, Kurztitel, Archivnummer 01–13; Alt-Texte gesetzt.
- Alte Post-/Cover-Metadaten gesichert: `/opt/backups/kisium-posts-covers-20261117-1545.json`.
- **Verifiziert:** 13/13 neue Feature-URLs, 13/13 Alt-Texte, Startseite im 3er-Raster, SEO-Audit 30/30. Lighthouse mobil 3 Läufe: TBT 122/67/160 ms (Median 122), LCP 1.275/1.276/1.308 ms (Median 1.276), CLS 0,109/0/0.
- Design: `docs/design/covers.md`; Kontaktbogen: `docs/seo/assets/covers-20261117-sheet.jpg`.

### W2.1j — Interne Links zum VPS-Pillar
- Vier technische Posts verlinken jetzt kontextuell auf `/vps-absichern-debian-checkliste/`: `mein-homelab`, `patchday`, `ansible-infrastruktur-als-code` und `ein-backup-ziel…`.
- Das Backup-Ziel hatte vorher **null** interne Links; es verlinkt jetzt zusätzlich auf Patchday und Homelab.
- **Verifiziert:** Marker in allen vier Posts, SEO-Audit 30/30; alte Post-Metadaten unter `/opt/backups/kisium-posts-internallinks-20261117.json`.

### W2.1k — Bewerbung-Post vertieft
- Neue Abschnitte: kopierbare **Anschreiben-Vorlage**, **drei häufigste Fehler**, **10-Punkte-Checkliste vor dem Absenden**.
- Meta-Description auf 130 Zeichen aktualisiert; H1 unverändert; interne Links auf Homelab, Zertifikat und IT-Berufe.
- **Verifiziert:** HTTP 200, H1=1, H2=13, H3=3, Codeblock=1, 35 Listeneinträge; SEO-Audit 30/30.
- Ist-Post gesichert: `/opt/backups/kisium-post-bewerbung-20261117.json`.

### W2.1l — Backlink-Baseline
- Search-Console-Links-Export „More sample links“ (17.11.): nur Kopfzeile, 0 Datenzeilen. Keine externen Links in diesem Export sichtbar; außerhalb des Exports unverifiziert.
- Backlink-Plan mit Prinzipien, Zielgruppen, Outreach-Vorlage und Tracking: `docs/seo/backlinks-20261117.md`; Export: `docs/seo/search-console/2026-11-17/Links-sample.csv`.

## Grenzen
- **Feld-CWV:** PSI/CrUX am 17.11.2026 mit Key geprüft: PSI 200, aber 0 Metriken; CrUX 404 für URL/Origin, Phone/Desktop. Keine Felddaten verfügbar. Bericht: `docs/field-cwv-20261117.md`.
