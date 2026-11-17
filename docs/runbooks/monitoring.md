# Monitoring-Checkliste — kisium.de

Stand: 17.11.2026.

## Vorhandene Automatik

- `/etc/cron.d/kisium-backup` — täglich 03:00 Uhr Backup.
- `/etc/cron.d/ghost-backup-check` — täglich 05:00 Uhr Backup-Prüfung.
- `/etc/cron.d/restore-test` — täglich 04:00 Uhr; **Paperless**, nicht Ghost.
- `/etc/cron.d/kisium-tls-renew` — TLS-Erneuerung.
- Die genaue Alarmkette ist nicht Teil dieses Dokuments; Details sind **unverifiziert**.

## Check-Skript und Cron

Quelle im Repo: `scripts/check-kisium.sh`. Installiert auf dem VPS: `/opt/kisium/check-kisium.sh`.
Cron: `/etc/cron.d/kisium-health-check`, alle 30 Minuten, Log `/var/log/kisium-health.log`; bei Exit 1 zusätzlich `logger -t kisium-health "check failed"`.

Manuell:

```bash
sudo /opt/kisium/check-kisium.sh
```

Geprüft wird:

1. Apex `https://kisium.de/` = HTTP/2 200.
2. `https://www.kisium.de/` = 301 auf `https://kisium.de/`.
3. TLS-Zertifikat: mindestens 21 Tage gültig, SAN enthält `www.kisium.de`.
4. Container `kisium-ghost` und `npm` = `healthy`.
5. Letztes Ghost-DB-Backup ist jünger als 26 Stunden.
6. Root-Disk unter 85 %.

Exit-Code 1 bei einem Fehler; Ausgabe `OK`/`FAIL` je Prüfung.

## Kadenz, Alarmierung und Rollback

- Cron: alle 30 Minuten; nach jedem Deploy/Update zusätzlich manuell.
- Bei `FAIL` sendet `check-kisium.sh` eine E-Mail über den vorhandenen Ghost-SMTP (`/opt/kisium/send-alert.py`) an `MAIL_USER` (optional `ALERT_TO`), mit **6h-Cooldown** und State `/var/lib/kisium-health.last-alert`.
- Test: `printf "Test\n" | sudo /opt/kisium/send-alert.py --force --subject "[kisium] Alert-Test"`.
- Der `logger`-Eintrag bleibt zusätzlich; der verifizierte Alarmkanal ist E-Mail.
- Wöchentlich Backup-Größen und Cert-Ablauf prüfen.
- Rollback: Aufruf in `check-kisium.sh` und `/opt/kisium/send-alert.py` entfernen; Cron bleibt reines Logging.

## Feld-Core-Web-Vitals

- Abruf am 17.11.2026 mit API-Key: PSI **HTTP 200**, aber `loadingExperience` und `originLoadingExperience` mit **0 Metriken**.
- CrUX API: **HTTP 404 `chrome ux report data not found`** für URL und Origin, Phone und Desktop.
- Ergebnis: **keine Felddaten** für kisium.de (zu wenig reale Nutzung); nicht „gut“, nicht „schlecht“. Bericht: `docs/field-cwv-20261117.md`.
- Lighthouse bleibt Labor. Für echte Feldwerte: mehr Traffic, Search Console oder RUM (Datenschutzentscheidung, nicht installiert).

## Grenzen

- Keine Feld-Core-Web-Vitals; Lighthouse ist Labor.
- Kein echter Admin-Login-Test (keine Admin-Zugangsdaten im Skript).
- Kein Ersatz für externes Uptime-Monitoring.
- Die Portal-/Such-Skripte werden nicht bewertet.
