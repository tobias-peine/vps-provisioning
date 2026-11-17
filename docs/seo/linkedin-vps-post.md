# LinkedIn-Post: VPS absichern

Stand 17.11.2026. **Noch nicht veröffentlicht** — für LinkedIn fehlt ein API-Token
oder ein manueller Post. Bild: `docs/seo/assets/linkedin-vps-absichern.jpg` (1200×627).

## Text

> Die meisten VPS-Anleitungen fangen mit der Firewall an. Ich würde mit dem SSH-Zugang anfangen.
>
> Auf meinem Server habe ich die Reihenfolge aufgeschrieben, die bei mir hängen geblieben ist: Schlüssel statt Passwort, Root-Login aus, dann erst Ports. Danach Updates, Docker-Ports prüfen, TLS, Backups und ein Alarm, der wirklich ankommt.
>
> Der unangenehmste Teil: Docker kann an ufw vorbei. Ein `0.0.0.0:3306` ist keine Kleinigkeit.
>
> Checkliste: https://kisium.de/vps-absichern-debian-checkliste/
>
> #Linux #VPS #Docker #Sicherheit #Quereinstieg

Wenn Reichweite wichtiger ist als der Klick: Text ohne Link posten und den Link in den
ersten Kommentar setzen.

## Manuell posten

1. LinkedIn öffnen → **Beitrag erstellen**.
2. Text einfügen.
3. Bild `linkedin-vps-absichern.jpg` anhängen.
4. Veröffentlichen.

Direkter Share-Dialog für den Artikel:

https://www.linkedin.com/sharing/share-offsite/?url=https%3A%2F%2Fkisium.de%2Fvps-absichern-debian-checkliste%2F

## Automatisierung

LinkedIn hat keinen einfachen Bot-Token wie Mastodon. Für einen persönlichen Post
braucht es eine LinkedIn-App mit OAuth 2.0 und dem Scope `w_member_social`; für eine
Company Page zusätzlich `w_organization_social` und Admin-Rechte.

Wenn ein Token in einer 600er-Datei liegt, kann ich — wie bei Mastodon — neue
Blogartikel automatisch posten. Token niemals in den Chat oder ins Repo.

**Nicht** mit dem persönlichen Browser-Profil automatisieren: Das ist riskant (ToS,
Captcha, Kontosperre) und ich nutze keine fremden Sessions ohne explizite Freigabe.
