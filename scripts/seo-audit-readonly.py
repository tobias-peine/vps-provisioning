#!/usr/bin/env python3
"""Read-only SEO-Audit für kisium.de.

Macht ausschließlich GET-Anfragen und schreibt nichts auf dem Server.
Ergebnis: JSON auf stdout.
"""
import json
import re
import urllib.error
import urllib.request
from html.parser import HTMLParser

BASE = "https://kisium.de"
UA = "Mozilla/5.0 (compatible; KisiumSEOAudit/1.0; read-only)"


def fetch(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "text/html,application/xml;q=0.9,*/*;q=0.8",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return {
                "status": r.status,
                "final_url": r.geturl(),
                "content_type": r.headers.get("Content-Type", ""),
                "x_robots_tag": r.headers.get("X-Robots-Tag"),
                "body": r.read().decode("utf-8", "replace"),
            }
    except urllib.error.HTTPError as e:
        return {
            "status": e.code,
            "final_url": url,
            "content_type": e.headers.get("Content-Type", ""),
            "x_robots_tag": e.headers.get("X-Robots-Tag"),
            "body": e.read().decode("utf-8", "replace"),
        }


class SeoParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title = ""
        self._in_title = False
        self.metas = []
        self.links = []
        self.scripts_ld = []
        self._in_ld = False
        self._ld_buf = []
        self.headings = []
        self._heading = None
        self._heading_buf = []
        self.images = []
        self.anchors = []
        self.html_lang = None
        self.viewport = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "html":
            self.html_lang = a.get("lang")
        elif tag == "title":
            self._in_title = True
        elif tag == "meta":
            self.metas.append(a)
            if a.get("name", "").lower() == "viewport":
                self.viewport = a.get("content")
        elif tag == "link":
            self.links.append(a)
        elif tag == "script":
            if (a.get("type") or "").lower() == "application/ld+json":
                self._in_ld = True
                self._ld_buf = []
        elif tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self._heading = tag
            self._heading_buf = []
        elif tag == "img":
            self.images.append(a)
        elif tag == "a":
            self.anchors.append(a)

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        elif tag == "script" and self._in_ld:
            self._in_ld = False
            self.scripts_ld.append("".join(self._ld_buf))
        elif self._heading == tag:
            self.headings.append(
                (tag, re.sub(r"\s+", " ", "".join(self._heading_buf)).strip()[:80])
            )
            self._heading = None

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._heading:
            self._heading_buf.append(data)
        if self._in_ld:
            self._ld_buf.append(data)


def meta_content(metas, key, attr="name"):
    for m in metas:
        if (m.get(attr) or "").lower() == key.lower():
            return m.get("content")
    return None


def analyze_html(url, res):
    p = SeoParser()
    p.feed(res["body"])
    canon = next(
        (l.get("href") for l in p.links if (l.get("rel") or "").lower() == "canonical"),
        None,
    )
    og = {
        k: meta_content(p.metas, "og:" + k, "property")
        for k in ("title", "description", "image", "url", "type", "site_name")
    }
    tw = {
        k: meta_content(p.metas, "twitter:" + k)
        for k in ("card", "title", "description", "image")
    }
    ld = []
    for raw in p.scripts_ld:
        try:
            data = json.loads(raw)
            ld.append({"valid_json": True, "types": collects_types(data), "keys": sorted(data.keys()) if isinstance(data, dict) else []})
        except Exception as e:
            ld.append({"valid_json": False, "error": str(e)[:120]})
    internal = [a.get("href") for a in p.anchors if a.get("href")]
    internal = [
        h
        for h in internal
        if h.startswith("/") and not h.startswith("//")
    ]
    return {
        "url": url,
        "status": res["status"],
        "final_url": res["final_url"],
        "content_type": res["content_type"],
        "x_robots_tag": res["x_robots_tag"],
        "lang": p.html_lang,
        "viewport": p.viewport,
        "title": re.sub(r"\s+", " ", p.title).strip(),
        "meta_description": meta_content(p.metas, "description"),
        "meta_description_len": len(meta_content(p.metas, "description") or ""),
        "meta_robots": meta_content(p.metas, "robots"),
        "canonical": canon,
        "og": og,
        "twitter": tw,
        "json_ld": ld,
        "h1_count": sum(1 for h, _ in p.headings if h == "h1"),
        "headings": p.headings,
        "images": [
            {
                "src": (i.get("src") or "")[:120],
                "alt": i.get("alt"),
                "width": i.get("width"),
                "height": i.get("height"),
                "loading": i.get("loading"),
            }
            for i in p.images
        ],
        "images_missing_alt": sum(1 for i in p.images if not (i.get("alt") or "").strip()),
        "internal_links": len(internal),
        "internal_unique": len(set(internal)),
        "internal_sample": sorted(set(internal))[:12],
    }


def collects_types(obj):
    found = []
    if isinstance(obj, dict):
        t = obj.get("@type")
        if t:
            found.append(t if isinstance(t, str) else json.dumps(t))
        for v in obj.values():
            found.extend(collects_types(v))
    elif isinstance(obj, list):
        for v in obj:
            found.extend(collects_types(v))
    return found


def sitemap_urls(url):
    res = fetch(url)
    locs = re.findall(r"<loc>([^<]+)</loc>", res["body"])
    return {
        "status": res["status"],
        "count": len(locs),
        "sample": locs[:5],
        "urls": locs,
    }


def main():
    from datetime import datetime, timezone

    out = {"generated": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")}
    index = fetch(BASE + "/sitemap.xml")
    out["sitemap_index"] = {
        "status": index["status"],
        "entries": re.findall(r"<loc>([^<]+)</loc>", index["body"]),
    }
    maps = {}
    for name in ("pages", "posts", "tags", "authors"):
        maps[name] = sitemap_urls(f"{BASE}/sitemap-{name}.xml")
    out["sitemaps"] = maps

    urls = {"home": BASE + "/"}
    if maps["posts"]["sample"]:
        urls["post"] = maps["posts"]["sample"][0]
    if maps["pages"]["sample"]:
        urls["page"] = maps["pages"]["sample"][0]
    if maps["tags"]["sample"]:
        urls["tag"] = maps["tags"]["sample"][0]
    if maps["authors"]["sample"]:
        urls["author"] = maps["authors"]["sample"][0]

    pages = {}
    for name, url in urls.items():
        try:
            pages[name] = analyze_html(url, fetch(url))
        except Exception as e:
            pages[name] = {"url": url, "error": str(e)[:200]}
    out["pages"] = pages

    matrix = []
    for kind, sm in maps.items():
        for u in sm.get("urls", []):
            try:
                p = analyze_html(u, fetch(u))
                levels = [int(h[1]) for h, _ in p["headings"]]
                order_ok = bool(levels) and levels[0] == 1 and all(
                    b <= a + 1 for a, b in zip(levels, levels[1:])
                )
                matrix.append(
                    {
                        "kind": kind,
                        "url": u,
                        "status": p["status"],
                        "title": p["title"],
                        "title_len": len(p["title"]),
                        "desc_len": p["meta_description_len"],
                        "canonical": p["canonical"],
                        "h1": p["h1_count"],
                        "heading_order_ok": order_ok,
                        "headings": [h for h, _ in p["headings"]][:8],
                        "missing_alt": p["images_missing_alt"],
                        "images": len(p["images"]),
                        "ld_types": sorted(
                            {t for x in p["json_ld"] for t in x.get("types", [])}
                        ),
                    }
                )
            except Exception as e:
                matrix.append({"kind": kind, "url": u, "error": str(e)[:120]})
    out["matrix"] = matrix

    note = urls.get("post") or BASE + "/"
    out["notfound"] = {
        "status": fetch(BASE + "/__seo-audit-404-check__")["status"],
    }
    out["robots_txt"] = fetch(BASE + "/robots.txt")["body"][:800]
    out["rss"] = {k: v for k, v in fetch(BASE + "/rss/").items() if k != "body"}
    out["llms_txt"] = {k: v for k, v in fetch(BASE + "/llms.txt").items() if k != "body"}
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
