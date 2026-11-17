Eine Gesundheits-App verspricht schnell: „Deine Daten bleiben bei dir.“ Bei Lunaria ist das fast wahr. Der Unterschied zwischen „fast“ und „ganz“ ist der interessante Teil — und genau darüber lohnt sich ein technischer Blick.

Lunaria ist eine local-first PWA für Medikamente, Rezepte, Zyklus, Schmerz und Arzttermine. Kein Konto, keine Cloud-Synchronisation, keine Gesundheitsdatenbank auf dem Server. Trotzdem gibt es zwei Stellen, an denen Daten das Gerät verlassen. Beide sind optional, beide laufen nur auf Klick, und beide muss man klar benennen, wenn man die App öffentlich zeigt.

Dieser Text ist keine Produktwerbung. Er ist der Versuch, ein eigenes Projekt so zu beschreiben, wie ich es in einem Bewerbungsgespräch erklären würde: was gebaut ist, warum es so gebaut ist, wo es schiefgehen kann und was ich daraus gelernt habe.

## Die Architektur: Der Server weiß fast nichts

Lunaria besteht aus drei Teilen:

```text
Browser / PWA
├── Next.js 16, React 19, Tailwind 4
├── IndexedDB über Dexie
│   └── Medikamente, Pläne, Einnahmen, Zyklus, Schmerz, Termine
├── Service Worker (Offline-Shell, Updates)
└── /api/scan, /api/cycle/analyze
        └── DeepSeek — nur auf Klick

Server
├── Next.js-Standalone-Image im Docker-Container
├── Nginx Proxy Manager terminiert TLS
└── Volume mit push.json: Push-Abos, Uhrzeiten, Zeitzone
```

Die entscheidende Entscheidung: **Gesundheitsdaten liegen nicht auf dem Server.** Es gibt keine Datenbank, keinen Sync und kein Nutzerkonto. Der Server liefert Code, schützt den Zugang und proxyt zwei KI-Aufrufe. Wenn der Server neu aufgesetzt wird, sind keine Gesundheitsdaten verloren — weil dort keine liegen.

Das Backup ist entsprechend kein Datenbank-Dump, sondern ein JSON-Export aus der App. Auf dem Server muss nur die `.env` gesichert werden: Passwörter, Session-Secret, API-Key, VAPID-Schlüssel. Der Rest ist reproduzierbar.

## Was lokal bleibt — und warum das nicht automatisch sicher ist

Die App speichert alles in IndexedDB. Reichweite, Rezept-Warnung und Zyklusprognose werden bei jedem Rendern aus den Rohdaten berechnet, statt berechnete Werte zu speichern. So kann kein veralteter Restbestand entstehen, nur weil ein Häkchen in einer anderen Ansicht gesetzt wurde.

Local-first heißt aber nicht automatisch „sicher“. Zwei Dinge muss man dazusagen:

- Die **App-Sperre** ist ein Sichtschutz, keine Verschlüsselung. Die Daten liegen unverschlüsselt in IndexedDB; der PIN schützt gegen neugierige Blicke, nicht gegen jemanden mit Zugriff auf das Browserprofil.
- Ein **JSON-Backup** ist ein Klartext-Export. Wer die Datei hat, hat die Daten. Das ist für ein bewusstes Backup in Ordnung, aber es ist kein verschlüsseltes Archiv.

Beides steht in der App und in der Doku. Es wäre einfacher, „verschlüsselt“ zu versprechen. Es wäre nur nicht wahr.

## Wo Daten das Gerät verlassen

Es gibt zwei KI-Funktionen:

1. **Scan der Medikamentenverpackung.** Ein verkleinertes Foto geht an `POST /api/scan`, der Server ruft damit die Vision-API auf. Das Foto enthält den Medikamentennamen und die Packung — also Gesundheitsdaten. Der API-Key bleibt serverseitig; die Route prüft die Session, damit niemand ohne Anmeldung kostenpflichtige Aufrufe auslöst.
2. **Zyklusprognose mit KI.** Auf Klick gehen Datumswerte, Stärke-Kategorien und Symptom-Schweregrade an DeepSeek. Nicht übertragen werden Name, freie Notizen, Medikamente, Termine oder Geräte-IDs. Die lokale Regel-Engine bleibt immer die Basis; ohne API-Key zeigt die App klar eine Demo-Berechnung.

Beim Öffnen der App wird nichts automatisch gesendet. Beide Funktionen brauchen einen Klick. Das ist der Unterschied zwischen „die App nutzt eine API“ und „die App telefoniert nach Hause“.

Trotzdem bleibt eine unbequeme Wahrheit: **„Ohne Cloud“ ist zu absolut, wenn zwei Funktionen eine Cloud-API nutzen.** Für einen öffentlichen Start müsste die Datenschutzerklärung diesen Datenfluss klar benennen, mit Einwilligung vor der Funktion und einer ehrlichen Beschreibung, was wohin geht. Das ist kein Detail, das man im Marketing weglässt.

## Betrieb auf einem 1-GB-VPS

Lunaria läuft als Docker-Container auf einem kleinen VPS. Die technischen Leitplanken:

- **Kein veröffentlichter Port.** Nginx Proxy Manager terminiert TLS und leitet `lunaria.kisium.de` an `lunaria-app:3000` weiter.
- **Non-root im Container**, `cap_drop: ALL`, `no-new-privileges`.
- **512 MB Memory-Limit**; im Leerlauf sind es gemessen etwa **51 MiB RSS**.
- **Healthcheck** alle 30 Sekunden gegen `/login`, damit ein hängender Prozess nicht als „läuft“ durchgeht.
- **Persistentes Volume** nur für Push-Abos und Uhrzeiten — keine Gesundheitsdaten.
- **Deployment über Ansible**; ein Rebuild passiert bewusst, nicht bei jedem Lauf.

Das ist keine große Plattform. Es ist genau die Größe, an der man Betrieb wirklich lernt: ein Dienst, ein Proxy, ein Zertifikat, ein Volume, ein Healthcheck, ein Backup. Wer das einmal sauber aufgebaut hat, versteht auch, warum ein Healthcheck nicht dasselbe ist wie ein Monitoring und warum ein Zertifikat, das in 20 Tagen abläuft, ein Alarmproblem ist.

Die Server-Härtung — SSH, Firewall, Docker-Ports — steht in der [VPS-Checkliste](/vps-absichern-debian-checkliste/). Dass ein Backup erst nach einem Restore zählt, steht in [Ein Backup-Ziel, das einen Nachmittag gebraucht hat](/ein-backup-ziel-das-einen-nachmittag-gebraucht-hat/).

## Der Fehler, der mich am meisten gelehrt hat

Der erste Entwurf des Zugangsschutzes prüfte das Server-Passwort in `proxy.ts`. Das klingt naheliegend: Proxy fängt alle Requests ab, Passwort prüfen, fertig.

Das Problem: `proxy.ts` wird beim Build gebündelt. `LUNARIA_PASSWORD` kommt aber erst zur Laufzeit aus der Docker-Umgebung. Im schlimmsten Fall wäre die Prüfung mit einem leeren Wert gebaut worden — und die Instanz wäre offen gewesen, ohne dass es beim Start auffällt.

Die Prüfung sitzt jetzt im Server-Layout, wo sie bei jedem Request zur Laufzeit läuft. `/api/scan` prüft die Session zusätzlich, weil dort Kosten entstehen. Dazu gibt es einen Auth-Test, der Redirect, falsches und richtiges Passwort, API-Sperre ohne Session und den Logout abdeckt.

Die Lehre ist nicht „Proxy ist schlecht“. Die Lehre ist: **Sicherheitsprüfungen gehören dorthin, wo die Laufzeitwerte sicher verfügbar sind — und man muss den Fall testen, in dem die Variable fehlt.** Ein grüner Build beweist keine geschlossene Tür.

## Was Lunaria nicht ist

- **Kein Verhütungsmittel.** Die Zyklusprognose ist eine Schätzung aus eigenen Einträgen; kalenderbasierte Verfahren sind dafür zu unzuverlässig. Das steht in der App an jeder relevanten Stelle.
- **Keine Diagnose und keine Medikamentenempfehlung.** Wechselwirkungshinweise sind Gesprächsanlass, keine Freigabe.
- **Kein Mehrnutzer-Produkt.** Kein Teilen, kein Sync, keine Konten.
- **Keine garantierte Push-Zustellung.** Der Scheduler läuft im Minutentakt; ist der Container genau dann aus, wird eine Erinnerung nicht nachgeholt.
- **Keine Verschlüsselung at rest.** Die App-Sperre ist ein Sichtschutz; das ist bewusst so benannt.

Diese Grenzen sind kein Marketing-Problem. Sie sind die Wahrheit über ein kleines Produkt, das mit sensiblen Daten arbeitet. Wer sie versteckt, baut Vertrauen auf einer Lüge.

## Was das für Bewerbungen zeigt

Ein eigenes Projekt beweist keine Berufserfahrung. Es beweist auch keine Teamarbeit und kein On-Call. Aber es zeigt etwas, das man in einem Gespräch schwer behaupten kann, ohne es zu haben:

- einen Dienst von der Entwicklung bis zum Betrieb zu bringen,
- Datenfluss und Grenzen zu erklären,
- Sicherheitsentscheidungen zu begründen,
- einen Fehler zu finden und die Ursache zu beheben,
- Backup, Healthcheck und Deployment nicht als Checkliste, sondern als Zusammenhang zu verstehen.

Für eine Junior-Sysadmin- oder DevOps-Stelle ist das der relevante Teil — nicht die Feature-Liste. Für eine Fullstack-Stelle ist die PWA mit Offline-Shell, IndexedDB und Android-Hülle der relevante Teil. Für IT-Support ist es eher ein Nebenprojekt.

## Fazit

Lunaria ist kein fertiges Consumer-Produkt. Es ist eine Beta, die zeigt, wie eine Gesundheits-App aussehen kann, die local-first ernst meint — und wo local-first endet, weil eine KI-Funktion Daten braucht.

Vor einem offenen Launch müssten Datenschutz, Einwilligung, medizinische Aussagen und Missbrauchsschutz geklärt sein. Bis dahin bleibt die App hinter dem Beta-Zugang. Dieser Text ist die technische Einordnung, kein Launch.

Und der wichtigste Satz für das nächste Gespräch: **Die interessanten Entscheidungen stehen nicht in der Feature-Liste, sondern in dem, was man bewusst weglässt.**

---

Lunaria ist eine persönliche Organisationshilfe und ersetzt keine ärztliche Beratung. Bei Nebenwirkungen oder Unsicherheiten wende dich an deine Ärztin, deinen Arzt oder eine Apotheke.
