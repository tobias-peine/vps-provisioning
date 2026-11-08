# Secrets-Audit - lokal ausfuehren, bevor das Repo public wird

Alle Befehle im **Repo-Root** ausfuehren. Sie sind read-only; der einzige
schreibende Hinweis steht in Nummer 1 (`git rm --cached`).
`grep`-Treffer ohne Ausgabe bedeuten "gut".

Automatisiert: `./scripts/secret-audit.sh` (bzw. `make audit`) fuehrt die
Nummern 1-10 in einem Lauf aus und endet mit Exit-Code 1, sobald etwas
gefunden wird. Fuer den vollstaendigen Historien-Scan bleiben gitleaks und
trufflehog (Nummern 11 und 12) noetig - ohne Zusatzsoftware findet das
Skript nur Muster in der Arbeitskopie und in den Dateipfaden der Historie.

Voraussetzungen (nur fuer die optionalen Schritte 11 und 12):

```bash
pipx install git-filter-repo
# gitleaks: Binary von der Release-Seite, oder
#   go install github.com/gitleaks/gitleaks/v8@latest
```

## 1) Getrackte Secret-Dateien

```bash
git ls-files -z | tr '\0' '\n' | grep -Ei '(^|/)\.env|\.(pem|key|p12|pfx|jks|kdbx|crt)$|(^|/)id_(rsa|ed25519|ecdsa)$|vault' || echo "OK: keine Secret-Dateien getrackt"
```

- **Findet:** Dateien, die Git schon verfolgt und die bei GitHub landen.
- **Gut:** keine Ausgabe.
- **Warnung:** `*.example`, `*.pub`, `*.crt` (oeffentliches Zert) - pruefen, ob wirklich kein Secret drin ist.
- **Abbruch:** echte `.env`, `.pem`, `.key`, `vault.yml`. Datei ist bereits im Index - `git rm --cached <datei>`, danach **Credential rotieren** (gitignore macht Historie nicht rueckgaengig).

## 2) Secret-Dateien auf der Platte (auch ignorierte)

```bash
find . -path ./.git -prune -o -type f \( -name '.env*' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name 'vault*.yml' -o -name '*vault*pass*' -o -name 'id_ed25519*' -o -name '*.tskey' \) -print
```

- **Findet:** was lokal herumliegt und bei einem `git add -f` oder einer `.gitignore`-Aenderung mitkaeme.
- **Gut:** leer.
- **Warnung:** Dateien vorhanden - normal, solange sie ignoriert sind (Pruefung in Nummer 3).
- **Abbruch:** eine dieser Dateien ist **nicht** ignoriert (siehe Nummer 3).

## 3) Greifen die Ignore-Regeln wirklich?

```bash
git check-ignore -v --no-index hosts.ini .env .env.local group_vars/all/vault.yml group_vars/prod/vault.yml 2>/dev/null
echo '--- getrackt? ---'
git ls-files --error-unmatch hosts.ini .env 2>/dev/null && echo "ABBRUCH: getrackt" || echo "OK: nicht getrackt"
```

- **Findet:** welche Regel welche Datei ausschliesst (`--no-index` prueft auch bereits getrackte Dateien).
- **Gut:** jede erwartete Datei hat eine Regel-Zeile.
- **Warnung:** Datei fehlt in der Ausgabe, existiert aber - Regel ergaenzen.
- **Abbruch:** zweiter Block meldet "getrackt".

## 4) Oeffentliche IPv4-Adressen in getrackten Dateien

```bash
git grep -n -I -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' -- . | grep -Ev '\b(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|169\.254\.|0\.0\.0\.0|255\.)' || echo "OK: keine oeffentliche IPv4"
```

- **Findet:** echte Server-IP, Remote-IPs in Kommentaren, alte Test-Adressen.
- **Gut:** keine Ausgabe (Loopback/private werden bewusst ausgeblendet, weil das Setup sie legitim nutzt).
- **Warnung:** IP in Doku/Beispiel - durch `192.0.2.x` (RFC 5737) ersetzen.
- **Abbruch:** die oeffentliche VPS-IP irgendwo im Repo - durch `100.64.0.1` (Platzhalter) ersetzen und Historie pruefen (Nummern 10 und 11).

## 5) Tailscale-Adressen (100.64.0.0/10)

```bash
git grep -n -I -E '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}\b' || echo "OK: keine Tailscale-IP"
```

- **Findet:** Tailnet-Adressen aus `hosts.ini`, Screenshots, Logauszuegen.
- **Gut:** keine Ausgabe.
- **Warnung:** immer - es ist kein Credential, aber es identifiziert Tailnet und Node. Platzhalter `100.64.0.1` verwenden.
- **Abbruch:** nur in Kombination mit `tailscale up --authkey ...`.

## 6) Domains, URLs, Mailadressen

```bash
git grep -n -I -i -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' | grep -Ev 'example\.(com|org|net)|noreply|@localhost' || echo "OK: keine Mailadresse"
git grep -n -I -E 'https?://[^ )"<>]+' | grep -Ev 'ansible\.com|github\.com|docker\.com|tailscale\.com|nginx\.org|schema\.|w3\.org|localhost' || echo "OK: keine fremde URL"
```

- **Findet:** die echte Domain in `server_name`, NPM-Configs, README-Beispielen, Zertifikatspfaden; persoenliche Mailadressen.
- **Gut:** keine Ausgabe oder nur Doku-Links zu Herstellern.
- **Warnung:** `admin@...`, `git@...` in Beispielen - auf `example.com` umstellen.
- **Abbruch:** die produktive Domain oder private Mailadresse. Ersetzen durch `<DEINE-DOMAIN>`.

## 7) Tokens, Keys, private Schluessel (Muster)

```bash
git grep -n -I -E '(-----BEGIN [A-Z ]*PRIVATE KEY-----)|(gh[pousr]_[A-Za-z0-9]{36})|(github_pat_[A-Za-z0-9_]{22,})|(AKIA[0-9A-Z]{16})|(xox[baprs]-[A-Za-z0-9-]{10,})|(tskey-[a-z]+-[A-Za-z0-9]{10,})|(sk-[A-Za-z0-9]{20,})|(eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)' || echo "OK: kein Token-Muster"
```

- **Findet:** Private-Key-Header, GitHub-PAT, AWS-Key, Slack-Token, Tailscale-Authkey, OpenAI-Key, JWTs.
- **Gut:** keine Ausgabe.
- **Warnung:** Treffer in Doku/Testfixture, der nachweislich ungueltig ist - trotzdem entfernen.
- **Abbruch:** jeder Treffer mit realistischem Format. Token sofort widerrufen, **dann** Historie bereinigen.

## 8) Generische Zuweisungen (`password:`, `token=`)

```bash
git grep -n -I -i -E '(password|passwd|secret|token|api[_-]?key|private[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]#]{6,}' | grep -v '{{' || echo "OK: keine harten Zuweisungen"
```

- **Findet:** Klartext-Credentials in `defaults/main.yml`, Compose-Dateien, Skripten.
- **Gut:** nur Treffer mit `{{ vault_... }}`, `""` oder `TODO`.
- **Warnung:** Platzhalter wie `changeme` - funktional harmlos, sieht im Portfolio aber schlecht aus.
- **Abbruch:** konkreter Wert. In `ansible-vault` verschieben, Variablenname auf `vault_`-Praefix umstellen.

## 9) Autoren-Mails in der Commit-Historie

```bash
git log --all --format='%an <%ae>' | sort -u
```

- **Findet:** die Mailadresse, die mit dem Public-Schalten fuer immer in jedem Commit steht.
- **Gut:** nur `...@users.noreply.github.com`.
- **Warnung:** private Adresse - akzeptabel, wenn sie ohnehin oeffentlich gefuehrt wird.
- **Abbruch:** Firmen-/Kundendomain oder Adresse, die nicht veroeffentlicht werden soll - `mailmap` plus Rewrite oder frischer Initial-Commit.

## 10) Dateien, die jemals im Baum waren (auch geloeschte)

```bash
git log --all --diff-filter=A --name-only --pretty=format: | sort -u | grep -Ei '(\.env|\.pem|\.key$|\.p12$|vault|secret|credential|hosts\.ini)' || echo "OK: nie hinzugefuegt"
```

- **Findet:** geloeschte Dateien, die in der Historie weiterleben (der klassische Fall: `.env` war mal committet).
- **Gut:** keine Ausgabe.
- **Warnung:** Datei war drin, war aber nachweislich leer/Beispiel.
- **Abbruch:** `.env` oder Key war drin - Historie bereinigen **und** rotieren.

## 11) Historien-Scan auf Inhalt (der wichtigste Schritt)

```bash
# a) gitleaks: durchsucht alle Commits und Diffs
gitleaks git --log-opts="--all" --redact -v .
#   gitleaks < 8.19:  gitleaks detect --source . --log-opts="--all" --redact -v

# b) gezielter Pivot: einen Fund aus der Arbeitskopie historisch nachweisen
git grep -n -I '<FUNDSTELLE>' $(git rev-list --all) 2>/dev/null || echo "historisch nicht vorhanden"
```

- **Findet:** Secrets in alten Commits, auch wenn sie heute nicht mehr im Baum sind.
- **Gut:** `leaks: 0 findings` bzw. "historisch nicht vorhanden".
- **Warnung:** Finding in einem Commit, der nie gepusht wurde - Rewrite reicht.
- **Abbruch:** Finding in einem gepushten Commit - Rotation plus Rewrite.

## 12) Zweitmeinung (nur verifizierte Treffer)

```bash
trufflehog git file://. --only-verified --no-update
```

- **Findet:** nur Credentials, die **live** bestaetigt wurden (API-Call erfolgreich).
- **Gut:** keine Ausgabe.
- **Warnung:** keine - der Befehl meldet nur bestaetigte Treffer.
- **Abbruch:** jeder Treffer. Das ist kein "vielleicht": der Key funktioniert gerade.

## 13) Grosse/verdaechtige Blobs in der Historie

```bash
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '$1=="blob" && $3>200000 {printf "%8.1f KB  %s\n", $3/1024, $4}' | sort -nr | head -20
```

- **Findet:** DB-Dumps, alte Backups, ZIPs, `.env`-Kopien, die im Baum hingen.
- **Gut:** nur Bilder/Doku-Dateien, die bewusst gewollt sind.
- **Warnung:** mehr als 1 MB Binaerdaten - Repo wird langsam, aber kein Secret.
- **Abbruch:** `.sql`, `.tar.gz`, `.env.bak` in der Liste - Historie bereinigen.

## 14) Refs/Remotes vor einem Rewrite

```bash
git branch -a -vv
git tag -l
git remote -v
git count-objects -vH
```

- **Findet:** wie viele Refs und Klone nach einem Rewrite nachziehen muessten.
- **Gut:** ein Branch, keine Tags, ein Remote.
- **Warnung:** mehrere Tag-/Branch-Reste - jeder muss neu geschrieben werden.
- **Abbruch:** Remote existiert schon oeffentlich - Rewrite erreicht Forks, Release-Assets und Caches nicht; den Fund als kompromittiert behandeln.

## Entscheidungshilfe: `git filter-repo` oder frischer Initial-Commit?

1. Nur eigene Commits, Repo noch nicht oeffentlich, ueberschaubare Zahl - **frischer Initial-Commit**: ehrlicher, in zwei Minuten erledigt, kein Reflog-Risiko.
2. Fremde Beitraege/PR-Merges oder der Lernverlauf ist Teil der Story - **`git filter-repo`**: Autoren, Daten und Messages bleiben erhalten.
3. Ein Fund war ein **gueltiges** Credential - Rotation ist Pflicht, unabhaengig vom Weg; ein Rewrite loescht nur die Kopie im Repo, nicht GitHub-Caches oder Forks.
4. Repo war schon public/geforct/getaggt - Rewrite wird teuer: alle Klone, Tags, Releases und offenen PRs muessen nachziehen.
5. Zeitbudget unter einer Stunde oder Unbehagen bei den Funden - **frischer Initial-Commit** mit sauberer `.gitignore`, alte Historie als `repo-alt.bundle` lokal archiviert (niemals pushen).

```bash
# Nach einem Rewrite immer:
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git log --all --oneline | head -5
```
