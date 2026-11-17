# Theme-Fork „kisium“ (Casper-Patch)

**Basis:** Casper 5.12.5, aktives Theme am 17.11.2026 (aus dem Ghost-Container extrahiert).
**Patch:** `kisium-casper.patch` (162 Zeilen, 5 Dateien). Kein vollständiger Theme-Klon, sondern ein nachvollziehbarer Diff.

## Enthalten

- `tag.hbs`: Archivtitel `<h2 class="post-card-title">` → `<h1>` — behebt die fehlende H1 auf allen 9 Tag-Seiten.
- `author.hbs`: Archivtitel `<h2 class="post-card-title">` → `<h1>` — behebt die fehlende H1 auf der Autor-Seite.
- `post.hbs`: Byline `<h4 class="author-name">{{authors}}</h4>` → `<p class="author-name">` — behebt die Heading-Order in allen 12 Beiträgen (H1 → H4 → H2).
- `default.hbs`: `{{ghost_head exclude="portal"}}` plus kleiner Lazy-Loader. Portal wird erst bei Sign-in/Signup oder Direktaufruf `#/portal/...` geladen; die Suche bleibt initial (liefert den Content-Key).
- `package.json`: `name` → `kisium`, `version` → `0.1.0`; Defaults für `show_publication_cover=false`, `header_style=Left aligned`, `title_font=Elegant serif` (Casper-Baseline).

## Bewusst nicht enthalten

- **Suche:** bleibt initial, weil das Sodo-Search-Script den öffentlichen Content-Key im `data-key` trägt; der TBT-Anteil ist klein (~95 ms).
- **Kontrast `span.k-chrome-title`:** stammt aus der Ghost-Code-Injection (Site Footer), nicht aus dem Theme.
- **Meta-Descriptions und Titel:** Ghost-Inhalte (W2.2b).

## Anwendung (erfolgt am 17.11.2026)

```bash
cp -a casper kisium
cd kisium
patch -p1 < ../kisium-casper.patch
```

Am 17.11.2026 als Theme installiert und aktiviert. Nach der Aktivierung prüfen bzw. setzen:

- `show_publication_cover = false`
- `header_style = Left aligned`
- `title_font = Elegant serif`

Sonst wird das 119-KB-Cover zum LCP. Die Defaults im Patch sind bereits entsprechend gesetzt; bestehende Themes brauchen die expliziten Werte.

**Portal-Version:** Der Lazy-Loader nutzt `portal@~2.72` (aus Ghost-Defaults). Bei einem Ghost-Update den Wert in `default.hbs` prüfen und anpassen.

## Verifikation (17.11.2026)

- Initial-HTML: kein Portal-Script-Tag; 0 Portal-Requests vor Interaktion.
- Sign-in/Signup-Klick und Direktlink `#/portal/signin` öffnen Portal (Iframe).
- Suche funktioniert weiter.
- Lighthouse mobil, 3 Läufe: **TBT 0 / 119 / 140 ms, Median 119 ms** (Baseline 1.066 ms); CLS 0; Score 98–99.
- LCP 2.065–2.118 ms (Baseline 1.596 ms) — noch über Baseline, aber im „good“-Bereich. Labor, keine Felddaten.

## Rollback

In Ghost zurück auf `casper` schalten; den `kisium`-Ordner entfernen. Wurde direkt über die DB umgeschaltet, zusätzlich `active_theme='casper'` setzen und `docker restart kisium-ghost`. Für nur den Portal-Loader: `default.hbs` aus `/opt/backups/ghost/default.hbs.bak-*` zurückholen und Ghost neu starten.

## Status

**Installiert und aktiviert am 17.11.2026.** Aktives Theme: `kisium` (Ghost 6.77.0). Der Patch bleibt die Quelle; auf dem Server liegt der Ordner `kisium` im Content-Volume.
