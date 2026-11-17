# 30-Tage-Plan: Sichtbarkeit kisium.de

Stand 17.11.2026. Technische Basis: 12 Posts, 9 Tags, 5 Seiten; Canonical, Sitemap, RSS, `Article`-Schema, keine Noindex-Seiten. SERP-Metadaten und Autor-`sameAs` sind gesetzt. **Der Engpass ist Autorität, Suchintention und Distribution — nicht TBT.**

## Zielgruppen und Cluster

| Cluster | Bestehende Posts | Pillar-Idee |
|---|---|---|
| Quereinstieg/Karriere | `zertifikate`, `bewerbung-quereinsteiger`, `it-berufe-quereinsteiger`, `quereinstieg-koennen`, `mein-weg-in-die-it` | „Quereinstieg als Sysadmin: Portfolio statt Zertifikate“ |
| VPS/Homelab | `mein-homelab`, `ein-backup-ziel…`, `patchday` | „VPS absichern: Checkliste für Debian“ |
| Ansible/Automation | `ansible-356-sekunden`, `ansible-infrastruktur-als-code` | „Ansible für Einsteiger: Inventory, Playbook, Idempotenz“ |
| Backup/Monitoring | `ein-backup-ziel…`, `grun-heisst-nicht-heil…`, `patchday` | „Backup-Strategie für den VPS: 3-2-1 und Restore-Test“ |

## 30 Tage

| Woche | Fokus | Konkret |
|---|---|---|
| 1 | Messen + Quick Wins | Search Console/Bing, Sitemap, Baseline; Meta-Titles sind gesetzt; 3 alte Posts mit internen Links auf die Cluster-Pillars versehen |
| 2 | Pillar 1 + 2 | „VPS absichern“ und „Ansible für Einsteiger“ schreiben; je 4–5 Links in bestehende Posts und zurück |
| 3 | Distribution | LinkedIn 1×, GitHub-README, Mastodon, 2 Community-Antworten; Newsletter-CTA; Signup testen |
| 4 | Pillar 3 + Backlinks | „Docker-Compose-Backup“; 5 relevante Backlink-Anfragen; GSC-Daten auswerten, nächsten Monat planen |

## Acht konkrete Artikel-Ideen

Zielquery = Hypothese, keine Volumenschätzung. Vor dem Schreiben in Search Console prüfen.

| Arbeitstitel | Zielquery / Intent | Interne Links |
|---|---|---|
| VPS absichern: Checkliste für Debian 13 | „VPS absichern Debian“ — How-to | Homelab, Backup, Patchday |
| Ansible für Einsteiger: Inventory, Playbook, Idempotenz | „Ansible Tutorial deutsch“ — Tutorial | Ansible-Posts, Homelab |
| Docker-Compose-Backup: MySQL, Volumes, Restore | „Docker Backup MySQL Volume“ — How-to | Backup-Ziel, Patchday |
| Uptime Kuma vs. Prometheus fürs Homelab | „Uptime Kuma Prometheus“ — Vergleich | Monitoring, Homelab |
| Quereinstieg als Sysadmin: Portfolio statt Zertifikate | „Quereinstieg Sysadmin Portfolio“ — Career | alle Career-Posts |
| Ghost 6 auf dem VPS: Update ohne Ausfall | „Ghost Update Docker“ — How-to | Backup, Patchday |
| Linux-Server-Härtung: SSH, Firewall, Updates | „Linux Server hardening“ — Checkliste | VPS, Monitoring |
| Homelab-Monitoring: was ich wirklich brauche | „Homelab Monitoring“ — Erfahrung | Homelab, Uptime Kuma |

Format: echtes Problem → Entscheidung → Befehle/Code → Fehler → Messung/Ergebnis. 1.200–2.000 Wörter, ein klarer Search Intent, 3–5 interne Links.

## Interne Verlinkung

- Jeder neue Pillar verlinkt 4–5 bestehende Posts; jeder bestehende Post bekommt einen Link zum passenden Pillar.
- Ankertext beschreibt das Problem („Backup mit restic prüfen“), nicht „hier klicken“.
- Tag-Seiten als Hubs nutzen: kurze Einleitung (2–3 Sätze) pro Tag, dann die Posts.
- Der bestehende „Read more“-Block zeigt die letzten 3 Posts; zusätzlich cluster-relevante Links im Text setzen.

## Distribution

- **LinkedIn:** 1× pro Woche; Story + konkreter Fehler + Link. Ziel: Recruiter/Sysadmins.
- **GitHub:** Profil-README und `vps-provisioning`-Docs verlinken die passenden Posts.
- **Mastodon:** Tech-Community, 1–2× pro Woche.
- **Reddit:** r/sysadmin, r/linuxadmin, r/de_EDV — nur hilfreiche Antworten, kein Link-Dump.
- **dev.to/Medium:** Artikel mit `canonical` auf kisium.de.
- **Deutsche Communities:** administrator.de, linuxforen.de — Mehrwert zuerst.
- **Hacker News:** nur bei einer starken technischen Geschichte.

## Backlinks

Ziel: 5–10 **relevante** Links in 30 Tagen, keine gekauften Links.

- Open-Source-Projekte, die du nutzt: Docs/README.
- Gastartikel auf deutschen DevOps-/Linux-Blogs.
- Podcast/Interview, lokale User Group.
- Antworten auf Stack Overflow/Reddit mit vertiefendem Link.
- LinkedIn-/GitHub-Profil als Portfolio-Einstieg.

## Messung

Wöchentlich: indexierte Seiten, Impressionen, Klicks, CTR, durchschnittliche Position, Referring Domains, Newsletter-Anmeldungen, GitHub-/LinkedIn-Klicks.

Monatlich: Seiten mit Impressionen aber niedriger CTR → Title/Description überarbeiten; Seiten auf Position 5–15 → interne Links und Tiefe ausbauen.

**Ziele (keine Garantie):** 12/12 Posts indexiert; 5 neue relevante Referring Domains; 3 Long-Tail-Queries in den Top 10; erste Newsletter-Anmeldungen.

## Search Console / Bing

Siehe `docs/seo/search-console-bing.md`. Ohne Query-Daten bleibt die Title-Optimierung eine Hypothese.
