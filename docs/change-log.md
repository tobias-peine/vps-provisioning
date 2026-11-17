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
