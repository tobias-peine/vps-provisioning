Ansible ist eines dieser Werkzeuge, bei denen man nach dem ersten Tutorial denkt: „Das kann ich auch mit einem Shell-Skript.“ Kann man. Bis das Skript auf dem zweiten Server anders heißt, der dritte eine andere Distribution hat und niemand mehr weiß, welcher Befehl zuletzt wirklich ausgeführt wurde. Ansible löst nicht das Problem, dass Infrastruktur komplex ist. Es macht die Komplexität sichtbar, wiederholbar und versionierbar.

Dieser Artikel ist kein Überblick über alle Module. Er ist der Weg vom ersten Ping bis zu einem Playbook, das nginx installiert, eine Startseite ausrollt und beim zweiten Lauf **nichts mehr ändert**. Genau dieser zweite Lauf ist der Unterschied zwischen „hat einmal funktioniert“ und „ist reproduzierbar“.

## Was Ansible ist — und was nicht

Ansible ist agentenlos. Auf dem Zielserver muss kein Dienst laufen, der auf Befehle wartet. Es reicht SSH und Python. Dein Rechner — der Control Node — baut eine Verbindung auf, kopiert ein temporäres Modul, führt es aus und räumt hinterher auf.

Das ist der Grund, warum Ansible auf einem frischen VPS so schnell einsatzbereit ist. Es ist aber auch der Grund, warum es kein Ersatz für ein sauberes SSH-Setup ist. Wenn du dich per Passwort als `root` anmeldest, automatisiert Ansible genau dieses unsichere Modell.

Was Ansible nicht ist:

- kein Ersatz für ein Monitoring
- kein Backup
- kein Container-Orchestrator
- keine Garantie, dass deine Rollen fachlich richtig sind

Ansible führt aus, was du beschreibst. Nicht mehr.

## Das Lab: ein Control Node, ein Ziel

Für den Einstieg reichen zwei Maschinen:

- dein Rechner mit Linux, macOS oder WSL als Control Node
- ein Debian- oder Ubuntu-Server als Ziel

Auf dem Control Node installierst du Ansible:

```bash
sudo apt update
sudo apt install ansible
ansible --version
```

Auf dem Zielserver legst du einen Benutzer mit sudo-Rechten an. Wie das sauber geht, steht in der [VPS-Checkliste](/vps-absichern-debian-checkliste/). Für dieses Lab nehmen wir an, dass `deploy` existiert und per SSH-Key erreichbar ist.

Ein eigener Key nur für Ansible ist keine Paranoia, sondern macht den Zugang später nachvollziehbar:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/ansible_lab -C "ansible-lab"
ssh-copy-id -i ~/.ssh/ansible_lab.pub deploy@192.0.2.10
```

Die IP `192.0.2.10` ist absichtlich aus dem Dokumentationsbereich. Ersetze sie durch deine echte Adresse.

## Projekt und Inventar

Ein Ansible-Projekt ist am Anfang nur ein Verzeichnis:

```bash
mkdir -p ~/ansible-lab/files
cd ~/ansible-lab
```

Die Datei `ansible.cfg` hält die wichtigsten Voreinstellungen:

```ini
[defaults]
inventory = inventory.ini
host_key_checking = True
```

`host_key_checking = True` ist Absicht. Im Lab mag das beim ersten Verbindungsaufbau stören; im Betrieb ist es genau der Schutz, der verhindert, dass du dich mit dem falschen Server verbindest. Bestätige den Host-Key einmal bewusst, nicht dauerhaft blind.

Das Inventar beschreibt, welche Server es gibt:

```ini
[webserver]
web1 ansible_host=192.0.2.10

[webserver:vars]
ansible_user=deploy
ansible_ssh_private_key_file=~/.ssh/ansible_lab
```

Der Name `web1` ist der Name, den du in Playbooks benutzt. Die IP steht nur in `ansible_host`. So kannst du später den Server austauschen, ohne das Playbook anzufassen.

## Der erste Ping

Bevor du irgendetwas installierst, prüfst du die Verbindung:

```bash
ansible all -m ansible.builtin.ping
```

Die Ausgabe sollte so aussehen:

```text
web1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

`ping` ist kein ICMP-Ping. Es ist ein Modul, das eine SSH-Verbindung aufbaut, Python findet und eine Antwort zurückgibt. Wenn das scheitert, liegt das Problem fast immer bei SSH, dem Benutzer, dem Key oder der Python-Installation — nicht bei Ansible.

Häufige Fehler an dieser Stelle:

- `Permission denied`: falscher Benutzer oder Key nicht hinterlegt.
- `Host key verification failed`: der Host-Key ist noch nicht bestätigt.
- `python3: not found`: auf sehr schlanken Images fehlt Python.
- `sudo: a password is required`: `become` ist gesetzt, aber der Benutzer hat kein passwortloses sudo.

## Das erste Playbook

Jetzt kommt der Teil, der wirklich etwas tut. Die Datei `webserver.yml`:

```yaml
---
- name: Webserver grundlegend einrichten
  hosts: webserver
  become: true

  tasks:
    - name: Paketlisten aktualisieren
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: nginx installieren
      ansible.builtin.apt:
        name: nginx
        state: present

    - name: Startseite ausrollen
      ansible.builtin.copy:
        src: files/index.html
        dest: /var/www/html/index.html
        owner: root
        group: root
        mode: "0644"
      notify: nginx neu laden

    - name: nginx aktiviert und gestartet
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

  handlers:
    - name: nginx neu laden
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

Dazu die Datei `files/index.html`:

```html
<!doctype html>
<html lang="de">
  <head>
    <meta charset="utf-8">
    <title>Mein Ansible-Lab</title>
  </head>
  <body>
    <h1>Ausgerollt von Ansible.</h1>
    <p>Der zweite Lauf ändert hier nichts mehr.</p>
  </body>
</html>
```

Der Lauf:

```bash
ansible-playbook webserver.yml
```

Beim ersten Mal siehst du `changed=3` oder ähnlich. nginx wird installiert, die Datei kopiert, der Dienst gestartet. Der Handler läuft nur, wenn sich die Datei tatsächlich geändert hat.

## Der zweite Lauf ist der Test

Jetzt kommt der wichtigere Befehl:

```bash
ansible-playbook webserver.yml
```

Die Ausgabe sollte mit `changed=0` enden. Das ist **Idempotenz**: Der beschriebene Zustand ist bereits erreicht, also ändert Ansible nichts. Genau das unterscheidet ein Playbook von einem Shell-Skript, das bei jedem Lauf erneut `apt install` und `systemctl restart` ausführt.

Wenn der zweite Lauf immer noch `changed` meldet, ist meistens eines dieser Dinge los:

- ein `shell`- oder `command`-Task ohne `changed_when`
- ein Template, das bei jedem Lauf ein Datum einbaut
- ein Handler, der unnötig oft getriggert wird
- eine Datei, deren Inhalt sich tatsächlich bei jedem Lauf ändert

Prüfen kannst du das mit:

```bash
ansible-playbook webserver.yml --check --diff
```

Der Check-Modus führt nichts aus, zeigt aber, was sich ändern würde. Bei `apt` kann er je nach Cache-Zustand meckern; nach dem ersten erfolgreichen Lauf ist er deutlich nützlicher.

## Was du damit wirklich automatisierst

Das Beispiel ist klein, aber es enthält alle Bausteine, die du später wiederverwendest:

- **Inventar:** Welche Hosts gehören zu welcher Gruppe?
- **Variablen:** Welcher Benutzer, welcher Key, welche Distribution?
- **Tasks:** Was soll auf dem Host passieren?
- **Handler:** Was soll nur bei einer Änderung passieren?
- **Idempotenz:** Was passiert beim zweiten Lauf?

Wenn du das beherrschst, sind Templates und Rollen kein neues Konzept mehr, sondern nur eine andere Organisation derselben Idee. Wie aus einem einzelnen Playbook eine ganze Infrastruktur wird, steht in [Server als Code](/ansible-infrastruktur-als-code/). Was dabei an Zeit hängen bleibt, habe ich in [356 Sekunden](/ansible-356-sekunden/) aufgeschrieben.

## Die drei häufigsten Anfängerfehler

**1. Alles mit `shell` lösen.**  
`shell` ist mächtig, aber Ansible weiß dann nicht, ob sich etwas geändert hat. Nutze Module wie `apt`, `copy`, `template` oder `service`. Wenn du `shell` wirklich brauchst, ergänze `changed_when` und `creates`.

**2. Gegen `all` laufen lassen.**  
Ein Playbook, das versehentlich alle Hosts neu startet, ist ein teurer Test. Nutze Gruppen und im Zweifel `--limit web1`.

**3. Secrets ins Inventar schreiben.**  
Passwörter und Tokens gehören nicht in Git. Für den Einstieg reichen SSH-Keys; später nimmst du `ansible-vault` oder einen Secret-Store. Ein Playbook ist kein Passwortmanager.

## Wie es weitergeht

Der nächste sinnvolle Schritt ist nicht „mehr Module“, sondern eine echte Aufgabe:

- eine nginx-Site per Template ausrollen
- eine `vars.yml` für unterschiedliche Umgebungen anlegen
- einen zweiten Host in dieselbe Gruppe hängen
- das Playbook in Git committen und die Änderung nachvollziehen

Ansible wird erst wertvoll, wenn du es auf eine Aufgabe anwendest, die du sonst wiederholt von Hand machst. Nicht auf eine Aufgabe, die du einmal im Jahr brauchst.

Und der wichtigste Test bleibt derselbe: **Der zweite Lauf muss `changed=0` zeigen.**
