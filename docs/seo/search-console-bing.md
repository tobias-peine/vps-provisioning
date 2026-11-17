# Search Console + Bing einrichten

Ziel: Query-, Index- und CTR-Daten für kisium.de. Ohne diese Daten ist jede weitere SEO-Änderung geraten.

## Stand 17.11.2026

- Ein Google-Verifikations-Meta-Tag ist bereits in der Ghost **Code Injection** (`codeinjection_head`) gesetzt und im HTML sichtbar.
- Damit ist die URL-Prefix-Property `https://kisium.de/` technisch verifizierbar. Ob die Property im Google-Konto existiert, ist ohne Login **unverifiziert**.
- Die Sitemap `https://kisium.de/sitemap.xml` ist gültig und in `robots.txt` referenziert.
- Nächster Schritt: Login, Property prüfen, Sitemap bestätigen, Performance-Export.

## Google Search Console

1. [search.google.com/search-console](https://search.google.com/search-console) öffnen.
2. Property `kisium.de` als **Domain-Property** anlegen (empfohlen; umfasst www/apex).
3. Verifizierung:
   - **DNS-TXT** bei der Domain-Verwaltung setzen, oder
   - **HTML-Tag** in Ghost unter Code Injection → Site Header, oder
   - **HTML-Datei** im Ghost-Content-Root (weniger sauber).
4. Sitemap einreichen: `https://kisium.de/sitemap.xml`.
5. Unter „Indexierung → Seiten“ prüfen:
   - Welche 12 Posts sind indexiert?
   - „Gefunden – zurzeit nicht indexiert“ → Backlinks/Content, nicht Technik.
6. Unter „Leistung“ nach 7/28 Tagen prüfen: Queries, Impressionen, CTR, Position, Land/Gerät.
7. Core Web Vitals: Für kisium.de liegen aktuell **keine CrUX-Felddaten** vor (17.11.2026). Der Report bleibt leer, bis Traffic vorhanden ist.

**Export für die Auswertung:** Leistung → Export → CSV/Google Sheets; Datei nach `docs/seo/` legen. Keine Zugangsdaten nötig.

## Bing Webmaster Tools

1. [bing.com/webmasters](https://www.bing.com/webmasters) öffnen.
2. Property aus Search Console importieren oder `kisium.de` hinzufügen.
3. Sitemap `https://kisium.de/sitemap.xml` einreichen.
4. IndexNow optional; Ghost hat keinen eingebauten Ping — nur mit Plugin/Skript sinnvoll.

## Was ich damit mache

- Queries mit Impressionen aber niedriger CTR → Meta-Title/Description schärfen.
- Seiten auf Position 5–15 → interne Links und Tiefe ausbauen.
- Seiten ohne Impressionen → Search Intent prüfen, ggf. Titel/Inhalt ändern.
- Länder/Geräte: deutsche Long-Tail-Queries priorisieren.

## Datenschutz

- Keine Search-Console-Passwörter oder 2FA-Codes teilen.
- Ein CSV-Export oder ein Service-Account mit `webmasters.readonly` reicht.
- Keine Analytics-Skripte ohne Datenschutz-Entscheidung einbauen.
