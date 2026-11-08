#!/usr/bin/env bash
# secret-audit.sh - lokale Secret-Vorpruefung fuer dieses Repo.
# Read-only: prueft Arbeitskopie und Historie, aendert nichts.
# Exit 0 = keine Funde, Exit 1 = Funde (Details oben).
#
# Bewusst nur Muster, die ohne Zusatzsoftware laufen. Fuer den vollen
# Historien-Scan zusaetzlich gitleaks/trufflehog einsetzen (siehe
# SECRETS-AUDIT.md, Nummern 11 und 12).

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

status=0
report() {
    local title=$1
    shift
    local out
    out=$("$@" 2>/dev/null || true)
    printf '\n== %s ==\n' "$title"
    if [ -n "$out" ]; then
        printf '%s\n' "$out" | head -25 | sed 's/^/  /'
        status=1
    else
        printf '  ok\n'
    fi
}

printf 'Secret-Audit in %s\n' "$(pwd)"

report "getrackte Secret-Dateien" \
    bash -c "git ls-files | grep -Ei '(^|)\\.env(\$|\\.)|\\.(pem|key|p12|pfx|jks|kdbx)\$|(^|)id_(rsa|ed25519|ecdsa)\$|(^|)vault\\.ya?ml\$'"

report "oeffentliche IPv4 (Loopback/private/CGNAT ausgenommen)" \
    bash -c "git grep -n -I -E '[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}' -- . \
        | grep -Ev '(127\\.|10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|169\\.254\\.|0\\.0\\.0\\.0|255\\.|100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.|192\\.0\\.2\\.)'"

# Platzhalter in der Vorlage sind erlaubt, deshalb dort ausgenommen.
report "Tailscale-Adressen (100.64.0.0/10)" \
    bash -c "git grep -n -I -E '100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]{1,3}\\.[0-9]{1,3}' -- . ':!hosts.ini.example' \
        | grep -Ev '100\\.64\\.0\\.1|/10' || true"

report "E-Mail-Adressen (example.com/noreply ausgenommen)" \
    bash -c "git grep -n -I -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}' -- . \
        | grep -Ev 'example\\.(com|org|net)|noreply|@localhost'"

report "Token- und Key-Muster" \
    bash -c "git grep -n -I -E '(-----BEGIN [A-Z ]*PRIVATE KEY-----)|(gh[pousr]_[A-Za-z0-9]{36})|(github_pat_[A-Za-z0-9_]{22,})|(AKIA[0-9A-Z]{16})|(xox[baprs]-[A-Za-z0-9-]{10,})|(tskey-[a-z]+-[A-Za-z0-9]{10,})|(sk-[A-Za-z0-9]{20,})|(eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.)' -- ."

# Die Audit-Doku selbst enthaelt die Muster als Text - deshalb ausgenommen.
report "harte Zuweisungen (password/token/secret)" \
    bash -c "git grep -n -I -i -E '(password|passwd|secret|token|api[_-]?key|private[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]#]{6,}' -- . ':!SECRETS-AUDIT.md' ':!scripts/secret-audit.sh' ':!group_vars/all/vault.yml.example' \
        | grep -v -e '{{' -e '\${' || true"

printf '\n== Secret-Dateien auf der Platte ohne Ignore-Regel ==\n'
leaks=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! git check-ignore -q --no-index "${f#./}"; then
        printf '  %s\n' "$f"
        leaks=1
    fi
done < <(find . -path ./.git -prune -o -type f \
    \( -name '.env*' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name 'vault*.yml' \) -print 2>/dev/null)
if [ "$leaks" -eq 1 ]; then status=1; else printf '  ok\n'; fi

report "jemals committete Secret-Pfade" \
    bash -c "git log --all --diff-filter=A --name-only --pretty=format: | sort -u \
        | grep -Ei '(^|)\\.env(\$|\\.)|(^|)hosts\\.ini\$|\\.(pem|key|p12|pfx|jks|kdbx)\$|(^|)vault\\.ya?ml\$|(^|)secrets?/'"

if command -v gitleaks >/dev/null 2>&1; then
    printf '\n== gitleaks (Historie) ==\n'
    gitleaks git --log-opts="--all" --redact -v . || status=1
else
    printf '\n== gitleaks (Historie) ==\n  nicht installiert - uebersprungen\n'
fi

printf '\n'
if [ "$status" -eq 0 ]; then
    printf 'Ergebnis: keine Funde.\n'
else
    printf 'Ergebnis: Funde vorhanden - vor dem Push klaeren (siehe SECRETS-AUDIT.md).\n'
fi
exit "$status"
