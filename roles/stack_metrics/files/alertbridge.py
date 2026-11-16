#!/usr/bin/env python3
"""Alertmanager-Webhook -> ntfy.sh (Verwaltet von Ansible, Rolle stack_metrics).

Alertmanager kann seine JSON-Nutzlast nicht selbst umformatieren; ein direkter
Webhook an ntfy wuerde rohes JSON aufs Handy schicken. Dieser winzige Dienst
uebersetzt sie in Titel + Kurztext und schickt sie an das konfigurierte Topic.

Nur Standardbibliothek - kein Image mit Abhaengigkeiten, keine Updates noetig.
"""
import json
import os
import sys
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

NTFY_URL = os.environ.get("NTFY_URL", "https://ntfy.sh").rstrip("/")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "").strip()


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802 - Name kommt von BaseHTTPRequestHandler
        if self.path not in ("/", "/alert"):
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        status = payload.get("status", "firing")
        alerts = payload.get("alerts") or [{}]
        first = alerts[0]
        labels = first.get("labels", {})
        annotations = first.get("annotations", {})

        title = f"{labels.get('alertname', 'Alarm')} ({status})"
        lines = [annotations.get("summary", "ohne Beschreibung")]
        if len(alerts) > 1:
            lines.append(f"+{len(alerts) - 1} weitere Alarme")

        message = {
            "topic": NTFY_TOPIC,
            "title": title,
            "message": "\n".join(lines),
            "priority": 4 if status == "firing" else 3,
            "tags": ["rotating_light"] if status == "firing" else ["white_check_mark"],
        }
        request = urllib.request.Request(
            f"{NTFY_URL}/",
            data=json.dumps(message).encode(),
            headers={"Content-Type": "application/json"},
        )
        try:
            urllib.request.urlopen(request, timeout=10).read()
        except Exception as exc:  # Netzfehler sollen Alertmanager nicht stoeren
            print(f"ntfy: {exc}", file=sys.stderr, flush=True)

        # Alertmanager wertet nur den Statuscode aus.
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    if not NTFY_TOPIC:
        sys.exit("NTFY_TOPIC fehlt")
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
