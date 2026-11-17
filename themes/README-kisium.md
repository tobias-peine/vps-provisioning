# Theme-Fork „kisium“ (Casper-Patch)

**Basis:** Casper 5.12.5, aktives Theme am 17.11.2026 (aus dem Ghost-Container extrahiert).
**Patch:** `kisium-casper.patch` (51 Zeilen, 4 Dateien). Kein vollständiger Theme-Klon, sondern ein nachvollziehbarer Diff.

## Enthalten

- `tag.hbs`: Archivtitel `<h2 class="post-card-title">` → `<h1>` — behebt die fehlende H1 auf allen 9 Tag-Seiten.
- `author.hbs`: Archivtitel `<h2 class="post-card-title">` → `<h1>` — behebt die fehlende H1 auf der Autor-Seite.
- `post.hbs`: Byline `<h4 class="author-name">{{authors}}</h4>` → `<p class="author-name">` — behebt die Heading-Order in allen 12 Beiträgen (H1 → H4 → H2).
- `package.json`: `name` → `kisium`, `version` → `0.1.0`, Beschreibung angepasst (Fork-Kennung).

## Bewusst nicht enthalten

- **Kontrast `span.k-chrome-title`:** stammt aus der Ghost-Code-Injection (Site Footer), nicht aus dem Theme.
- **`portal.min.js` / `sodo-search.min.js`:** werden von Ghost-Core bzw. CDN injiziert, nicht vom Theme. Eine Reduzierung braucht Ghost-Einstellungen oder Code-Injection, keinen Theme-Patch.
- **Meta-Descriptions und Titel:** Ghost-Inhalte (W2.2b).

## Anwendung (erfolgt am 17.11.2026)

```bash
cp -a casper kisium
cd kisium
patch -p1 < ../kisium-casper.patch
```

Am 17.11.2026 als Theme installiert und aktiviert (ein Ghost-Restart).

## Rollback

In Ghost zurück auf `casper` schalten; den `kisium`-Ordner entfernen. Wurde direkt über die DB umgeschaltet, zusätzlich `active_theme='casper'` setzen und `docker restart kisium-ghost`.

## Status

**Installiert und aktiviert am 17.11.2026.** Aktives Theme: `kisium` (Ghost 6.77.0). Der Patch bleibt die Quelle; auf dem Server liegt der Ordner `kisium` im Content-Volume.
