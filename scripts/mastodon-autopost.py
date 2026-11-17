#!/usr/bin/env python3
"""Post new kisium.de RSS items to Mastodon exactly once.

Root-only: reads /etc/kisium/mastodon.token (600), writes state under
/var/lib/kisium-mastodon/. The first run only creates a baseline and posts
nothing, so existing articles are not re-announced.
"""
import argparse
import fcntl
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import date
from html import unescape

TOKEN_PATH = "/etc/kisium/mastodon.token"
STATE_PATH = "/var/lib/kisium-mastodon/state.json"
LOCK_PATH = "/var/lock/kisium-mastodon.lock"
FEED_URL = "https://kisium.de/rss/"
MASTODON = "https://mastodon.social"
MAX_STATUS = 500


def plain(value):
    value = re.sub(r"<[^>]+>", " ", value or "")
    return re.sub(r"\s+", " ", unescape(value)).strip()


def read_token():
    try:
        with open(TOKEN_PATH, encoding="utf-8") as fh:
            token = fh.read().strip()
    except OSError as exc:
        raise SystemExit(f"token_unreadable: {exc.__class__.__name__}")
    if not token:
        raise SystemExit("token_empty")
    return token


def fetch_items():
    req = urllib.request.Request(FEED_URL, headers={"User-Agent": "kisium-mastodon/1.0"})
    with urllib.request.urlopen(req, timeout=30) as response:
        root = ET.fromstring(response.read())
    items = []
    for node in root.iter("item"):
        title = plain(node.findtext("title"))
        link = (node.findtext("link") or "").strip()
        guid = (node.findtext("guid") or "").strip()
        desc = plain(node.findtext("description"))
        cats = [plain(c.text) for c in node.findall("category") if plain(c.text)]
        key = link or guid
        if title and key:
            items.append({"title": title, "link": link or guid, "description": desc, "categories": cats, "key": key})
    return items


def hashtags(item):
    tags = []
    for cat in item["categories"]:
        tag = re.sub(r"[^0-9A-Za-z_]", "", cat.replace(" ", ""))
        if tag and tag.lower() not in [t.lower() for t in tags]:
            tags.append(tag)
    if not tags:
        tags = ["Linux", "Homelab"]
    if not any(t.lower() == "linux" for t in tags):
        tags.append("Linux")
    return " ".join("#" + t for t in tags[:4])


def build_status(item):
    title = item["title"][:120].strip()
    link = item["link"]
    tags = hashtags(item)
    fixed = f"{title}\n\n{link}\n\n{tags}"
    room = max(0, MAX_STATUS - len(fixed) - 4)
    desc = item["description"][:room].rstrip()
    return f"{title}\n\n{desc}\n\n{link}\n\n{tags}" if desc else f"{title}\n\n{link}\n\n{tags}"


def load_state():
    try:
        with open(STATE_PATH, encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict) and isinstance(data.get("posted"), list):
            return data
    except (OSError, ValueError):
        pass
    return {"posted": [], "last_post_date": None}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_PATH), mode=0o700, exist_ok=True)
    state["posted"] = state["posted"][-200:]
    tmp = STATE_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, ensure_ascii=False, indent=1)
    os.chmod(tmp, 0o600)
    os.replace(tmp, STATE_PATH)


def post_status(token, item):
    body = urllib.parse.urlencode({
        "status": build_status(item),
        "visibility": "public",
        "language": "de",
    }).encode()
    headers = {
        "Authorization": "Bearer " + token,
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "kisium-mastodon/1.0",
        "Idempotency-Key": hashlib.sha256(item["key"].encode()).hexdigest(),
    }
    req = urllib.request.Request(MASTODON + "/api/v1/statuses", data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as exc:
        return exc.code, {"error": exc.read().decode("utf-8", "replace")[:200]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--init", action="store_true", help="baseline current feed without posting")
    args = parser.parse_args()

    os.makedirs(os.path.dirname(STATE_PATH), mode=0o700, exist_ok=True)
    lock = open(LOCK_PATH, "w")
    fcntl.flock(lock, fcntl.LOCK_EX)

    items = fetch_items()
    if not items:
        print("feed_empty")
        return 0

    state = load_state()
    if args.init or not os.path.exists(STATE_PATH):
        state["posted"] = [item["key"] for item in items]
        state["last_post_date"] = None
        if not args.dry_run:
            save_state(state)
        print(f"baseline: {len(items)} items; nichts gepostet")
        return 0

    posted = set(state["posted"])
    new_items = [item for item in items if item["key"] not in posted]
    if not new_items:
        if args.dry_run:
            print("keine neuen Artikel")
        return 0

    if state.get("last_post_date") == date.today().isoformat():
        if args.dry_run:
            print("Tageslimit erreicht")
        return 0

    item = new_items[0]
    if args.dry_run:
        print("dry_run: würde posten")
        print(build_status(item))
        return 0

    token = read_token()
    status, payload = post_status(token, item)
    if status in (200, 201):
        state["posted"].append(item["key"])
        state["last_post_date"] = date.today().isoformat()
        save_state(state)
        print(f"posted: {payload.get('url', 'ok')}")
        return 0
    print(f"post_failed: {status} {str(payload)[:200]}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
