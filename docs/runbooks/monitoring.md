# Monitoring-Checkliste — kisium.de

Stand: 17.11.2026.

## Vorhandene Automatik

- `/etc/cron.d/kisium-backup` — täglich 03:00 Uhr Backup.
- `/etc/cron.d/ghost-backup-check` — täglich 05:00 Uhr Backup-Prüfung.
- `/etc/cron.d/restore-test` — täglich 04:00 Uhr; **Paperless**, nicht Ghost.
- `/etc/cron.d/kisium-tls-renew` — TLS-Erneuerung.
- Die genaue Alarmkette ist nicht Teil dieses Dokuments; Details sind **unverifiziert**.

## Check-Skript

`scripts/check-kisium.sh` läuft auf dem VPS (root oder mit `sudo -n` für Backup-Zugriff):

```bash
sudo bash scripts/check-kisium.sh
```

Geprüft wird:

1. Apex `https://kisium.de/` = HTTP/2 200.
2. `https://www.kisium.de/` = 301 auf `https://kisium.de/`.
3. TLS-Zertifikat: mindestens 21 Tage gültig, SAN enthält `www.kisium.de`.
4. Container `kisium-ghost` und `npm` = `healthy`.
5. Letztes Ghost-DB-Backup ist jünger als 26 Stunden.
6. Root-Disk unter 85 %.

Exit-Code 1 bei einem Fehler; Ausgabe `OK`/`FAIL` je Prüfung.

## Empfohlene Kadenz

- Nach jedem Deploy/Update.
- Täglich per externem Cron oder bestehender Alarmkette.
- Zusätzlich wöchentlich ein manueller Blick auf Backup-Größen und Cert-Ablauf.

## Grenzen

- Keine Feld-Core-Web-Vitals; Lighthouse ist Labor.
- Kein echter Admin-Login-Test (keine Admin-Zugangsdaten im Skript).
- Kein Ersatz für externes Uptime-Monitoring.
- Die Portal-/Such-Skripte werden nicht bewertet.
