# SERP-Metadaten — 17.11.2026

Angewendet über die Ghost Admin API. **H1 und Inhalt unverändert.** Backup des Ist-Stands: `/opt/backups/kisium-meta-20261117-1435.json` (600, root).

| Slug | Meta-Title | L | Meta-Description | L |
|---|---|---:|---|---:|
| `ein-backup-ziel-das-einen-nachmittag-gebraucht-hat` | VPS-Backup mit Hetzner Storage Box einrichten | 45 | Ein Backup-Ziel für den VPS einrichten: Hetzner Storage Box, 1 TB, 3,81 €/Monat – was länger dauerte als gedacht und was ich gelernt habe. | 138 |
| `grun-heisst-nicht-heil-drei-stille-ausfalle-an-einem-tag` | Server-Monitoring: drei stille Ausfälle an einem Tag | 52 | Drei Testalarme, die nie ankamen: Warum grüne Monitoring-Dashboards nichts beweisen und wie ich stille Ausfälle gefunden habe. | 126 |
| `patchday` | Patchday auf dem VPS: 17 Pakete und vier alte Fehler | 52 | Siebzehn Pakete, vier Stunden und vier Fehler, die schon vorher da waren: Was ein Reboot über den Server verrät und welche Checks wirklich zählen. | 146 |
| `ansible-356-sekunden` | Ansible auf einem VPS: 356 Sekunden und drei Fehler | 51 | Ein Wochenende Handarbeit in zwölf Ansible-Rollen: 356 Sekunden Laufzeit, drei Fehler erst auf der leeren Maschine – und was Ansible nicht löst. | 144 |
| `ansible-infrastruktur-als-code` | Infrastructure as Code: Server mit Ansible dokumentieren | 56 | Ich wollte den Server nur dokumentieren – und fand ein anderes Betriebssystem, mehr Container als gedacht und ein Passwort im Klartext. | 135 |
| `ein-bot-der-fur-mich-auftrage-sucht` | n8n-Bot: Freelance-Projekte automatisch finden | 46 | Wie ich mit n8n, DeepSeek und MySQL einen Bot gebaut habe, der täglich Freelance-Projekte findet – mit Zahlen, Fehlern und Kosten. | 130 |
| `bewerbung-quereinsteiger` | Bewerbung als Quereinsteiger: Worauf es ankommt | 47 | Nicht fehlende Erfahrung ist das Problem, sondern fehlende Belege: Was ein Beleg ist und die drei Sätze, auf die es in der Bewerbung ankommt. | 141 |
| `it-berufe-quereinsteiger` | IT-Berufe für Quereinsteiger: Was realistisch ist | 49 | Data Science, Cloud, Security: Die üblichen Listen empfehlen Einstiege, die ohne Erfahrung niemand besetzt. Welche drei Türen wirklich aufgehen. | 144 |
| `quereinstieg-koennen` | Quereinstieg in die IT: Was du wirklich können musst | 52 | Sechs Fähigkeiten entscheiden über den Quereinstieg – keine davon ist ein Zertifikat. Mit Selbsttest und der Reihenfolge, in der ich sie gelernt habe. | 150 |
| `zertifikate` | Google IT Support Zertifikat: Erfahrungen und Kosten | 52 | Sechs Wochen, rund 80 Stunden, auf Deutsch und über Financial Aid finanziert: Was das Google-IT-Support-Zertifikat bringt – und wo es nicht hilft. | 146 |
| `mein-homelab` | Mein Homelab: VPS, Docker und drei teure Fehler | 47 | Ein kleiner VPS, ein Reverse Proxy und sechs Container – und drei Fehler, an denen ich hängen geblieben bin. Was ich dabei gelernt habe. | 136 |
| `mein-weg-in-die-it` | Vom Koch zum Cloud-Sysadmin: Mein Quereinstieg | 46 | Vom Koch zum Cloud-Sysadmin: Wie ich ohne Studium in die IT wechsle, welche Coursera-Kurse helfen und warum ich über den Support einsteige. | 139 |

## Verifikation

- Alle 12 Seiten: `<title>` = Meta-Title, Meta-Description = gesetzter Text.
- Keine doppelten Titles; Längen 45–56 (Title) und 126–150 (Description).
- H1 bleibt der erzählerische Originaltitel; keine URL-Änderung.

## Autoren-Schema

- Ghost-Profil: Website `https://github.com/tobias-peine`, LinkedIn-Handle `tobias-peine`.
- Article-`author.sameAs`: `["https://github.com/tobias-peine","https://www.linkedin.com/in/tobias-peine"]`.
- Autorenseite `/author/tobias/` verlinkt GitHub und LinkedIn.

## Rollback

- Metadaten: Werte aus dem Backup per Admin API zurückschreiben (oder Matrix oben leeren).
- Autor: `website=NULL, linkedin=NULL` für `slug=tobias`, danach Ghost-Restart.
