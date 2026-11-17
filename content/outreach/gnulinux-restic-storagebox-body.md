Ein Backup-Ziel einzurichten klingt nach einer Aufgabe für zwanzig Minuten. Bestellen, Passwort setzen, `ssh-copy-id`, Repository initialisieren, fertig. Bei mir wurden daraus mehrere Stunden – nicht wegen restic, sondern wegen einer Storage Box, die auf zwei Ports zwei verschiedene Welten zeigt.

Die Ausgangslage: Die Backups lagen bereits verschlüsselt auf einem zweiten Server im Tailnet. Das ist besser als nichts, aber es ist derselbe Anbieter, dieselbe Region, dasselbe Konto. Wenn dort etwas schiefgeht, geht alles gleichzeitig schief. Also ein zweites Ziel bei einem anderen Produkt: eine Hetzner Storage Box, 1 TB, wenige Euro im Monat. Die Snapshots sollten abwechselnd an beide Ziele gehen.

## Port 22 und Port 23 sind nicht derselbe Ort

Die Storage Box bietet SFTP auf zwei Ports an. Auf Port 22 ist die Wurzel `/`, auf Port 23 ist sie `/home`. Dasselbe Repository liegt damit je nach Port an einer anderen Stelle. Mein erster Versuch legte es unter `/restic-offsite2` an – über den einen Port erreichbar, über den anderen unsichtbar.

Zwei Stunden später änderte ich den Pfad auf `/home/restic` und wunderte mich, warum „das Repository weg“ war. Es war nie weg. Ich hatte an der falschen Tür geklopft. Wer nur den Port in der SSH-Konfiguration ändert und den Pfad gleich lässt, sieht genau dieses Verhalten: `restic snapshots` meldet ein leeres oder fehlendes Repository, obwohl die Daten existieren.

Die Lehre ist unspektakulär, aber wichtig: **Port und Pfad gehören zusammen.** Bevor man den ersten Snapshot schreibt, prüft man mit `sftp` oder `ssh`, wo man tatsächlich landet:

```bash
sftp -P 23 u123456@u123456.your-storagebox.de
pwd
ls -la
```

Erst wenn `pwd` und der restic-Pfad zusammenpassen, ist der Rest sinnvoll.

## Ein Schlüssel für alles ist ein Schlüssel für nichts

Der zweite Fehler war ein wiederverwendeter SSH-Key. Ich kopierte meinen persönlichen Schlüssel auf die Box, weil er dort schon autorisiert war. Das war der bequemste Weg – und der falsche. Ein Schlüssel, der überall passt, macht genau das, was ein Schlüssel nicht tun soll: er öffnet zu viel.

Besser ist ein eigener Key nur für restic:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/restic_storagebox -C "restic@kisium"
ssh-copy-id -i ~/.ssh/restic_storagebox.pub -p 23 u123456@u123456.your-storagebox.de
```

Danach in der restic-Konfiguration ausschließlich diesen Key verwenden. Auf der Storage Box landet er in `authorized_keys`. Dort kann übrigens derselbe Schlüssel in zwei Formaten stehen – einmal OpenSSH, einmal im alten SSH2-Format. Der SFTP-Dienst bricht beim Parsen an dem Block ab und ignoriert alles danach. Ein Schlüssel, der in der Datei steht, ist deshalb nicht automatisch ein Schlüssel, der gelesen wird.

## Das Repository und der erste Snapshot

Ist der Zugang geklärt, ist restic selbst unspektakulär. Repository initialisieren, Passwort in einem Passwortmanager ablegen, ersten Snapshot schreiben:

```bash
export RESTIC_REPOSITORY="sftp:u123456@u123456.your-storagebox.de:/home/restic"
export RESTIC_PASSWORD_COMMAND="pass show restic/storagebox"

restic init
restic backup /etc /opt /home \
  --exclude /home/*/.cache \
  --exclude /opt/kisium/backups
```

Der Port muss zur gewählten Tür passen. Bei restic setzt man ihn über die SSH-/SFTP-Optionen; wer hier Port 23 konfiguriert, muss auch den Pfad unter `/home` verwenden. Klingt banal, kostet sonst einen Nachmittag.

Nach dem Lauf prüft man nicht nur, ob der Job mit Exit-Code 0 endet, sondern ob der Snapshot wirklich da ist:

```bash
restic snapshots
restic check
```

`restic check` prüft die Struktur des Repositories. Das ist wichtig, aber es ist noch kein Restore.

## Der Test, der zählt

Ein Backup, das nie zurückgespielt wurde, ist nur eine Datei, die Platz braucht. Also: einen Snapshot in ein separates Verzeichnis zurückspielen, nicht über das laufende System:

```bash
mkdir -p /tmp/restore-test
restic restore latest --target /tmp/restore-test
ls -la /tmp/restore-test/etc
```

Danach die wiederhergestellte Datenbank oder Konfiguration öffnen und prüfen, ob der Dienst damit starten würde. Nicht nur die Dateigröße ansehen. Der Unterschied zwischen „der Dump ist da“ und „der Dump lässt sich importieren“ ist der Unterschied zwischen Backup und Hoffnung.

Bei mir hat genau dieser Schritt einen Fehler gefunden, den `restic check` nicht sieht: Der Snapshot war vollständig, aber ein Pfad in der Compose-Datei zeigte nach dem Restore ins Leere. Ohne den Test wäre das erst im Ernstfall aufgefallen.

## Was ich heute anders machen würde

1. **Zuerst den Port und den Pfad testen**, dann restic initialisieren.
2. **Einen eigenen Key** nur für das Backup-Ziel verwenden.
3. **Restore von Anfang an üben**, nicht erst nach dem ersten Ausfall.
4. **Die Frische überwachen:** Ein Cron-Job, der den Zeitpunkt des letzten Snapshots in eine Metrik schreibt, ist mehr wert als eine E-Mail, die nur bei einem Fehler kommt.

Die Storage Box ist ein solides Ziel. Aber sie ist kein Backup, solange niemand die Tür gefunden hat – und den Restore geprobt hat.

*Der vollständige Erfahrungsbericht mit den konkreten Fehlermeldungen steht auf [kisium.de](https://kisium.de/ein-backup-ziel-das-einen-nachmittag-gebraucht-hat/).*
