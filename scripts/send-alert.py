#!/usr/bin/env python3
"""Send a kisium health alert through the existing Ghost SMTP config.

Reads /opt/kisium/.env (root-only), sends to MAIL_USER unless ALERT_TO is set.
A 6-hour cooldown prevents alert spam; --force bypasses it for testing.
"""
import argparse
import os
import smtplib
import ssl
import sys
import time
from email.message import EmailMessage
from email.utils import parseaddr

ENV_PATH = "/opt/kisium/.env"
STATE_PATH = "/var/lib/kisium-health.last-alert"
COOLDOWN = 6 * 3600


def load_env(path):
    env = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--subject", default="[kisium] Health check failed")
    args = parser.parse_args()

    if not args.force and os.path.exists(STATE_PATH):
        age = time.time() - os.path.getmtime(STATE_PATH)
        if age < COOLDOWN:
            print("alert_suppressed")
            return 0

    body = sys.stdin.read().strip()
    if not body:
        body = "check-kisium.sh reported a failure."

    try:
        env = load_env(ENV_PATH)
    except OSError as exc:
        print("alert_config_error", type(exc).__name__)
        return 1

    host = env.get("MAIL_HOST", "")
    port = int(env.get("MAIL_PORT", "0") or 0)
    user = env.get("MAIL_USER", "")
    password = env.get("MAIL_PASSWORD", "")
    sender = env.get("MAIL_FROM", "") or user
    recipient = env.get("ALERT_TO", "") or os.environ.get("ALERT_TO", "") or user
    secure = env.get("MAIL_SECURE", "").lower() in ("1", "true", "yes")

    if not (host and port and user and password and recipient):
        print("alert_config_incomplete")
        return 1

    envelope_from = parseaddr(sender)[1] or user
    msg = EmailMessage()
    msg["Subject"] = args.subject
    msg["From"] = sender
    msg["To"] = recipient
    msg.set_content(body + f"\n\nHost: {os.uname().nodename}\nZeit: {time.strftime('%Y-%m-%d %H:%M:%S')}")

    try:
        if port == 465 or (secure and port != 587):
            context = ssl.create_default_context()
            with smtplib.SMTP_SSL(host, port, timeout=20, context=context) as smtp:
                smtp.login(user, password)
                smtp.send_message(msg, from_addr=envelope_from, to_addrs=[recipient])
        else:
            with smtplib.SMTP(host, port, timeout=20) as smtp:
                smtp.ehlo()
                smtp.starttls(context=ssl.create_default_context())
                smtp.ehlo()
                smtp.login(user, password)
                smtp.send_message(msg, from_addr=envelope_from, to_addrs=[recipient])
    except Exception as exc:
        print("alert_error", type(exc).__name__, str(exc)[:160])
        return 1

    try:
        with open(STATE_PATH, "w", encoding="utf-8") as fh:
            fh.write(str(int(time.time())) + "\n")
    except OSError:
        pass
    print("alert_sent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
