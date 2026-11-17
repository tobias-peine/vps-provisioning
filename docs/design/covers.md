# Cover-System für kisium.de

Stand 17.11.2026. Alle 13 Posts nutzen dasselbe Raster. Kontaktbogen:
`docs/seo/assets/covers-20261117-sheet.jpg`.

## Format

- **1600 × 880 px** (Seitenverhältnis 1,818) — die Post-Karte nutzt `padding-bottom: 55%`, dadurch kein Crop.
- JPEG, Qualität 87, 60–80 KB pro Bild.
- Sicherer Bereich: 92 px Rand; Titel max. 1180 px breit.

## Gestaltung

- Hintergrund: `#0a1120` → `#111b31`, Raster 52 px, zwei weiche Glows.
- Akzent: `#38bdf8` (eine Farbe für alle Posts, keine Regenbogen-Serie).
- Text: `#f8fafc`, Subtitle `#94a3b8`, Meta `#64748b`.
- Oben links: `KISIUM.DE / BLOG`.
- Oben rechts: Kategorie-Chip (z. B. `KARRIERE`, `BACKUP`, `SICHERHEIT`).
- Haupttitel: kurz, max. zwei Zeilen, 102–190 px, abhängig von der Länge.
- Subtitle: eine Zeile, 37 px.
- Unten links: Akzentlinie, `kisium.de · Linux, Docker, Homelab`.
- Rechts: große Archivnummer (01–13) als Watermark, 9 % Deckkraft.
- Keine vollständigen SEO-Titel auf dem Bild — die stehen direkt darunter auf der Karte.

## Archivnummern

| Nr. | Slug | Kurztitel | Kategorie |
|---:|---|---|---|
| 01 | `mein-weg-in-die-it` | Vom Koch zum Sysadmin | KARRIERE |
| 02 | `mein-homelab` | Mein Homelab | HOMELAB |
| 03 | `zertifikate` | Google IT Support | KARRIERE |
| 04 | `quereinstieg-koennen` | Was du wirklich können musst | KARRIERE |
| 05 | `it-berufe-quereinsteiger` | Welche IT-Berufe sind realistisch? | KARRIERE |
| 06 | `bewerbung-quereinsteiger` | Bewerbung als Quereinsteiger | KARRIERE |
| 07 | `ein-bot-der-fur-mich-auftrage-sucht` | Der Bot, der Aufträge sucht | AUTOMATION |
| 08 | `ansible-infrastruktur-als-code` | Server als Code | INFRASTRUKTUR |
| 09 | `ansible-356-sekunden` | 356 Sekunden | ANSIBLE |
| 10 | `patchday` | Patchday | BETRIEB |
| 11 | `grun-heisst-nicht-heil-drei-stille-ausfalle-an-einem-tag` | Drei stille Ausfälle | MONITORING |
| 12 | `ein-backup-ziel-das-einen-nachmittag-gebraucht-hat` | Ein Backup-Ziel | BACKUP |
| 13 | `vps-absichern-debian-checkliste` | VPS absichern | SICHERHEIT |

## Neue Posts

Neue Posts bekommen die nächste Nummer, eine Kategorie und einen Kurztitel nach
demselben Raster. Der vollständige Titel bleibt der Post-Titel; das Cover ist die
visuelle Klammer der Serie.
