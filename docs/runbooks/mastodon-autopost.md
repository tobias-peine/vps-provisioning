# Mastodon-Auto-Poster

Stand 17.11.2026. Postet **neue** Blogartikel aus dem RSS-Feed einmalig auf
`https://mastodon.social/@kisium`. Keine Follows, Likes oder Antworten.

## Verhalten

- Quelle: `https://kisium.de/rss/`
- Erster Lauf: Baseline der vorhandenen Artikel, **nichts wird gepostet**.
- Danach: der neueste noch nicht gepostete Artikel wird veröffentlicht.
- Maximal **1 Post pro Tag**.
- `Idempotency-Key` pro Artikel verhindert Doppelposts bei Wiederholung.
- Caption: Titel, gekürzter Auszug, Link, bis zu vier Hashtags aus den RSS-Kategorien.
- Bei „keine neuen Artikel“ bleibt das Log still; Fehler werden geloggt.

## Komponenten

| Pfad | Zweck |
|---|---|
| `/opt/kisium/mastodon-autopost.py` | Skript, `700 root` |
| `/etc/kisium/mastodon.token` | Mastodon-Token, `600 root` |
| `/etc/cron.d/kisium-mastodon` | Cron, alle 15 Minuten |
| `/var/lib/kisium-mastodon/state.json` | bereits gepostete Links, `600 root` |
| `/var/log/kisium-mastodon.log` | Log, `640 root`, wöchentlich rotiert |

## Test

```bash
sudo /opt/kisium/mastodon-autopost.py --dry-run
```

Baseline neu setzen (postet nichts):

```bash
sudo /opt/kisium/mastodon-autopost.py --init
```

## Deaktivieren

```bash
sudo rm /etc/cron.d/kisium-mastodon
```

Optional Skript und Token entfernen:

```bash
sudo rm /opt/kisium/mastodon-autopost.py /etc/kisium/mastodon.token
sudo rm -rf /var/lib/kisium-mastodon
```

## Token-Rotation

1. In Mastodon unter **Einstellungen → Entwicklung** neuen Token erzeugen.
2. Lokal ablegen und auf den VPS kopieren:

```bash
sudo install -m 600 /dev/null /etc/kisium/mastodon.token
sudo nano /etc/kisium/mastodon.token
```

3. Nächsten Cron-Lauf abwarten oder `--dry-run` testen.

## Grenzen

- Nur neue RSS-Artikel; keine freien Texte, keine Interaktion.
- Max. 1 Post/Tag; dadurch keine Flut.
- Der Account ist kein Bot; die Automatisierung ist im Profil benannt.
- Bei API-Fehler wird der Artikel nicht als gepostet markiert; der nächste Lauf versucht es erneut.
