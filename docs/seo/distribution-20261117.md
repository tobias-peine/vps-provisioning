# Distribution: VPS-Pillar

Stand 17.11.2026. Keine automatischen Posts — die Texte sind Vorlagen, keine Einladung zum Link-Dump.

## LinkedIn

> Die meisten VPS-Anleitungen fangen mit der Firewall an. Ich würde mit dem SSH-Zugang anfangen.
>
> Auf meinem Server habe ich die Reihenfolge einmal aufgeschrieben, die bei mir hängen geblieben ist: Schlüssel statt Passwort, Root-Login aus, dann erst Ports. Danach Updates, Docker-Ports prüfen, TLS, Backups und ein Alarm, der wirklich ankommt.
>
> Der unangenehmste Teil: Docker kann an ufw vorbei. Ein `0.0.0.0:3306` ist keine Kleinigkeit.
>
> Checkliste: https://kisium.de/vps-absichern-debian-checkliste/

## GitHub-Profil / README

> **Blog:** [VPS absichern: Debian-Checkliste](https://kisium.de/vps-absichern-debian-checkliste/) — SSH, Firewall, Docker-Fallen, TLS, Backups, Monitoring.

## Mastodon

> Neue Checkliste: VPS absichern unter Debian/Ubuntu. SSH zuerst, dann Firewall — und Docker-Ports separat prüfen. Mit Befehlen und den Fallen, die in Anleitungen oft fehlen.
> https://kisium.de/vps-absichern-debian-checkliste/

## Reddit / Foren

Nicht als eigener Link-Post. In einem passenden Thread als Antwort:

> Zwei Dinge, die bei VPS-Härtung oft untergehen: Docker veröffentlicht Ports an ufw vorbei (`docker ps --format 'table {{.Names}}\t{{.Ports}}'` prüfen), und ein Backup ohne Restore-Test ist nur ein Hoffnungswert. Ich habe meine Reihenfolge hier aufgeschrieben: [Link] — falls es hilft.

## Reihenfolge

1. LinkedIn (persönlicher Account, 1×).
2. GitHub-README/Profil.
3. Mastodon.
4. Zwei Community-Antworten mit echtem Mehrwert.
5. Nach 7 Tagen: Search-Console-Daten prüfen, Title/Description ggf. nachschärfen.

## Status

- **17.11.2026:** Mastodon `@kisium` eingerichtet (Bio, Avatar, Header, vier Profilfelder, discoverable); VPS-Post veröffentlicht; Auto-Poster für neue RSS-Artikel aktiv (max. 1/Tag).
- **17.11.2026:** LinkedIn-Post und Bild vorbereitet (`docs/seo/linkedin-vps-post.md`); Veröffentlichung manuell oder per API-Token noch offen.
