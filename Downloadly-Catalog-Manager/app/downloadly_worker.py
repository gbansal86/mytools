#!/usr/bin/env python3
"""
Downloadly Course Catalog + Link Extractor V21
=============================================

Sources:
1) automatic discovery (DEFAULT): discover Downloadly course/video-tutorial title pages.
2) URL file: optional targeted/sample list.
3) saved HTML only: rebuild reports from the persistent archive with no network.

Fetch modes:
- offline HTTP (DEFAULT): no browser opens.
- browser: optional Selenium/Chrome rendering for dynamic pages.

The tool inventories links; it does not intentionally download archives/media. Final reports are one CSV + one XLSX with one row per course.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import threading
import time
import traceback
import uuid
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, asdict
from datetime import date, datetime, timedelta
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = PACKAGE_ROOT / 'config' / 'urls.txt'
DEFAULT_OUTPUT = PACKAGE_ROOT / 'data'
COOKIE_SNAPSHOT_PATH: Path | None = None
CLEAR_SITE_COOKIES_ON_NEW_SESSION = False
_cookie_snapshot_lock = threading.Lock()
_http_session_generation = 0
_http_session_generation_lock = threading.Lock()
from typing import Iterable
from urllib.parse import unquote, urljoin, urlparse, urldefrag
from xml.sax.saxutils import escape as xml_escape

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Missing dependency. Run: python -m pip install requests beautifulsoup4 lxml")
    raise SystemExit(2)

FILE_EXTS = {
    ".rar", ".zip", ".7z", ".tar", ".gz", ".tgz", ".bz2", ".xz", ".zst",
    ".iso", ".img", ".dmg", ".pkg", ".exe", ".msi", ".apk", ".torrent",
    ".pdf", ".epub", ".mobi", ".chm", ".djvu",
}

FILE_HOST_HINTS = (
    "rapidgator", "drive.google.com", "docs.google.com", "mega.nz", "mediafire",
    "dropbox", "onedrive", "1fichier", "uploadgig", "nitroflare", "turbobit",
    "katfile", "usersdrive", "pixeldrain", "gofile", "send.cm", "filecrypt",
    "uploadrar", "dailyuploads", "drop.download", "qiwi", "terabox",
)

OFFICIAL_PROVIDER_HINTS = (
    "udemy.com", "coursera.org", "pluralsight.com", "linkedin.com/learning",
    "linkedin.com", "oreilly.com", "masterclass.com", "skillshare.com",
    "maven.com", "academind.com", "frontendmasters.com", "kodekloud.com",
    "cloudacademy.com", "dataquest.io", "datacamp.com",
)

NOISE_TEXT = {
    "home", "menu", "contact", "contact us", "vip", "profile", "login", "register",
    "back to top", "previous", "next", "older posts", "newer posts", "search",
}

DOWNLOAD_WORDS = (
    "download", "direct link", "mirror", "part 1", "part 2", "part 3", "part 4",
    "part1", "part2", "part3", "part4", "google drive", "rapidgator", "mega",
    "mediafire", "torrent", "file", "course link", "source",
)

DOWNLOADLY_DATE_RE = re.compile(r"/(20\d{2})/(\d{1,2})/\d+/(\d{1,2})/", re.I)
DOWNLOADLY_TITLE_PATH_RE = re.compile(r"^/(20\d{2})/(\d{1,2})/\d+/(\d{1,2})/[^/]+/\d+/?$", re.I)
DYNAMIC_FRAGMENT_RE = re.compile(r"#/[A-Za-z0-9_./%+\-=]+\.html(?:\?[^\s\"'<>]*)?", re.I)
HTTP_URL_RE = re.compile(r"https?://[^\s\"'<>\\)]+", re.I)
BLOCK_PAGE_MARKERS = (
    "just a moment", "attention required", "access denied", "cf-chl-", "cloudflare",
    "captcha", "too many requests", "rate limit",
    "verifying that you are not a robot", "verify that you are not a robot",
    "verify you are human", "verification required", "checking your browser",
    "security verification", "checking if the site connection is secure",
)


class DiscoveryBlockedError(RuntimeError):
    """Raised when Downloadly returns a block/challenge page during discovery."""

    def __init__(self, url: str, status_code: int | None, detail: str = ""):
        self.url = url
        self.status_code = status_code
        status = "unknown" if status_code is None else str(status_code)
        reason = detail or ("site challenge page" if status_code == 200 else "blocked response")
        super().__init__(f"Discovery blocked at {url} (HTTP {status}): {reason}")


class DiscoveryCancelledError(RuntimeError):
    """Raised when the user requests Stop during discovery."""


@dataclass
class LinkRecord:
    parent_title: str
    parent_url: str
    saved_html: str
    link_text: str
    child_url: str
    link_type: str
    host: str
    source_attribute: str


@dataclass
class PageRecord:
    parent_title: str
    requested_url: str
    url_date: str
    mode: str
    fetch_status: str
    http_status: str
    final_url: str
    saved_html: str
    dynamic_fragment: str
    extracted_links: int
    title_source: str
    error: str
    panel_source_status: str = ""
    panel_source_url: str = ""
    panel_saved_html: str = ""


def parse_downloadly_url_date(url: str) -> date | None:
    """Parse Downloadly's /YYYY/DD/ID/MM/... title URL into YYYY-MM-DD."""
    m = DOWNLOADLY_DATE_RE.search(urlparse(url).path)
    if not m:
        return None
    year, day, month = map(int, m.groups())
    try:
        return date(year, month, day)
    except ValueError:
        return None


def fallback_title_from_url(url: str) -> str:
    """Return a readable title from a Downloadly title URL when the page cannot load."""
    parts = [p for p in unquote(urlparse(url).path).split("/") if p]
    slug = ""
    # Downloadly title URLs normally end .../<slug>/<numeric>/
    if len(parts) >= 2 and parts[-1].isdigit():
        slug = parts[-2]
    elif parts:
        slug = parts[-1]
    slug = re.sub(r"[-_]+", " ", slug).strip()
    slug = re.sub(r"\s+", " ", slug)
    if not slug:
        return "Unknown course/title"
    small = {"ai": "AI", "sql": "SQL", "aws": "AWS", "azure": "Azure", "chatgpt": "ChatGPT", "notebooklm": "NotebookLM", "udemy": "Udemy"}
    words = []
    for w in slug.split():
        lw = w.lower()
        words.append(small.get(lw, w.capitalize()))
    return " ".join(words)



def fragment_from_url(url: str) -> str:
    """Return a browser hash fragment in '#/file.html' form, or ''."""
    frag = urlparse(url).fragment or ""
    if not frag:
        return ""
    if frag.startswith("/"):
        return "#" + frag
    return "#/" + frag.lstrip("/")


def panel_source_candidates(requested_url: str, final_url: str = "") -> list[str]:
    """Generate safe HTML-only candidate URLs for a #/panel.html fragment.

    URL fragments are never sent to an HTTP server. Downloadly appears to use
    them client-side, so offline mode tries a few likely HTML-source locations
    without opening a browser and without requesting archive/media links.
    """
    frag = fragment_from_url(requested_url)
    if not frag:
        return []
    filename = frag.lstrip("#/")
    if not filename.lower().endswith(('.html', '.htm')):
        return []
    base = urldefrag(final_url or requested_url)[0]
    parsed = urlparse(base)
    origin = f"{parsed.scheme}://{parsed.netloc}/"
    candidates = [
        urljoin(base, filename),          # .../20/panel.html
        urljoin(base, "../" + filename), # .../course-slug/panel.html
        urljoin(origin, filename),        # /panel.html
    ]
    out = []
    for u in candidates:
        if u not in out:
            out.append(u)
    return out


def canonical_parent_key(url: str) -> str:
    parsed = urlparse(urldefrag(url or "")[0])
    path = parsed.path.rstrip("/") or "/"
    query = parsed.query
    if not query:
        return f"{parsed.scheme}://{parsed.netloc}{path}"
    return f"{parsed.scheme}://{parsed.netloc}{path}?{query}"

def select_urls(urls: list[str], *, date_from: date | None = None, date_to: date | None = None, limit: int = 0) -> list[str]:
    selected: list[str] = []
    use_date_filter = date_from is not None or date_to is not None
    for url in urls:
        if use_date_filter:
            d = parse_downloadly_url_date(url)
            if d is None:
                continue
            if date_from is not None and d < date_from:
                continue
            if date_to is not None and d > date_to:
                continue
        selected.append(url)
        if limit > 0 and len(selected) >= limit:
            break
    return selected


def parse_cli_date(value: str, label: str) -> date | None:
    value = (value or "").strip()
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError as exc:
        raise SystemExit(f"Invalid {label}: {value!r}. Use YYYY-MM-DD.") from exc




def _month_start(d: date) -> date:
    return date(d.year, d.month, 1)


def _shift_month_start(d: date, delta_months: int) -> date:
    total = d.year * 12 + (d.month - 1) + int(delta_months)
    year, month0 = divmod(total, 12)
    return date(year, month0 + 1, 1)


def current_two_month_window(window_end: date, lower_bound: date | None = None, *, months_per_window: int = 2) -> tuple[date, date]:
    """Return the newest calendar-month chunk ending at *window_end*.

    Example: 2026-09-28 with two-month windows -> 2026-08-01..2026-09-28.
    The lower bound is inclusive and clamps the first date when supplied.
    """
    months = max(1, int(months_per_window or 1))
    start = _shift_month_start(_month_start(window_end), -(months - 1))
    if lower_bound is not None and start < lower_bound:
        start = lower_bound
    return start, window_end


def previous_two_month_window(current_start: date, lower_bound: date | None = None, *, months_per_window: int = 2) -> tuple[date, date] | tuple[None, None]:
    """Return the calendar chunk immediately before ``current_start``."""
    prev_end = current_start - timedelta(days=1)
    if lower_bound is not None and prev_end < lower_bound:
        return None, None
    return current_two_month_window(prev_end, lower_bound, months_per_window=months_per_window)


def build_two_month_windows(lower_bound: date, upper_bound: date, *, months_per_window: int = 2) -> list[tuple[date, date]]:
    """Build newest-to-oldest inclusive calendar windows for a finite date range."""
    if lower_bound > upper_bound:
        return []
    out: list[tuple[date, date]] = []
    start, end = current_two_month_window(upper_bound, lower_bound, months_per_window=months_per_window)
    while start is not None and end is not None:
        out.append((start, end))
        start, end = previous_two_month_window(start, lower_bound, months_per_window=months_per_window)
    return out


def report_flush_due(completed_since_flush: int, *, now: float, last_flush: float, buffer_courses: int, flush_seconds: int) -> bool:
    """Return True when buffered HTML results should be written to CSV/XLSX."""
    count_due = int(buffer_courses or 0) > 0 and int(completed_since_flush or 0) >= int(buffer_courses)
    time_due = int(flush_seconds or 0) > 0 and float(now) - float(last_flush) >= int(flush_seconds)
    return bool(count_due or time_due)

def safe_name(text: str, max_len: int = 100) -> str:
    text = re.sub(r"[^A-Za-z0-9._-]+", "_", text.strip())
    text = text.strip("._-") or "page"
    return text[:max_len]


def file_ext(url: str) -> str:
    return Path(urlparse(url).path.lower()).suffix.lower()


def classify_link(url: str, text: str, parent_host: str) -> str | None:
    low_url = url.lower()
    low_text = " ".join((text or "").lower().split())
    p = urlparse(url)
    host = p.netloc.lower()

    if low_url.startswith(("javascript:", "mailto:", "tel:")):
        return None
    if DYNAMIC_FRAGMENT_RE.search(url):
        return "Dynamic download panel"
    if file_ext(url) in FILE_EXTS:
        return "Direct file/archive"
    if any(h in low_url for h in FILE_HOST_HINTS):
        return "File host / cloud"
    if any(h in low_url for h in OFFICIAL_PROVIDER_HINTS):
        return "Official course/provider"
    if host and host != parent_host:
        if any(word in low_text for word in DOWNLOAD_WORDS):
            return "External download/mirror"
        return None
    if host == parent_host or "downloadly" in host or host.endswith("cdn.ir"):
        if any(word in low_text for word in DOWNLOAD_WORDS):
            return "Downloadly download/redirect"
        path_query = (p.path or "").lower() + (("?" + p.query.lower()) if p.query else "")
        if any(k in path_query for k in ("/download", "/dl/", "redirect", "?url=", "?link=")):
            return "Downloadly download/redirect"
    return None


def normalize_candidate(raw: str, base_url: str) -> str | None:
    raw = (raw or "").strip()
    if not raw:
        return None
    if raw.startswith("#/"):
        base_no_frag, _ = urldefrag(base_url)
        return base_no_frag + raw
    if raw.startswith("//"):
        return "https:" + raw
    if raw.startswith(("http://", "https://")):
        return raw
    if raw.startswith(("mailto:", "tel:", "javascript:", "data:")):
        return None
    return urljoin(base_url, raw)


def find_dynamic_fragments(html: str) -> list[str]:
    found: list[str] = []
    for m in DYNAMIC_FRAGMENT_RE.finditer(html or ""):
        val = m.group(0)
        if val not in found:
            found.append(val)
    return found


def title_from_html(html: str) -> str:
    soup = BeautifulSoup(html, "lxml")
    h1 = soup.find("h1")
    if h1:
        text = " ".join(h1.stripped_strings).strip()
        if text:
            return text
    if soup.title:
        return soup.title.get_text(" ", strip=True)
    return ""


def is_probable_block_page(html: str, status_code: int | None = None) -> bool:
    if status_code in {401, 403, 429, 503}:
        return True
    sample = (html or "")[:15000].lower()
    return any(marker in sample for marker in BLOCK_PAGE_MARKERS)


def clear_downloadly_cookies(session) -> int:
    """Remove only Downloadly cookies from this tool's own HTTP cookie jar."""
    removed = 0
    jar = getattr(session, "cookies", None)
    if jar is None:
        return 0
    for cookie in list(jar):
        domain = (getattr(cookie, "domain", "") or "").lstrip(".").lower()
        if domain == "downloadlynet.ir" or domain.endswith(".downloadlynet.ir"):
            try:
                jar.clear(domain=getattr(cookie, "domain", None), path=getattr(cookie, "path", "/"), name=getattr(cookie, "name", None))
                removed += 1
            except Exception:
                try:
                    jar.clear()
                    removed += 1
                except Exception:
                    pass
    return removed


def write_cookie_snapshot(session, path: Path) -> None:
    """Persist non-sensitive metadata about this tool's Downloadly cookies.

    Cookie values are intentionally not written; the GUI cookie browser is for
    diagnostics, not credential/token export.
    """
    rows = []
    jar = getattr(session, "cookies", None)
    if jar is not None:
        for cookie in list(jar):
            domain = (getattr(cookie, "domain", "") or "").lower()
            if "downloadlynet.ir" not in domain:
                continue
            value = str(getattr(cookie, "value", "") or "")
            rows.append({
                "name": str(getattr(cookie, "name", "") or ""),
                "domain": domain,
                "path": str(getattr(cookie, "path", "/") or "/"),
                "secure": bool(getattr(cookie, "secure", False)),
                "expires": getattr(cookie, "expires", None),
                "value_length": len(value),
            })
    payload = {
        "site": "downloadlynet.ir",
        "saved_at": datetime.now().isoformat(timespec="seconds"),
        "cookies": rows,
    }
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    # Cookie diagnostics must not be able to terminate a crawl.
    try:
        atomic_write_json(Path(path), payload)
    except Exception:
        Path(path).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def maybe_snapshot_cookies(session) -> None:
    path = COOKIE_SNAPSHOT_PATH
    if not path:
        return
    try:
        with _cookie_snapshot_lock:
            write_cookie_snapshot(session, Path(path))
    except Exception:
        pass


def extract_links_from_html(html: str, base_url: str, saved_html: str = "", forced_title: str = "") -> list[LinkRecord]:
    soup = BeautifulSoup(html, "lxml")
    title = forced_title or title_from_html(html) or fallback_title_from_url(base_url)
    parent_host = urlparse(base_url).netloc.lower()
    candidates: list[tuple[str, str, str]] = []

    attrs = ("href", "data-href", "data-url", "data-link", "data-download", "data-src")
    for tag in soup.find_all(True):
        text = " ".join(tag.stripped_strings).strip()[:500]
        for attr in attrs:
            raw = tag.get(attr)
            if raw:
                candidates.append((str(raw), text, attr))
        onclick = tag.get("onclick")
        if onclick:
            for m in HTTP_URL_RE.finditer(str(onclick)):
                candidates.append((m.group(0), text, "onclick"))
            for m in DYNAMIC_FRAGMENT_RE.finditer(str(onclick)):
                candidates.append((m.group(0), text, "onclick"))

    for frag in find_dynamic_fragments(html):
        candidates.append((frag, "Dynamic download panel", "html-text"))

    records: list[LinkRecord] = []
    seen = set()
    for raw, text, source_attr in candidates:
        text_norm = " ".join((text or "").split())
        if text_norm.lower() in NOISE_TEXT:
            continue
        url = normalize_candidate(raw, base_url)
        if not url:
            continue
        kind = classify_link(url, text_norm, parent_host)
        if not kind:
            continue
        key = (url, kind)
        if key in seen:
            continue
        seen.add(key)
        records.append(LinkRecord(
            parent_title=title,
            parent_url=base_url,
            saved_html=saved_html,
            link_text=text_norm,
            child_url=url,
            link_type=kind,
            host=urlparse(url).netloc.lower(),
            source_attribute=source_attr,
        ))
    return records


def extract_links_from_saved_html(html_path: Path, base_url: str) -> list[LinkRecord]:
    html = html_path.read_text(encoding="utf-8", errors="replace")
    return extract_links_from_html(html, base_url, str(html_path))


def make_save_path(save_dir: Path, requested_url: str, suffix: str) -> Path:
    """Return a deliberately short filename inside the already-unique course folder.

    Older builds repeated the full course slug in both the directory and filename,
    which could push Windows paths over MAX_PATH and surface as misleading
    FileNotFoundError/Errno 2 failures.  The per-course directory already contains
    a stable URL hash, so the file only needs a short role name.
    """
    return save_dir / f"{safe_name(suffix, 32)}.html"





def archive_dir_for_url(archive_root: Path, requested_url: str) -> Path:
    """Stable per-course folder under the persistent HTML archive."""
    base = urldefrag(requested_url)[0]
    parts = [p for p in unquote(urlparse(base).path).split("/") if p]
    slug = parts[-2] if len(parts) >= 2 and parts[-1].isdigit() else (parts[-1] if parts else "course")
    digest = hashlib.sha1(requested_url.encode("utf-8", "replace")).hexdigest()[:10]
    return archive_root / f"{safe_name(slug, 90)}_{digest}"


def _path_for_meta(archive_dir: Path, value: str) -> str:
    if not value:
        return ""
    try:
        return str(Path(value).resolve().relative_to(archive_dir.resolve()))
    except Exception:
        return Path(value).name


def write_archive_meta(archive_dir: Path, page: PageRecord) -> None:
    archive_dir.mkdir(parents=True, exist_ok=True)
    files = []
    if page.saved_html:
        files.append({
            "path": _path_for_meta(archive_dir, page.saved_html),
            "kind": "parent_rendered" if page.mode == "browser" else "parent_raw",
            "source_url": page.final_url or urldefrag(page.requested_url)[0],
            "reliable": page.fetch_status == "fetched",
        })
    if page.panel_saved_html:
        files.append({
            "path": _path_for_meta(archive_dir, page.panel_saved_html),
            "kind": "panel_raw",
            "source_url": page.panel_source_url,
            "reliable": page.panel_source_status == "fetched",
        })
    payload = {
        "version": 8,
        "saved_at": datetime.now().isoformat(timespec="seconds"),
        "requested_url": page.requested_url,
        "url_date": page.url_date,
        "parent_title": page.parent_title,
        "fetch_status": page.fetch_status,
        "http_status": page.http_status,
        "final_url": page.final_url,
        "mode": page.mode,
        "dynamic_fragment": page.dynamic_fragment,
        "title_source": page.title_source,
        "error": page.error,
        "panel_source_status": page.panel_source_status,
        "panel_source_url": page.panel_source_url,
        "files": files,
        "page": asdict(page),
    }
    target = archive_dir / "meta.json"
    tmp = archive_dir / f".meta.json.{os.getpid()}.{threading.get_ident()}.{uuid.uuid4().hex}.tmp"
    try:
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        _replace_path_with_retry(tmp, target)
    finally:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass


def extract_course_from_archive(archive_dir: Path) -> tuple[PageRecord, list[LinkRecord]]:
    """Rebuild one course record using only saved HTML + meta.json. No network."""
    meta_path = archive_dir / "meta.json"
    if not meta_path.exists():
        raise FileNotFoundError(f"Missing archive metadata: {meta_path}")
    meta = json.loads(meta_path.read_text(encoding="utf-8-sig", errors="replace"))
    requested_url = meta.get("requested_url", "")
    fallback = meta.get("parent_title") or fallback_title_from_url(requested_url)
    page_data = meta.get("page") or {}
    page = PageRecord(
        parent_title=page_data.get("parent_title") or fallback,
        requested_url=page_data.get("requested_url") or requested_url,
        url_date=page_data.get("url_date") or meta.get("url_date", ""),
        mode="saved",
        fetch_status="archived",
        http_status=page_data.get("http_status") or meta.get("http_status", ""),
        final_url=page_data.get("final_url") or meta.get("final_url", ""),
        saved_html="",
        dynamic_fragment=page_data.get("dynamic_fragment") or meta.get("dynamic_fragment", ""),
        extracted_links=0,
        title_source="archive",
        error=page_data.get("error") or meta.get("error", ""),
        panel_source_status=page_data.get("panel_source_status") or meta.get("panel_source_status", ""),
        panel_source_url=page_data.get("panel_source_url") or meta.get("panel_source_url", ""),
        panel_saved_html="",
    )
    links: list[LinkRecord] = []
    seen = set()
    files = meta.get("files") or []
    referenced = set()
    best_title = page.parent_title
    for item in files:
        rel = item.get("path", "")
        if not rel:
            continue
        hp = archive_dir / rel
        referenced.add(hp.resolve() if hp.exists() else hp)
        if not hp.exists() or hp.suffix.lower() not in {".html", ".htm"}:
            continue
        html = hp.read_text(encoding="utf-8", errors="replace")
        reliable = bool(item.get("reliable", True)) and not is_probable_block_page(html)
        if reliable:
            candidate_title = title_from_html(html)
            if candidate_title and item.get("kind", "").startswith("parent"):
                best_title = candidate_title
        if not reliable:
            continue
        base_url = item.get("source_url") or page.final_url or urldefrag(page.requested_url)[0]
        rows = extract_links_from_html(html, base_url, str(hp), best_title)
        for row in rows:
            row.parent_title = best_title
            row.parent_url = page.final_url or page.requested_url
            sig = (row.child_url, row.link_type)
            if sig not in seen:
                links.append(row)
                seen.add(sig)
    # Also process manually-added HTML files in this archive folder.
    for hp in sorted(archive_dir.glob("*.htm*")):
        try:
            resolved = hp.resolve()
        except Exception:
            resolved = hp
        if resolved in referenced:
            continue
        html = hp.read_text(encoding="utf-8", errors="replace")
        if is_probable_block_page(html):
            continue
        rows = extract_links_from_html(html, page.final_url or urldefrag(page.requested_url)[0], str(hp), best_title)
        for row in rows:
            row.parent_title = best_title
            row.parent_url = page.final_url or page.requested_url
            sig = (row.child_url, row.link_type)
            if sig not in seen:
                links.append(row)
                seen.add(sig)
    page.parent_title = best_title or fallback
    page.extracted_links = len(links)
    parent_files = [x for x in files if str(x.get("kind", "")).startswith("parent")]
    panel_files = [x for x in files if str(x.get("kind", "")).startswith("panel")]
    if parent_files:
        page.saved_html = str(archive_dir / parent_files[0].get("path", ""))
    if panel_files:
        page.panel_saved_html = str(archive_dir / panel_files[0].get("path", ""))
    return page, links


_thread_local = threading.local()


def get_http_session() -> requests.Session:
    generation = _http_session_generation
    session = getattr(_thread_local, "session", None)
    session_generation = getattr(_thread_local, "session_generation", None)
    if session is not None and session_generation != generation:
        try:
            session.close()
        except Exception:
            pass
        session = None
        if hasattr(_thread_local, "session"):
            delattr(_thread_local, "session")
    if session is None:
        session = requests.Session()
        session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/136 Safari/537.36",
            "Accept-Language": "en-US,en;q=0.9",
        })
        if CLEAR_SITE_COOKIES_ON_NEW_SESSION:
            clear_downloadly_cookies(session)
        try:
            from requests.adapters import HTTPAdapter
            from urllib3.util.retry import Retry
            retry = Retry(
                total=2,
                connect=2,
                read=2,
                status=2,
                backoff_factor=0.75,
                status_forcelist=(429, 500, 502, 503, 504),
                allowed_methods=frozenset(["GET", "HEAD"]),
                respect_retry_after_header=True,
                raise_on_status=False,
            )
            adapter = HTTPAdapter(max_retries=retry, pool_connections=8, pool_maxsize=8)
            session.mount("http://", adapter)
            session.mount("https://", adapter)
        except Exception:
            pass
        _thread_local.session = session
        _thread_local.session_generation = generation
    return session


def response_html_text(resp) -> str:
    """Decode HTML robustly, preferring UTF-8 when HTTP defaults to latin-1."""
    raw = getattr(resp, "content", None)
    if isinstance(raw, (bytes, bytearray)):
        enc = (getattr(resp, "encoding", None) or "").lower()
        if not enc or enc in {"iso-8859-1", "latin-1", "latin1"}:
            try:
                return bytes(raw).decode("utf-8")
            except UnicodeDecodeError:
                pass
        try:
            return bytes(raw).decode(enc or "utf-8", errors="replace")
        except LookupError:
            return bytes(raw).decode("utf-8", errors="replace")
    return str(getattr(resp, "text", "") or "")


def fetch_panel_source(session: requests.Session, requested_url: str, final_url: str, title: str, save_dir: Path, timeout: int) -> tuple[str, str, str, list[LinkRecord]]:
    """Try raw HTML source candidates for a #/panel.html fragment.

    Returns (status, successful_url, saved_html_path, links). Only .html/.htm
    candidates are requested. Linked archives/media are never fetched.
    """
    candidates = panel_source_candidates(requested_url, final_url)
    if not candidates:
        return "", "", "", []
    saw_blocked = False
    saw_http_error = False
    for idx, candidate in enumerate(candidates, 1):
        try:
            resp = session.get(candidate, timeout=timeout, allow_redirects=True)
            maybe_snapshot_cookies(session)
        except requests.RequestException:
            continue
        html = response_html_text(resp)
        if is_probable_block_page(html, getattr(resp, 'status_code', None)):
            saw_blocked = True
            continue
        if getattr(resp, 'status_code', 0) >= 400:
            saw_http_error = True
            continue
        if not html.strip():
            continue
        save_path = make_save_path(save_dir, requested_url, f"panel{idx}_raw")
        save_path.write_text(html, encoding="utf-8", errors="replace")
        links = extract_links_from_html(html, str(getattr(resp, 'url', candidate) or candidate), str(save_path), title)
        # A successful HTML fetch counts even if it contains zero relevant links.
        return "fetched", str(getattr(resp, 'url', candidate) or candidate), str(save_path), links
    if saw_blocked:
        return "blocked", "", "", []
    if saw_http_error:
        return "http_error", "", "", []
    return "not_found", "", "", []

def fetch_offline(session: requests.Session, requested_url: str, save_dir: Path, timeout: int, preferred_title: str = "") -> tuple[PageRecord, list[LinkRecord]]:
    fallback = fallback_title_from_url(requested_url)
    url_date = parse_downloadly_url_date(requested_url)
    try:
        resp = session.get(requested_url, timeout=timeout, allow_redirects=True)
        maybe_snapshot_cookies(session)
        html = response_html_text(resp)
        blocked = is_probable_block_page(html, resp.status_code)
        http_error = resp.status_code >= 400
        save_path = make_save_path(save_dir, requested_url, "blocked" if blocked else "raw")
        if html:
            save_path.write_text(html, encoding="utf-8", errors="replace")
        else:
            save_path = Path("")

        reliable_parent = not blocked and not http_error
        if reliable_parent:
            html_title = title_from_html(html)
            title = html_title or fallback
            title_source = "html" if html_title else "url_fallback"
            links = extract_links_from_html(html, str(resp.url), str(save_path), title)
            frags = find_dynamic_fragments(html)
            fetch_status = "fetched"
            error = ""
        else:
            title = preferred_title.strip() or fallback
            title_source = "discovery" if preferred_title.strip() else "url_fallback"
            links = []
            frags = []
            fetch_status = "blocked" if blocked else "http_error"
            error = "HTTP/anti-bot response prevented reliable page extraction" if blocked else f"HTTP {resp.status_code} response"

        # Important: the browser hash is not sent in the HTTP request. If the
        # input contains #/something.html, try likely raw-HTML panel URLs too.
        panel_request_url = requested_url
        if not fragment_from_url(panel_request_url) and frags:
            panel_request_url = urldefrag(requested_url)[0] + frags[0]
        panel_status, panel_url, panel_saved, panel_links = fetch_panel_source(
            session, panel_request_url, str(resp.url), title, save_dir, timeout
        )
        seen = {(x.child_url, x.link_type) for x in links}
        for item in panel_links:
            key = (item.child_url, item.link_type)
            if key not in seen:
                links.append(item)
                seen.add(key)

        requested_frag = fragment_from_url(requested_url)
        dynamic_fragment = requested_frag or (frags[0] if frags else "")
        return PageRecord(
            parent_title=title,
            requested_url=requested_url,
            url_date=url_date.isoformat() if url_date else "",
            mode="offline",
            fetch_status=fetch_status,
            http_status=str(resp.status_code),
            final_url=str(resp.url),
            saved_html=str(save_path) if str(save_path) != "." else "",
            dynamic_fragment=dynamic_fragment,
            extracted_links=len(links),
            title_source=title_source,
            error=error,
            panel_source_status=panel_status,
            panel_source_url=panel_url,
            panel_saved_html=panel_saved,
        ), links
    except requests.RequestException as exc:
        # Even if the parent page request itself fails, try a fragment panel
        # only when a normal final URL can be derived from the requested URL.
        base = urldefrag(requested_url)[0]
        failure_title = preferred_title.strip() or fallback
        panel_status, panel_url, panel_saved, panel_links = fetch_panel_source(
            session, requested_url, base, failure_title, save_dir, timeout
        )
        return PageRecord(
            parent_title=failure_title,
            requested_url=requested_url,
            url_date=url_date.isoformat() if url_date else "",
            mode="offline",
            fetch_status="error",
            http_status="",
            final_url="",
            saved_html="",
            dynamic_fragment=fragment_from_url(requested_url),
            extracted_links=len(panel_links),
            title_source="discovery" if preferred_title.strip() else "url_fallback",
            error=str(exc),
            panel_source_status=panel_status,
            panel_source_url=panel_url,
            panel_saved_html=panel_saved,
        ), panel_links


def build_driver(page_timeout: int):
    try:
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
    except ImportError:
        print("Browser mode requires Selenium. Run: python -m pip install selenium")
        raise SystemExit(2)
    opts = Options()
    opts.add_argument("--disable-popup-blocking")
    opts.add_argument("--disable-notifications")
    opts.add_argument("--window-size=1440,1100")
    opts.add_experimental_option("prefs", {
        "download.prompt_for_download": True,
        "download_restrictions": 3,
        "profile.default_content_setting_values.automatic_downloads": 2,
    })
    driver = webdriver.Chrome(options=opts)
    driver.set_page_load_timeout(page_timeout)
    return driver


def fetch_browser(driver, requested_url: str, save_dir: Path, wait_seconds: float) -> tuple[PageRecord, list[LinkRecord]]:
    fallback = fallback_title_from_url(requested_url)
    url_date = parse_downloadly_url_date(requested_url)
    try:
        driver.get(requested_url)
        time.sleep(max(wait_seconds, 0.5))
        try:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(min(max(wait_seconds, 0.5), 3.0))
        except Exception:
            pass
        html = driver.page_source or ""
        final_url = driver.current_url
        save_path = make_save_path(save_dir, requested_url, "rendered")
        save_path.write_text(html, encoding="utf-8", errors="replace")
        blocked = is_probable_block_page(html)
        if blocked:
            return PageRecord(
                parent_title=fallback,
                requested_url=requested_url,
                url_date=url_date.isoformat() if url_date else "",
                mode="browser",
                fetch_status="blocked",
                http_status="",
                final_url=final_url,
                saved_html=str(save_path),
                dynamic_fragment="",
                extracted_links=0,
                title_source="url_fallback",
                error="Rendered page appears to be an anti-bot/access-block page",
            ), []
        title = title_from_html(html) or fallback
        title_source = "html" if title_from_html(html) else "url_fallback"
        links = extract_links_from_html(html, final_url, str(save_path), title)
        frags = find_dynamic_fragments(html)
        return PageRecord(
            parent_title=title,
            requested_url=requested_url,
            url_date=url_date.isoformat() if url_date else "",
            mode="browser",
            fetch_status="fetched",
            http_status="",
            final_url=final_url,
            saved_html=str(save_path),
            dynamic_fragment=(frags[0] if frags else ""),
            extracted_links=len(links),
            title_source=title_source,
            error="",
        ), links
    except Exception as exc:
        return PageRecord(
            parent_title=fallback,
            requested_url=requested_url,
            url_date=url_date.isoformat() if url_date else "",
            mode="browser",
            fetch_status="error",
            http_status="",
            final_url="",
            saved_html="",
            dynamic_fragment="",
            extracted_links=0,
            title_source="url_fallback",
            error=str(exc),
        ), []



def is_downloadly_title_url(url: str, base_host: str = "downloadlynet.ir") -> bool:
    """True for Downloadly post/title URLs like /YYYY/DD/ID/MM/slug/NN/."""
    p = urlparse(urldefrag(url or "")[0])
    host = p.netloc.lower().split(":", 1)[0]
    expected = (base_host or "downloadlynet.ir").lower().split(":", 1)[0]
    if host and host != expected and not host.endswith("." + expected):
        return False
    return bool(DOWNLOADLY_TITLE_PATH_RE.match(p.path or ""))


def _course_context_for_anchor(anchor) -> bool:
    """Best-effort check that a title card is a Video Tutorial/course post."""
    node = anchor
    for _ in range(7):
        if node is None:
            break
        try:
            text = " ".join(node.stripped_strings).lower()
            hrefs = [str(a.get("href", "")).lower() for a in node.find_all("a", href=True)]
        except Exception:
            text, hrefs = "", []
        if "video tutorial" in text or any("/topics/video-tutorial" in h for h in hrefs):
            return True
        # A different explicit "Posted in" category means this card is probably software/book, not a course.
        if "posted in" in text and any("/topics/" in h for h in hrefs):
            return False
        node = getattr(node, "parent", None)
    # Provider-labelled titles are a useful fallback when category markup is separated from the title.
    text = " ".join(anchor.stripped_strings).lower()
    provider_words = (
        "udemy", "pluralsight", "linkedin", "masterclass", "coursera", "skillshare",
        "maven", "academind", "frontend masters", "frontendmasters", "oreilly", "o'reilly",
        "kodekloud", "datacamp", "dataquest", "aihero", "embeddedexpertio"
    )
    return any(word in text for word in provider_words)


def extract_discovered_courses_from_html(html: str, listing_url: str) -> list[dict]:
    """Extract course/title links from one Downloadly listing page.

    Returns dictionaries with title/url/url_date. Repeated image/title anchors are collapsed.
    """
    soup = BeautifulSoup(html or "", "lxml")
    base_host = urlparse(listing_url).netloc.lower().split(":", 1)[0] or "downloadlynet.ir"
    found: dict[str, dict] = {}
    order: list[str] = []
    for a in soup.find_all("a", href=True):
        raw = str(a.get("href", "")).strip()
        if not raw:
            continue
        absolute = urljoin(listing_url, raw)
        p = urlparse(urldefrag(absolute)[0])
        # Normalize title pages to their clean parent URL; hash download panels are discovered from the page source later.
        clean = f"{p.scheme}://{p.netloc}{p.path}"
        if not is_downloadly_title_url(clean, base_host=base_host):
            continue
        if not _course_context_for_anchor(a):
            continue
        key = canonical_parent_key(clean)
        text = " ".join(a.stripped_strings).strip()
        if not text:
            img = a.find("img")
            if img:
                text = str(img.get("alt", "") or "").strip()
        title = text or fallback_title_from_url(clean)
        d = parse_downloadly_url_date(clean)
        if key not in found:
            found[key] = {"title": title, "url": clean, "url_date": d.isoformat() if d else ""}
            order.append(key)
        elif text and found[key]["title"] == fallback_title_from_url(clean):
            found[key]["title"] = text
    return [found[k] for k in order]


def read_discovery_history(out_dir: Path) -> list[dict]:
    """Read cumulative discovery history from JSON state."""
    path = Path(out_dir) / "state" / "discovery_history.json"
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig", errors="replace"))
        return [dict(r) for r in data] if isinstance(data, list) else []
    except Exception:
        return []


def update_discovery_history(out_dir: Path, rows: list[dict], seen_at: str | None = None) -> list[dict]:
    """Merge scanned discovery rows into cumulative JSON history."""
    out_dir = Path(out_dir)
    state_dir = out_dir / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    stamp = seen_at or datetime.now().isoformat(timespec="seconds")
    existing = read_discovery_history(out_dir)
    merged: dict[str, dict] = {}
    order: list[str] = []
    for r in existing:
        url = (r.get("url") or "").strip()
        if not url:
            continue
        key = canonical_parent_key(url)
        if key not in merged:
            merged[key] = dict(r)
            order.append(key)
    for src in rows:
        url = (src.get("url") or "").strip()
        if not url:
            continue
        key = canonical_parent_key(url)
        if key not in merged:
            merged[key] = {
                "title": src.get("title", ""), "url": url, "url_date": src.get("url_date", ""),
                "first_seen": stamp, "last_seen": stamp,
                "listing_page": src.get("listing_page", ""), "listing_url": src.get("listing_url", ""),
            }
            order.append(key)
        else:
            dst = merged[key]
            if src.get("title"):
                dst["title"] = src.get("title", "")
            if src.get("url_date"):
                dst["url_date"] = src.get("url_date", "")
            dst["last_seen"] = stamp
            dst["listing_page"] = src.get("listing_page", dst.get("listing_page", ""))
            dst["listing_url"] = src.get("listing_url", dst.get("listing_url", ""))
            dst.setdefault("first_seen", stamp)
    fields = ["title", "url", "url_date", "first_seen", "last_seen", "listing_page", "listing_url"]
    result = [{k: merged[key].get(k, "") for k in fields} for key in order]
    atomic_write_json(state_dir / "discovery_history.json", result)
    return result


def load_known_course_urls(out_dir: Path) -> set[str]:
    """Load already-known course URLs from JSON history/snapshot and HTML archive."""
    out_dir = Path(out_dir)
    urls: set[str] = set()
    for row in read_discovery_history(out_dir):
        if row.get("url"):
            urls.add(row["url"].strip())
    snapshot = out_dir / "state" / "discovered_courses.json"
    if snapshot.exists():
        try:
            data = json.loads(snapshot.read_text(encoding="utf-8-sig", errors="replace"))
            for row in data if isinstance(data, list) else []:
                if row.get("url"):
                    urls.add(str(row["url"]).strip())
        except Exception:
            pass
    # Read-only compatibility with V8-V12 snapshots; V13 never writes this CSV.
    legacy_snapshot = out_dir / "discovered_courses.csv"
    if legacy_snapshot.exists():
        try:
            with legacy_snapshot.open("r", encoding="utf-8-sig", newline="") as f:
                for row in csv.DictReader(f):
                    if row.get("url"):
                        urls.add(row["url"].strip())
        except Exception:
            pass
    archive_root = out_dir / "html_archive"
    if archive_root.exists():
        for meta_path in archive_root.glob("*/meta.json"):
            try:
                data = json.loads(meta_path.read_text(encoding="utf-8"))
                url = str(data.get("requested_url", "") or data.get("url", "")).strip()
                if url:
                    urls.add(url)
            except Exception:
                continue
    return urls




def extract_impreza_ajax_config(html_text: str, listing_url: str) -> dict | None:
    """Return the Impreza ``us_ajax_grid`` configuration for the main course grid.

    Downloadly's home/listing view currently renders the first batch in the HTML and
    uses the theme's ``Load More`` AJAX grid for subsequent batches.  Normal
    ``/page/2/`` requests are therefore not a reliable way to discover beyond the
    first batch.  The unrendered source contains a hidden ``.w-grid-json`` element
    whose ``onclick`` attribute is ``return {...}``; this is the same payload used by
    the site's own JavaScript.
    """
    soup = BeautifulSoup(html_text or "", "lxml")
    candidates: list[tuple[tuple[int, int, int, int], dict]] = []
    for node in soup.select('.w-grid-json[onclick]'):
        raw = str(node.get('onclick', '') or '').strip()
        match = re.match(r'^\s*return\s+(\{.*\})\s*;?\s*$', raw, re.S)
        if not match:
            continue
        try:
            cfg = json.loads(match.group(1))
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(cfg, dict) or cfg.get('action') != 'us_ajax_grid':
            continue
        grid = node.find_parent(class_=lambda value: value and 'w-grid' in (value if isinstance(value, list) else str(value).split()))
        fragment = str(grid) if grid is not None else html_text
        try:
            course_count = len(extract_discovered_courses_from_html(fragment, listing_url))
        except Exception:
            course_count = 0
        item_count = len(grid.select('.w-grid-item')) if grid is not None else 0
        has_load_more = 1 if (grid is not None and grid.select_one('.g-loadmore') is not None) else 0
        try:
            max_num_pages = int(cfg.get('max_num_pages') or 1)
        except (TypeError, ValueError):
            max_num_pages = 1
        # Prefer a Load More grid that actually contains course cards.  Item count
        # and page count are tie-breakers for pages containing more than one grid.
        score = (has_load_more, course_count, item_count, max_num_pages)
        candidates.append((score, dict(cfg)))
    if not candidates:
        return None
    candidates.sort(key=lambda item: item[0], reverse=True)
    cfg = candidates[0][1]
    cfg['ajax_url'] = str(cfg.get('ajax_url') or urljoin(listing_url, 'wp-admin/admin-ajax.php'))
    try:
        cfg['max_num_pages'] = max(1, int(cfg.get('max_num_pages') or 1))
    except (TypeError, ValueError):
        cfg['max_num_pages'] = 1
    return cfg


def _impreza_ajax_payload(config: dict, page_no: int) -> dict:
    """Build the form payload sent by Impreza's own WGrid JavaScript."""
    cfg = dict(config or {})
    raw_tv = cfg.get('template_vars') or {}
    if isinstance(raw_tv, str):
        try:
            template_vars = json.loads(raw_tv)
        except (TypeError, ValueError, json.JSONDecodeError):
            template_vars = {}
    elif isinstance(raw_tv, dict):
        # JSON round-trip gives us a deep copy without introducing another dependency.
        template_vars = json.loads(json.dumps(raw_tv))
    else:
        template_vars = {}
    query_args = template_vars.get('query_args')
    if not isinstance(query_args, dict):
        query_args = {}
        template_vars['query_args'] = query_args
    query_args['paged'] = int(page_no)

    payload: dict[str, str] = {}
    for key, value in cfg.items():
        if key == 'ajax_url':
            continue
        if key == 'template_vars':
            payload[key] = json.dumps(template_vars, separators=(',', ':'))
        elif value is None:
            continue
        elif isinstance(value, bool):
            payload[key] = '1' if value else '0'
        elif isinstance(value, (dict, list)):
            payload[key] = json.dumps(value, separators=(',', ':'))
        else:
            payload[key] = str(value)
    payload['action'] = 'us_ajax_grid'
    payload['template_vars'] = json.dumps(template_vars, separators=(',', ':'))
    return payload


def _fetch_impreza_ajax_page(session: requests.Session, config: dict, page_no: int,
                              timeout: int, referer: str):
    """Fetch one Load More batch, with small retry/backoff for transient errors."""
    ajax_url = str(config.get('ajax_url') or urljoin(referer, 'wp-admin/admin-ajax.php'))
    payload = _impreza_ajax_payload(config, page_no)
    last_resp = None
    last_exc = None
    for attempt in range(3):
        try:
            resp = session.post(
                ajax_url,
                data=payload,
                timeout=timeout,
                allow_redirects=True,
                headers={
                    'Referer': referer,
                    'X-Requested-With': 'XMLHttpRequest',
                    'Accept': 'text/html, */*; q=0.01',
                },
            )
            maybe_snapshot_cookies(session)
            last_resp = resp
            if getattr(resp, 'status_code', 0) not in {429, 500, 502, 503, 504}:
                return resp
        except requests.RequestException as exc:
            last_exc = exc
        if attempt < 2:
            time.sleep(0.75 * (2 ** attempt))
    if last_resp is not None:
        return last_resp
    if last_exc is not None:
        raise last_exc
    raise requests.RequestException('Load More request failed without a response')


def discover_downloadly_courses(*, session: requests.Session, base_url: str, timeout: int,
                                max_pages: int = 0, date_from: date | None = None,
                                date_to: date | None = None, limit: int = 0,
                                progress_callback=None, known_urls: set[str] | None = None,
                                incremental: bool = False, stop_after_known_pages: int = 2,
                                all_discovered_callback=None, initial_rows: list[dict] | None = None,
                                start_page: int = 1, batch_complete_callback=None,
                                maintenance_seconds: int = 180, maintenance_callback=None,
                                cancel_callback=None, stop_when_older_than: date | None = None) -> list[dict]:
    """Discover Downloadly course/title pages without opening a browser.

    Downloadly uses an Impreza ``Load More`` grid.  The first batch is read from
    the normal page source; later batches are requested through the grid's own
    ``us_ajax_grid`` endpoint.  If no grid configuration is present, the older
    ``/page/N/`` discovery method remains as a compatibility fallback.

    ``max_pages=0`` means all available listing/Load More batches.  Incremental
    mode returns only unseen courses and stops after the requested known-only
    streak.
    """
    base_url = (base_url or 'https://downloadlynet.ir/').rstrip('/') + '/'
    selected: list[dict] = []
    seen: set[str] = set()
    all_rows: list[dict] = []
    known_keys = {canonical_parent_key(u) for u in (known_urls or set()) if u}
    incremental = bool(incremental and known_keys)
    stop_after_known_pages = max(1, int(stop_after_known_pages or 1))
    consecutive_known_only = 0
    start_page = max(1, int(start_page or 1))
    maintenance_seconds = max(0, int(maintenance_seconds or 0))
    last_maintenance_at = time.monotonic()

    def maybe_run_maintenance(page_no: int, next_page: int) -> None:
        nonlocal last_maintenance_at
        if not maintenance_callback or maintenance_seconds <= 0:
            return
        now = time.monotonic()
        if now - last_maintenance_at < maintenance_seconds:
            return
        maintenance_callback(page_no, list(all_rows), next_page)
        last_maintenance_at = time.monotonic()

    def raise_if_cancelled() -> None:
        if cancel_callback and cancel_callback():
            raise DiscoveryCancelledError("Discovery stopped by user")

    def batch_is_entirely_older(html_text: str, listing_url: str) -> bool:
        if stop_when_older_than is None:
            return False
        rows = extract_discovered_courses_from_html(html_text, listing_url)
        dates = [parse_downloadly_url_date(str(r.get("url") or "")) for r in rows]
        dates = [d for d in dates if d is not None]
        return bool(dates) and max(dates) < stop_when_older_than

    # Seed discovery state from a durable checkpoint when resuming a full scan.
    for row0 in (initial_rows or []):
        if not isinstance(row0, dict) or not row0.get('url'):
            continue
        key = canonical_parent_key(row0['url'])
        if key in seen:
            continue
        seen.add(key)
        row = dict(row0)
        all_rows.append(row)
        if incremental and key in known_keys:
            continue
        d = parse_downloadly_url_date(row['url'])
        if date_from is not None and (d is None or d < date_from):
            continue
        if date_to is not None and (d is None or d > date_to):
            continue
        selected.append(row)
        if limit > 0 and len(selected) >= limit:
            selected = selected[:limit]
            break

    def consume(page_no: int, listing_url: str, html_text: str) -> tuple[int, int, bool]:
        """Consume one listing fragment. Returns (rows, unique_rows, limit_hit)."""
        nonlocal consecutive_known_only
        rows = extract_discovered_courses_from_html(html_text, listing_url)
        unique_rows: list[tuple[str, dict]] = []
        for row0 in rows:
            key = canonical_parent_key(row0['url'])
            if key in seen:
                continue
            seen.add(key)
            row = dict(row0)
            row['listing_page'] = page_no
            row['listing_url'] = listing_url
            unique_rows.append((key, row))
            all_rows.append(dict(row))
            if all_discovered_callback:
                all_discovered_callback(dict(row))

        if incremental and unique_rows:
            unknown_on_page = any(key not in known_keys for key, _ in unique_rows)
            known_on_page = any(key in known_keys for key, _ in unique_rows)
            consecutive_known_only = (consecutive_known_only + 1) if (known_on_page and not unknown_on_page) else 0

        for key, row in unique_rows:
            if incremental and key in known_keys:
                continue
            d = parse_downloadly_url_date(row['url'])
            if date_from is not None and (d is None or d < date_from):
                continue
            if date_to is not None and (d is None or d > date_to):
                continue
            selected.append(row)
            if limit > 0 and len(selected) >= limit:
                if progress_callback:
                    progress_callback(page_no, len(selected), listing_url, 'limit reached')
                return len(rows), len(unique_rows), True
        return len(rows), len(unique_rows), False

    # Page/batch 1 is always the ordinary homepage/listing source.
    if progress_callback:
        progress_callback(1, len(selected), base_url, 'fetching first listing batch')
    try:
        first_resp = session.get(base_url, timeout=timeout, allow_redirects=True)
        maybe_snapshot_cookies(session)
        first_html = response_html_text(first_resp)
    except requests.RequestException as exc:
        if progress_callback:
            progress_callback(1, len(selected), base_url, f'error: {exc}')
        return selected
    if getattr(first_resp, 'status_code', 0) >= 400 or is_probable_block_page(first_html, getattr(first_resp, 'status_code', None)):
        status_code = getattr(first_resp, 'status_code', None)
        if progress_callback:
            progress_callback(1, len(selected), base_url, f'blocked/http {status_code if status_code is not None else ""}')
        detail = 'HTTP 200 challenge/block page' if status_code == 200 else 'blocked listing response'
        raise DiscoveryBlockedError(base_url, status_code, detail)

    first_url = str(getattr(first_resp, 'url', base_url) or base_url)
    if start_page <= 1:
        row_count, unique_count, limit_hit = consume(1, first_url, first_html)
        if batch_complete_callback:
            batch_complete_callback(1, list(all_rows), 2)
        maybe_run_maintenance(1, 2)
        if progress_callback:
            progress_callback(1, len(selected), first_url, f'found {row_count} course card(s)')
        if batch_is_entirely_older(first_html, first_url):
            return selected
        if limit_hit:
            return selected
        if incremental and consecutive_known_only >= stop_after_known_pages:
            return selected
        if max_pages == 1:
            return selected
    elif progress_callback:
        progress_callback(1, len(selected), first_url, f'resumed checkpoint; next batch={start_page}')

    raise_if_cancelled()

    # Preferred path: reproduce the site's own Load More AJAX requests.
    ajax_config = extract_impreza_ajax_config(first_html, first_url)
    if ajax_config and int(ajax_config.get('max_num_pages') or 1) > 1:
        site_pages = int(ajax_config.get('max_num_pages') or 1)
        last_page = min(site_pages, max_pages) if max_pages > 0 else site_pages
        if progress_callback:
            progress_callback(1, len(selected), first_url,
                              f'detected Load More grid with {site_pages} batch(es); scanning through {last_page}')
        consecutive_errors = 0
        for page_no in range(max(2, start_page), last_page + 1):
            raise_if_cancelled()
            listing_label = f"{ajax_config.get('ajax_url')} [Load More batch {page_no}/{site_pages}]"
            if progress_callback:
                progress_callback(page_no, len(selected), listing_label, 'fetching Load More batch')
            try:
                resp = _fetch_impreza_ajax_page(session, ajax_config, page_no, timeout, first_url)
                html_text = response_html_text(resp)
            except requests.RequestException as exc:
                consecutive_errors += 1
                if progress_callback:
                    progress_callback(page_no, len(selected), listing_label, f'Load More error: {exc}')
                if consecutive_errors >= 3:
                    break
                continue
            if getattr(resp, 'status_code', 0) >= 400 or is_probable_block_page(html_text, getattr(resp, 'status_code', None)):
                status_code = getattr(resp, 'status_code', None)
                if progress_callback:
                    progress_callback(page_no, len(selected), listing_label,
                                      f'Load More blocked/http {status_code if status_code is not None else ""}')
                detail = 'HTTP 200 challenge/block page' if status_code == 200 else 'blocked Load More response'
                raise DiscoveryBlockedError(listing_label, status_code, detail)
            consecutive_errors = 0
            row_count, unique_count, limit_hit = consume(page_no, listing_label, html_text)
            if batch_complete_callback:
                batch_complete_callback(page_no, list(all_rows), page_no + 1)
            maybe_run_maintenance(page_no, page_no + 1)
            if progress_callback:
                if incremental:
                    progress_callback(page_no, len(selected), listing_label,
                                      f'found {row_count} course card(s); known-only streak={consecutive_known_only}/{stop_after_known_pages}')
                else:
                    progress_callback(page_no, len(selected), listing_label,
                                      f'found {row_count} course card(s)')
            if batch_is_entirely_older(html_text, listing_label):
                break
            if limit_hit:
                return selected
            if incremental and consecutive_known_only >= stop_after_known_pages:
                break
        return selected

    # Compatibility fallback for sites/listing templates that use normal pagination.
    page_no = max(2, start_page)
    consecutive_empty = 0
    while True:
        raise_if_cancelled()
        if max_pages > 0 and page_no > max_pages:
            break
        listing_url = urljoin(base_url, f'page/{page_no}/')
        if progress_callback:
            progress_callback(page_no, len(selected), listing_url, 'fetching legacy listing page')
        try:
            resp = session.get(listing_url, timeout=timeout, allow_redirects=True)
            maybe_snapshot_cookies(session)
            html_text = response_html_text(resp)
        except requests.RequestException as exc:
            consecutive_empty += 1
            if progress_callback:
                progress_callback(page_no, len(selected), listing_url, f'error: {exc}')
            if consecutive_empty >= 3:
                break
            page_no += 1
            continue
        if getattr(resp, 'status_code', 0) >= 400 or is_probable_block_page(html_text, getattr(resp, 'status_code', None)):
            status_code = getattr(resp, 'status_code', None)
            if progress_callback:
                progress_callback(page_no, len(selected), listing_url, f'blocked/http {status_code if status_code is not None else ""}')
            detail = 'HTTP 200 challenge/block page' if status_code == 200 else 'blocked listing response'
            raise DiscoveryBlockedError(listing_url, status_code, detail)
        row_count, unique_count, limit_hit = consume(page_no, listing_url, html_text)
        if batch_complete_callback:
            batch_complete_callback(page_no, list(all_rows), page_no + 1)
        consecutive_empty = consecutive_empty + 1 if unique_count == 0 else 0
        if progress_callback:
            progress_callback(page_no, len(selected), listing_url, f'found {row_count} course card(s)')
        if batch_is_entirely_older(html_text, listing_url):
            break
        if limit_hit:
            return selected
        if incremental and consecutive_known_only >= stop_after_known_pages:
            break
        if consecutive_empty >= 3:
            break
        page_no += 1
    return selected


def write_discovery_snapshot(out_dir: Path, rows: list[dict]) -> None:
    fields = ["title", "url", "url_date", "listing_page", "listing_url"]
    state_dir = Path(out_dir) / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    payload = [{k: r.get(k, "") for k in fields} for r in rows]
    atomic_write_json(state_dir / "discovered_courses.json", payload)



def read_urls(path: Path) -> list[str]:
    urls: list[str] = []
    for line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith(("http://", "https://")):
            urls.append(line)
    return list(dict.fromkeys(urls))



REPORT_COLUMNS = [
    "Course / Post Title",
    "Parent Course Page",
    "Published Date",
    "Categories",
    "Udemy Source/coupon Link(s)",
    "Google Drive Link(s)",
    "Rapidgator Link(s)",
    "Direct File Link(s)",
    "Other File Host Link(s)",
    "Host(s)",
    "Status",
]

SOCIAL_SHARE_HOSTS = (
    "facebook.com", "twitter.com", "x.com", "linkedin.com", "pinterest.com",
    "reddit.com", "whatsapp.com", "telegram.me", "t.me",
)


def clean_post_title(title: str) -> str:
    title = " ".join((title or "").split()).strip()
    title = re.sub(r"\s*[–—-]\s*Downloadly\s*$", "", title, flags=re.I).strip()
    return title


def unwrap_href_li(url: str) -> str:
    """Unwrap href.li/?https://... links used for original provider URLs."""
    try:
        parsed = urlparse(url)
        if parsed.netloc.lower().endswith("href.li") and parsed.query:
            candidate = unquote(parsed.query).strip()
            if candidate.startswith(("http://", "https://")):
                return candidate
    except Exception:
        pass
    return url


def extract_page_metadata(page: PageRecord) -> dict:
    title = clean_post_title(page.parent_title) or fallback_title_from_url(page.requested_url)
    published = page.url_date or ""
    categories: list[str] = []
    html_path = Path(page.saved_html) if page.saved_html else None
    if html_path and html_path.exists():
        try:
            html = html_path.read_text(encoding="utf-8", errors="replace")
            soup = BeautifulSoup(html, "lxml")
            post_title = soup.select_one(".post_title a") or soup.select_one("h1.entry-title") or soup.select_one("h1")
            if post_title:
                parsed_title = clean_post_title(post_title.get_text(" ", strip=True))
                if parsed_title:
                    title = parsed_title
            time_tag = soup.select_one("time.entry-date[datetime]") or soup.find("time", attrs={"datetime": True})
            if time_tag and time_tag.get("datetime"):
                dt = str(time_tag.get("datetime")).strip()
                m = re.match(r"(20\d{2}-\d{2}-\d{2})", dt)
                if m:
                    published = m.group(1)
            for a in soup.select('.post_taxonomy a[href*="/topics/"]'):
                text = " ".join(a.stripped_strings).strip()
                if text and text not in categories:
                    categories.append(text)
        except Exception:
            pass
    return {"title": title, "published_date": published, "categories": categories}


def _dedupe_strings(items: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for item in items:
        val = (item or "").strip()
        if not val or val in seen:
            continue
        seen.add(val)
        out.append(val)
    return out


def _link_display(link: LinkRecord, url: str) -> str:
    text = " ".join((link.link_text or "").split()).strip()
    if not text or text == url:
        return url
    return f"{text} | {url}"


def _page_status(page: PageRecord) -> str:
    status = (page.fetch_status or "").lower()
    if status == "fetched":
        return "Fetched"
    if status == "archived":
        return "Saved HTML"
    if status == "discovered_pending":
        return "Discovered - pending extraction"
    if status == "blocked":
        return "Blocked" + (f" (HTTP {page.http_status})" if page.http_status else "")
    if status == "http_error":
        return "HTTP error" + (f" {page.http_status}" if page.http_status else "")
    if status == "error":
        return "Error"
    return page.fetch_status or "Unknown"


def build_report_rows(pages: list[PageRecord], links: list[LinkRecord]) -> tuple[list[str], list[dict]]:
    """Build exactly one user-facing row per course/title."""
    by_key: dict[str, list[LinkRecord]] = {}
    by_title: dict[str, list[LinkRecord]] = {}
    for link in links:
        by_key.setdefault(canonical_parent_key(link.parent_url), []).append(link)
        by_title.setdefault(clean_post_title(link.parent_title), []).append(link)

    rows: list[dict] = []
    for page in pages:
        meta = extract_page_metadata(page)
        course_links: list[LinkRecord] = []
        seen_sig: set[tuple[str, str]] = set()
        keys = [canonical_parent_key(page.requested_url)]
        if page.final_url:
            keys.insert(0, canonical_parent_key(page.final_url))
        candidates: list[LinkRecord] = []
        for key in keys:
            candidates.extend(by_key.get(key, []))
        candidates.extend(by_title.get(clean_post_title(page.parent_title), []))
        for link in candidates:
            sig = (link.child_url, link.link_type)
            if sig in seen_sig:
                continue
            seen_sig.add(sig)
            course_links.append(link)

        udemy: list[str] = []
        gdrive: list[str] = []
        rapid: list[str] = []
        direct: list[str] = []
        other: list[str] = []
        hosts: list[str] = []

        for link in course_links:
            original_url = (link.child_url or "").strip()
            if not original_url:
                continue
            final_url = unwrap_href_li(original_url)
            parsed = urlparse(final_url)
            host = parsed.netloc.lower().split(":", 1)[0]
            low_url = final_url.lower()
            if any(x in low_url for x in ("/wp-json/oembed/", "/tag/", "/topics/", "/downloads/vip-membership/")):
                continue
            if any(host == h or host.endswith("." + h) for h in SOCIAL_SHARE_HOSTS):
                continue
            if link.link_type == "Dynamic download panel":
                continue
            if "/files/elearning/sample/" in low_url:
                continue

            display = _link_display(link, final_url)
            kept = False
            if host == "udemy.com" or host.endswith(".udemy.com"):
                udemy.append(final_url)
                kept = True
            elif host in {"drive.google.com", "docs.google.com"} or host.endswith(".drive.google.com"):
                gdrive.append(display)
                kept = True
            elif "rapidgator" in host:
                rapid.append(display)
                kept = True
            elif link.link_type == "Direct file/archive" or ("downloadly" in host and file_ext(final_url) in FILE_EXTS):
                direct.append(display)
                kept = True
            elif link.link_type == "File host / cloud":
                other.append(display)
                kept = True
            elif link.link_type == "External download/mirror" and host and "downloadly" not in host:
                other.append(display)
                kept = True
            if kept and host and host not in hosts:
                hosts.append(host)

        rows.append({
            "Course / Post Title": meta["title"],
            "Parent Course Page": page.requested_url,
            "Published Date": meta["published_date"],
            "Categories": "\n".join(_dedupe_strings(meta["categories"])),
            "Udemy Source/coupon Link(s)": "\n".join(_dedupe_strings(udemy)),
            "Google Drive Link(s)": "\n".join(_dedupe_strings(gdrive)),
            "Rapidgator Link(s)": "\n".join(_dedupe_strings(rapid)),
            "Direct File Link(s)": "\n".join(_dedupe_strings(direct)),
            "Other File Host Link(s)": "\n".join(_dedupe_strings(other)),
            "Host(s)": "\n".join(_dedupe_strings(hosts)),
            "Status": _page_status(page),
        })
    return list(REPORT_COLUMNS), rows


def _xlsx_col_name(n: int) -> str:
    out = ""
    while n:
        n, rem = divmod(n - 1, 26)
        out = chr(65 + rem) + out
    return out


def _replace_path_with_retry(tmp: Path, target: Path, *, retries: int = 20, base_delay: float = 0.05) -> None:
    """Replace a report file while tolerating brief Windows sharing violations."""
    attempts = max(1, int(retries or 1))
    for attempt in range(attempts):
        try:
            tmp.replace(target)
            return
        except OSError as exc:
            retryable = (
                isinstance(exc, PermissionError)
                or getattr(exc, "winerror", None) in {5, 32, 33}
                or getattr(exc, "errno", None) in {13, 16}
            )
            if (not retryable) or attempt + 1 >= attempts:
                raise
            time.sleep(max(0.0, base_delay) * (attempt + 1))


def write_xlsx_report(path: Path, headers: list[str], rows: list[dict]) -> None:
    """Write a compact one-sheet XLSX using only the Python standard library."""
    path.parent.mkdir(parents=True, exist_ok=True)
    widths = [42, 58, 15, 28, 60, 60, 62, 68, 62, 30, 18]
    max_row = len(rows) + 1
    max_col = len(headers)

    def cell_xml(ref: str, value: object, style: int) -> str:
        text = str(value if value is not None else "")[:32767]
        return f'<c r="{ref}" t="inlineStr" s="{style}"><is><t xml:space="preserve">{xml_escape(text)}</t></is></c>'

    sheet_rows = []
    header_cells = "".join(cell_xml(f"{_xlsx_col_name(i)}1", h, 1) for i, h in enumerate(headers, 1))
    sheet_rows.append(f'<row r="1" ht="30" customHeight="1">{header_cells}</row>')
    for r_idx, row in enumerate(rows, 2):
        cells = "".join(cell_xml(f"{_xlsx_col_name(c_idx)}{r_idx}", row.get(h, ""), 2) for c_idx, h in enumerate(headers, 1))
        sheet_rows.append(f'<row r="{r_idx}" ht="62" customHeight="1">{cells}</row>')
    cols_xml = "".join(
        f'<col min="{i}" max="{i}" width="{widths[i-1] if i-1 < len(widths) else 22}" customWidth="1"/>'
        for i in range(1, max_col + 1)
    )
    dim = f"A1:{_xlsx_col_name(max_col)}{max(1, max_row)}"
    sheet_xml = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        f'<dimension ref="{dim}"/>'
        '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
        f'<sheetFormatPr defaultRowHeight="18"/><cols>{cols_xml}</cols><sheetData>{"".join(sheet_rows)}</sheetData>'
        f'<autoFilter ref="{dim}"/><pageMargins left="0.25" right="0.25" top="0.5" bottom="0.5" header="0.2" footer="0.2"/>'
        '</worksheet>'
    )
    styles_xml = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="10"/><name val="Segoe UI"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="10"/><name val="Segoe UI"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1F4E78"/><bgColor indexed="64"/></patternFill></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>'
    )
    workbook_xml = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="Course Report" sheetId="1" r:id="rId1"/></sheets></workbook>'
    )
    workbook_rels = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>'
    )
    root_rels = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>'
    )
    content_types = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>'
    )
    tmp = path.parent / f".{path.name}.{os.getpid()}.{threading.get_ident()}.{uuid.uuid4().hex}.tmp"
    try:
        with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr("[Content_Types].xml", content_types)
            z.writestr("_rels/.rels", root_rels)
            z.writestr("xl/workbook.xml", workbook_xml)
            z.writestr("xl/_rels/workbook.xml.rels", workbook_rels)
            z.writestr("xl/worksheets/sheet1.xml", sheet_xml)
            z.writestr("xl/styles.xml", styles_xml)
        # Validate the generated workbook before replacing the user's report.
        with zipfile.ZipFile(tmp, "r") as check:
            bad = check.testzip()
            if bad:
                raise RuntimeError(f"Generated XLSX is corrupt at {bad}")
        _replace_path_with_retry(tmp, path)
    finally:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass



def build_grouped_rows(pages: list[PageRecord], links: list[LinkRecord]) -> tuple[list[str], list[dict]]:
    """Build one CSV row per title, expanding inside links across columns."""
    grouped: dict[str, list[LinkRecord]] = {}
    for link in links:
        grouped.setdefault(canonical_parent_key(link.parent_url), []).append(link)

    max_links = 0
    rows: list[dict] = []
    base_headers = [
        "parent_title", "requested_url", "url_date", "mode", "fetch_status",
        "http_status", "extracted_links", "panel_source_status", "panel_source_url",
        "title_source", "error",
    ]
    for page in pages:
        page_keys = [
            canonical_parent_key(page.final_url or page.requested_url),
            canonical_parent_key(page.requested_url),
        ]
        page_links: list[LinkRecord] = []
        seen = set()
        for key in page_keys:
            for link in grouped.get(key, []):
                sig = (link.child_url, link.link_type)
                if sig not in seen:
                    page_links.append(link)
                    seen.add(sig)
        # Also merge same-title links from fragment/panel HTML whose base URL differs.
        for link in links:
            if link.parent_title == page.parent_title:
                sig = (link.child_url, link.link_type)
                if sig not in seen:
                    page_links.append(link)
                    seen.add(sig)
        row = {
            "parent_title": page.parent_title,
            "requested_url": page.requested_url,
            "url_date": page.url_date,
            "mode": page.mode,
            "fetch_status": page.fetch_status,
            "http_status": page.http_status,
            "extracted_links": len(page_links),
            "panel_source_status": page.panel_source_status,
            "panel_source_url": page.panel_source_url,
            "title_source": page.title_source,
            "error": page.error,
        }
        for i, link in enumerate(page_links, 1):
            row[f"link_{i}_text"] = link.link_text
            row[f"link_{i}_url"] = link.child_url
            row[f"link_{i}_type"] = link.link_type
            row[f"link_{i}_host"] = link.host
        max_links = max(max_links, len(page_links))
        rows.append(row)

    headers = list(base_headers)
    for i in range(1, max_links + 1):
        headers.extend([f"link_{i}_text", f"link_{i}_url", f"link_{i}_type", f"link_{i}_host"])
    return headers, rows


def write_csv(path: Path, fieldnames: list[str], rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.parent / f".{path.name}.{os.getpid()}.{threading.get_ident()}.{uuid.uuid4().hex}.tmp"
    try:
        with tmp.open("w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for row in rows:
                writer.writerow(row)
            f.flush()
            try:
                os.fsync(f.fileno())
            except OSError:
                pass
        _replace_path_with_retry(tmp, path)
    finally:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass



def _retryable_replace_error(exc: OSError) -> bool:
    return (
        isinstance(exc, PermissionError)
        or getattr(exc, "winerror", None) in {5, 32, 33}
        or getattr(exc, "errno", None) in {13, 16}
    )


def atomic_write_json(path: Path, payload: dict, *, retries: int = 12, base_delay: float = 0.025) -> None:
    """Atomically write JSON, tolerating brief Windows reader locks.

    A unique same-directory temp file avoids collisions between rapid status writes.
    ``os.replace`` is retried for sharing/access violations commonly caused by GUI readers.
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.parent / f"{path.name}.{os.getpid()}.{threading.get_ident()}.{uuid.uuid4().hex}.tmp"
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    attempts = max(1, int(retries or 1))
    try:
        for attempt in range(attempts):
            try:
                os.replace(tmp, path)
                return
            except OSError as exc:
                if not _retryable_replace_error(exc) or attempt + 1 >= attempts:
                    raise
                time.sleep(max(0.0, base_delay) * (attempt + 1))
    finally:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass


def safe_write_progress_json(path: Path, payload: dict, log_path: Path | None = None) -> bool:
    """Best-effort progress write. Progress telemetry must never terminate the worker."""
    try:
        atomic_write_json(path, payload)
        return True
    except OSError as exc:
        if log_path:
            try:
                log_line(log_path, f"Progress status write skipped after retries: {exc}")
            except Exception:
                pass
        return False


def discovery_checkpoint_signature(base_url: str, date_from: date | None, date_to: date | None, limit: int, max_pages: int) -> dict:
    return {
        "base_url": (base_url or "").rstrip("/") + "/",
        "date_from": date_from.isoformat() if date_from else "",
        "date_to": date_to.isoformat() if date_to else "",
        "limit": int(limit or 0),
        "max_pages": int(max_pages or 0),
    }


def read_discovery_checkpoint(out_dir: Path, signature: dict) -> dict | None:
    path = Path(out_dir) / "state" / "discovery_checkpoint.json"
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    if data.get("signature") != signature or data.get("status") != "in_progress":
        return None
    if not isinstance(data.get("rows"), list):
        return None
    return data


def write_discovery_checkpoint(out_dir: Path, signature: dict, page_no: int, next_page: int, rows: list[dict]) -> None:
    path = Path(out_dir) / "state" / "discovery_checkpoint.json"
    payload = {
        "version": 1, "status": "in_progress", "signature": signature,
        "last_completed_batch": int(page_no), "next_batch": int(next_page),
        "course_count": len(rows), "updated_at": datetime.now().isoformat(timespec="seconds"),
        "rows": rows,
    }
    atomic_write_json(path, payload)


def clear_discovery_checkpoint(out_dir: Path) -> None:
    path = Path(out_dir) / "state" / "discovery_checkpoint.json"
    try:
        path.unlink(missing_ok=True)
    except OSError:
        pass


def discovery_rows_to_pending_pages(rows: list[dict]) -> list[PageRecord]:
    """Represent discovered-but-not-yet-fetched courses in the normal report."""
    pages: list[PageRecord] = []
    for row in rows or []:
        if not isinstance(row, dict):
            continue
        url = str(row.get("url") or "").strip()
        if not url:
            continue
        title = str(row.get("title") or "").strip() or fallback_title_from_url(url)
        url_date = str(row.get("url_date") or "").strip()
        pages.append(PageRecord(
            parent_title=title, requested_url=url, url_date=url_date, mode="discovery",
            fetch_status="discovered_pending", http_status="", final_url="", saved_html="",
            dynamic_fragment=fragment_from_url(url), extracted_links=0, title_source="discovery", error="",
        ))
    return pages


def rotate_http_sessions() -> int:
    """Invalidate all thread-local HTTP sessions for the next request.

    Worker threads compare their stored generation with this global generation,
    close the stale session, and create a fresh Downloadly-only cookie jar.
    """
    global _http_session_generation
    with _http_session_generation_lock:
        _http_session_generation += 1
        return _http_session_generation


def reset_http_session() -> None:
    """Compatibility wrapper: invalidate sessions and drop the caller's session now."""
    rotate_http_sessions()
    try:
        session = getattr(_thread_local, "session", None)
        if session is not None:
            try:
                session.close()
            except Exception:
                pass
        if hasattr(_thread_local, "session"):
            delattr(_thread_local, "session")
        if hasattr(_thread_local, "session_generation"):
            delattr(_thread_local, "session_generation")
    except Exception:
        pass


def wait_for_block_retry(seconds: int, cancel_file: Path, state: dict, progress_file: Path,
                         log_file: Path, sleep_fn=time.sleep) -> bool:
    """Pause without exiting after a site block. Return False only when user cancels."""
    total = max(0, int(seconds or 0))
    if total <= 0:
        return True
    for remaining in range(total, 0, -1):
        if cancel_requested(cancel_file):
            return False
        state["status"] = "paused_blocked"
        state["message"] = f"Site block detected. Checkpoint/report saved. Automatic offline retry in {remaining}s"
        safe_write_progress_json(progress_file, state, log_file)
        sleep_fn(1)
    return not cancel_requested(cancel_file)


def log_line(log_path: Path, message: str) -> None:
    stamp = datetime.now().strftime("%H:%M:%S")
    line = f"[{stamp}] {message}"
    print(line, flush=True)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def cancel_requested(cancel_file: Path) -> bool:
    return bool(cancel_file and cancel_file.exists())


def archive_meta_for_url(archive_root: Path, url: str) -> Path:
    return archive_dir_for_url(archive_root, url) / "meta.json"


def fetch_archive_extract_one(url: str, *, archive_root: Path, mode: str, timeout: int,
                              wait_seconds: float, refresh: bool, headless_browser: bool,
                              preferred_title: str = "") -> tuple[PageRecord, list[LinkRecord], bool]:
    """Fetch one URL when needed, persist HTML, then extract. Returns reused flag."""
    archive_dir = archive_dir_for_url(archive_root, url)
    meta_path = archive_dir / "meta.json"
    if meta_path.exists() and not refresh:
        reusable = True
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8-sig", errors="replace"))
            status = str(meta.get("fetch_status") or (meta.get("page") or {}).get("fetch_status") or "").lower()
            if status in {"blocked", "http_error", "error"}:
                reusable = False
            files = [f for f in (meta.get("files") or []) if isinstance(f, dict)]
            if files and not any(bool(f.get("reliable")) for f in files):
                reusable = False
        except Exception:
            # Preserve backward compatibility with older good archives whose meta
            # predates the reliability flag; extraction below is still validated.
            reusable = True
        if reusable:
            page, links = extract_course_from_archive(archive_dir)
            if preferred_title.strip() and page.title_source in {"url_fallback", "archive"}:
                page.parent_title = preferred_title.strip()
                page.title_source = "discovery"
                for link in links:
                    link.parent_title = page.parent_title
            return page, links, True
    archive_dir.mkdir(parents=True, exist_ok=True)
    if mode == "offline":
        page, links = fetch_offline(get_http_session(), url, archive_dir, timeout, preferred_title=preferred_title)
    else:
        # Browser mode intentionally creates an independent browser session per task.
        driver = build_driver(timeout, headless=headless_browser)
        try:
            page, links = fetch_browser(driver, url, archive_dir, wait_seconds)
        finally:
            try:
                driver.quit()
            except Exception:
                pass
    if preferred_title.strip() and page.title_source == "url_fallback":
        page.parent_title = preferred_title.strip()
        page.title_source = "discovery"
        for link in links:
            link.parent_title = page.parent_title
    write_archive_meta(archive_dir, page)
    # Re-extract from disk to verify that saved HTML is sufficient for later use.
    try:
        archived_page, archived_links = extract_course_from_archive(archive_dir)
        archived_page.mode = page.mode
        archived_page.fetch_status = page.fetch_status
        archived_page.http_status = page.http_status
        archived_page.final_url = page.final_url
        archived_page.title_source = page.title_source if page.title_source != "url_fallback" else archived_page.title_source
        archived_page.error = page.error
        archived_page.panel_source_status = page.panel_source_status
        archived_page.panel_source_url = page.panel_source_url
        if archived_links or not links:
            page, links = archived_page, archived_links
    except Exception:
        pass
    return page, links, False


def scan_archive(archive_root: Path) -> list[tuple[str, Path]]:
    rows: list[tuple[str, Path]] = []
    if not archive_root.exists():
        return rows
    for meta_path in sorted(archive_root.glob("*/meta.json")):
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8-sig", errors="replace"))
            url = meta.get("requested_url") or (meta.get("page") or {}).get("requested_url") or ""
            if url:
                rows.append((url, meta_path.parent))
        except Exception:
            continue
    return rows


def write_outputs(out_dir: Path, pages: list[PageRecord], all_links: list[LinkRecord]) -> None:
    """Write only the two user-facing report files: one CSV and one XLSX."""
    reports_dir = Path(out_dir) / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    headers, rows = build_report_rows(pages, all_links)
    write_csv(reports_dir / "course_report.csv", headers, rows)
    write_xlsx_report(reports_dir / "course_report.xlsx", headers, rows)


def safe_write_outputs(out_dir: Path, pages: list[PageRecord], all_links: list[LinkRecord],
                       log_path: Path | None = None, error_log_path: Path | None = None) -> bool:
    """Write reports without allowing report-generation errors to kill extraction."""
    try:
        write_outputs(out_dir, pages, all_links)
        return True
    except Exception:
        tb = traceback.format_exc()
        if error_log_path is None:
            error_log_path = Path(out_dir) / "logs" / "report_errors.log"
        try:
            error_log_path.parent.mkdir(parents=True, exist_ok=True)
            with error_log_path.open("a", encoding="utf-8") as f:
                f.write(f"\n[{datetime.now().isoformat(timespec='seconds')}] Report generation failed\n{tb}\n")
        except Exception:
            pass
        if log_path:
            try:
                log_line(log_path, f"Report generation warning: {tb.strip().splitlines()[-1] if tb.strip() else 'unknown error'}")
            except Exception:
                pass
        return False



def _report_status_rank(status: str) -> int:
    text = (status or "").strip().lower()
    if text.startswith("fetched") or text.startswith("saved html"):
        return 5
    if text.startswith("http error") or text.startswith("error"):
        return 4
    if text.startswith("blocked"):
        return 3
    if text.startswith("discovered"):
        return 1
    return 2


def merge_report_rows(out_dir: Path, pages: list[PageRecord], links: list[LinkRecord]) -> tuple[list[str], list[dict]]:
    """Merge fresh page rows into the existing one-row-per-course report.

    This lets rolling mode update CSV/XLSX from a small buffer of newly archived
    HTML pages without reparsing the entire HTML archive every time.
    """
    headers, fresh_rows = build_report_rows(pages, links)
    reports_dir = Path(out_dir) / "reports"
    existing_path = reports_dir / "course_report.csv"
    existing_rows: list[dict] = []
    if existing_path.exists():
        try:
            with existing_path.open("r", encoding="utf-8-sig", newline="") as f:
                existing_rows = [dict(r) for r in csv.DictReader(f)]
        except Exception:
            existing_rows = []

    by_key: dict[str, dict] = {}
    order: list[str] = []
    for row in existing_rows:
        key = canonical_parent_key(str(row.get("Parent Course Page") or ""))
        if not key:
            continue
        if key not in by_key:
            order.append(key)
        by_key[key] = {h: row.get(h, "") for h in headers}

    for row in fresh_rows:
        key = canonical_parent_key(str(row.get("Parent Course Page") or ""))
        if not key:
            continue
        old = by_key.get(key)
        if old is not None and _report_status_rank(str(old.get("Status") or "")) > _report_status_rank(str(row.get("Status") or "")):
            # Never downgrade a fetched/saved course to discovered-pending or blocked.
            continue
        if key not in by_key:
            order.append(key)
        by_key[key] = {h: row.get(h, "") for h in headers}

    merged = [by_key[k] for k in order if k in by_key]
    merged.sort(key=lambda r: (str(r.get("Published Date") or ""), str(r.get("Course / Post Title") or "")), reverse=True)
    return headers, merged


def write_outputs_merged(out_dir: Path, pages: list[PageRecord], links: list[LinkRecord]) -> None:
    reports_dir = Path(out_dir) / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    headers, rows = merge_report_rows(out_dir, pages, links)
    write_csv(reports_dir / "course_report.csv", headers, rows)
    write_xlsx_report(reports_dir / "course_report.xlsx", headers, rows)


def safe_write_outputs_merged(out_dir: Path, pages: list[PageRecord], links: list[LinkRecord],
                              log_path: Path | None = None, error_log_path: Path | None = None) -> bool:
    try:
        write_outputs_merged(out_dir, pages, links)
        return True
    except Exception:
        tb = traceback.format_exc()
        if error_log_path is None:
            error_log_path = Path(out_dir) / "logs" / "report_errors.log"
        try:
            error_log_path.parent.mkdir(parents=True, exist_ok=True)
            with error_log_path.open("a", encoding="utf-8") as f:
                f.write(f"\n[{datetime.now().isoformat(timespec='seconds')}] Rolling report generation failed\n{tb}\n")
        except Exception:
            pass
        if log_path:
            try:
                log_line(log_path, f"Rolling report generation warning: {tb.strip().splitlines()[-1] if tb.strip() else 'unknown error'}")
            except Exception:
                pass
        return False


def rolling_checkpoint_signature(base_url: str, overall_from: date | None, overall_to: date, months: int, limit: int, max_pages: int) -> dict:
    return {
        "base_url": (base_url or "https://downloadlynet.ir/").rstrip("/") + "/",
        "overall_from": overall_from.isoformat() if overall_from else "",
        "overall_to": overall_to.isoformat(),
        "months": int(months),
        "limit": int(limit),
        "max_pages": int(max_pages),
    }


def read_rolling_checkpoint(out_dir: Path, signature: dict) -> dict | None:
    path = Path(out_dir) / "state" / "rolling_window_checkpoint.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return None
    if not isinstance(data, dict) or data.get("signature") != signature:
        return None
    return data


def write_rolling_checkpoint(out_dir: Path, signature: dict, window_from: date, window_to: date, *, status: str = "in_progress") -> None:
    atomic_write_json(Path(out_dir) / "state" / "rolling_window_checkpoint.json", {
        "version": 1, "signature": signature, "status": status,
        "window_from": window_from.isoformat(), "window_to": window_to.isoformat(),
        "updated_at": datetime.now().isoformat(timespec="seconds"),
    })


def clear_rolling_checkpoint(out_dir: Path) -> None:
    try:
        (Path(out_dir) / "state" / "rolling_window_checkpoint.json").unlink(missing_ok=True)
    except OSError:
        pass


def _rows_in_window(rows: list[dict], window_from: date, window_to: date, limit: int = 0) -> list[dict]:
    selected: list[dict] = []
    seen: set[str] = set()
    for row in rows:
        url = str(row.get("url") or "")
        key = canonical_parent_key(url)
        if not url or key in seen:
            continue
        d = parse_downloadly_url_date(url)
        if d is None or d < window_from or d > window_to:
            continue
        seen.add(key)
        selected.append(dict(row))
        if limit > 0 and len(selected) >= limit:
            break
    return selected


def _process_rolling_targets(*, targets: list[tuple[str, Path | None, str]], args, out_dir: Path, archive_root: Path,
                             progress_file: Path, log_file: Path, report_error_log: Path, cancel_file: Path,
                             state: dict) -> tuple[int, int, bool]:
    """Fetch one rolling window with buffered report writes and block retry.

    Returns (completed_count, links_count, cancelled). Blocked course requests are
    requeued after the configured wait and a full HTTP-session rotation.
    """
    pending = list(targets)
    total = len(pending)
    completed = 0
    links_found = 0
    buffer_pages: list[PageRecord] = []
    buffer_links: list[LinkRecord] = []
    completed_since_flush = 0
    last_flush = time.monotonic()

    def flush_buffer(reason: str) -> None:
        nonlocal buffer_pages, buffer_links, completed_since_flush, last_flush
        if not buffer_pages and not buffer_links:
            return
        state["status"] = "maintenance"
        state["message"] = reason
        safe_write_progress_json(progress_file, state, log_file)
        safe_write_outputs_merged(out_dir, buffer_pages, buffer_links, log_file, report_error_log)
        buffer_pages = []
        buffer_links = []
        completed_since_flush = 0
        last_flush = time.monotonic()
        state["status"] = "running"
        state["message"] = "Resumed automatically"
        safe_write_progress_json(progress_file, state, log_file)

    def task(item):
        url, _archive_dir, preferred_title = item
        page, links, reused = fetch_archive_extract_one(
            url, archive_root=archive_root, mode=args.mode, timeout=args.page_timeout,
            wait_seconds=args.wait, refresh=args.refresh, headless_browser=args.headless_browser,
            preferred_title=preferred_title,
        )
        return item, page, links, reused

    while pending and not cancel_requested(cancel_file):
        cycle_queue = list(pending)
        pending = []
        blocked_items: list[tuple[str, Path | None, str]] = []
        block_seen = False
        active = {}
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            while cycle_queue and len(active) < args.workers:
                item = cycle_queue.pop(0)
                active[executor.submit(task, item)] = item
            while active:
                future = next(as_completed(list(active.keys())))
                item = active.pop(future)
                url = item[0]
                try:
                    _item, page, links, reused = future.result()
                except Exception as exc:
                    page = PageRecord(
                        parent_title=item[2] or fallback_title_from_url(url), requested_url=url,
                        url_date=(parse_downloadly_url_date(url).isoformat() if parse_downloadly_url_date(url) else ""),
                        mode=args.mode, fetch_status="error", http_status="", final_url="", saved_html="",
                        dynamic_fragment=fragment_from_url(url), extracted_links=0,
                        title_source="discovery" if item[2] else "url_fallback", error=str(exc),
                    )
                    links = []
                    reused = False

                if page.fetch_status == "blocked":
                    block_seen = True
                    blocked_items.append(item)
                    state["blocked"] = int(state.get("blocked", 0) or 0) + 1
                    state["current"] = page.parent_title
                    log_line(log_file, f"Course request blocked; will retry after pause: {page.requested_url}")
                else:
                    completed += 1
                    links_found += len(links)
                    state["completed"] = int(state.get("completed", 0) or 0) + 1
                    state["links_found"] = int(state.get("links_found", 0) or 0) + len(links)
                    state["current"] = page.parent_title
                    if reused:
                        state["reused"] = int(state.get("reused", 0) or 0) + 1
                    if page.fetch_status in {"error", "http_error"}:
                        state["failed"] = int(state.get("failed", 0) or 0) + 1
                    buffer_pages.append(page)
                    buffer_links.extend(links)
                    completed_since_flush += 1
                    log_line(log_file, f"Window {completed}/{total} | {page.fetch_status} | links={len(links)} | {page.parent_title}")

                if report_flush_due(
                    completed_since_flush, now=time.monotonic(), last_flush=last_flush,
                    buffer_courses=args.report_buffer_courses, flush_seconds=args.report_flush_seconds,
                ):
                    flush_buffer(f"Report buffer flush: {completed_since_flush} HTML course(s)")

                state["message"] = "Site block detected; finishing active requests before pause" if block_seen else "Processing rolling window"
                safe_write_progress_json(progress_file, state, log_file)

                if not block_seen and not cancel_requested(cancel_file) and cycle_queue:
                    nxt = cycle_queue.pop(0)
                    active[executor.submit(task, nxt)] = nxt

        # Unscheduled items and blocked items are retried after the same durable flush.
        pending = blocked_items + cycle_queue
        flush_buffer("Saving buffered HTML results before pause")
        if cancel_requested(cancel_file):
            break
        if block_seen:
            state["status"] = "paused_blocked"
            state["message"] = f"Course-page block detected. Reports saved; retrying {len(pending)} pending course(s) in {args.blocked_retry_seconds}s."
            safe_write_progress_json(progress_file, state, log_file)
            if not wait_for_block_retry(args.blocked_retry_seconds, cancel_file, state, progress_file, log_file):
                break
            rotate_http_sessions()
            try:
                if COOKIE_SNAPSHOT_PATH:
                    COOKIE_SNAPSHOT_PATH.unlink(missing_ok=True)
            except OSError:
                pass
            state["status"] = "running"
            state["message"] = "Fresh offline HTTP session created; retrying blocked course"
            safe_write_progress_json(progress_file, state, log_file)

    flush_buffer("Final report-buffer flush for this two-month window")
    return completed, links_found, cancel_requested(cancel_file)


def run_rolling_mode(args, *, out_dir: Path, archive_root: Path, progress_file: Path, log_file: Path,
                     report_error_log: Path, cancel_file: Path, date_from: date | None, date_to: date | None) -> int:
    """Process Downloadly newest-to-oldest in calendar windows, fetching each window before continuing."""
    overall_to = date_to or date.today()
    overall_from = date_from
    months = max(1, int(args.rolling_months or 2))
    rolling_sig = rolling_checkpoint_signature(args.discover_base_url, overall_from, overall_to, months, args.limit, args.discovery_pages)
    rolling_cp = read_rolling_checkpoint(out_dir, rolling_sig)
    if rolling_cp:
        try:
            window_from = parse_cli_date(str(rolling_cp.get("window_from") or ""), "rolling window from")
            window_to = parse_cli_date(str(rolling_cp.get("window_to") or ""), "rolling window to")
        except SystemExit:
            window_from, window_to = current_two_month_window(overall_to, overall_from, months_per_window=months)
    else:
        window_from, window_to = current_two_month_window(overall_to, overall_from, months_per_window=months)

    discovery_sig = discovery_checkpoint_signature(args.discover_base_url, overall_from, overall_to, args.limit, args.discovery_pages)
    checkpoint = read_discovery_checkpoint(out_dir, discovery_sig)
    all_rows = [dict(r) for r in (checkpoint.get("rows", []) if checkpoint else []) if isinstance(r, dict)]
    resume_page = max(1, int(checkpoint.get("next_batch") or 1)) if checkpoint else 1
    total_completed = 0
    total_links = 0
    window_index = 0

    state = {
        "status": "rolling", "operation": "fetch", "source": "discover", "mode": args.mode,
        "workers": args.workers, "total": len(all_rows), "completed": 0, "failed": 0, "blocked": 0,
        "reused": 0, "links_found": 0, "current": args.discover_base_url,
        "started_at": datetime.now().isoformat(timespec="seconds"), "message": "Starting rolling two-month mode",
    }
    safe_write_progress_json(progress_file, state, log_file)

    while window_from is not None and window_to is not None:
        window_index += 1
        if cancel_requested(cancel_file):
            state.update(status="cancelled", message="Stopped by user; rolling checkpoint preserved", finished_at=datetime.now().isoformat(timespec="seconds"))
            safe_write_progress_json(progress_file, state, log_file)
            return 3
        write_rolling_checkpoint(out_dir, rolling_sig, window_from, window_to, status="in_progress")
        state.update(
            status="discovering",
            current=f"{window_from.isoformat()} to {window_to.isoformat()}",
            message=f"Rolling window {window_index}: discovering {window_from.isoformat()} to {window_to.isoformat()}",
        )
        safe_write_progress_json(progress_file, state, log_file)
        log_line(log_file, state["message"])

        batch_completed_this_call = False
        selected_rows: list[dict] = []

        def progress(page_no, found, listing_url, message):
            state["current"] = listing_url
            state["total"] = len(all_rows) + found
            state["message"] = f"Window {window_from}..{window_to} | batch {page_no}: {message}; window courses={found}"
            safe_write_progress_json(progress_file, state, log_file)
            log_line(log_file, state["message"])

        def batch_done(page_no, rows, next_page):
            nonlocal all_rows, resume_page, batch_completed_this_call
            batch_completed_this_call = True
            all_rows = [dict(r) for r in rows]
            resume_page = max(1, int(next_page or page_no + 1))
            write_discovery_checkpoint(out_dir, discovery_sig, page_no, resume_page, all_rows)

        while True:
            try:
                selected_rows = discover_downloadly_courses(
                    session=get_http_session(), base_url=args.discover_base_url, timeout=args.page_timeout,
                    max_pages=args.discovery_pages, date_from=window_from, date_to=window_to, limit=0,
                    progress_callback=progress, initial_rows=all_rows, start_page=resume_page,
                    batch_complete_callback=batch_done, maintenance_seconds=0,
                    cancel_callback=lambda: cancel_requested(cancel_file),
                    stop_when_older_than=window_from,
                )
                checkpoint = read_discovery_checkpoint(out_dir, discovery_sig)
                if checkpoint:
                    all_rows = [dict(r) for r in checkpoint.get("rows", []) if isinstance(r, dict)]
                    resume_page = max(1, int(checkpoint.get("next_batch") or resume_page))
                break
            except DiscoveryCancelledError:
                state.update(status="cancelled", message=f"Stopped by user. Saved {len(all_rows)} discovered course(s).", finished_at=datetime.now().isoformat(timespec="seconds"))
                safe_write_progress_json(progress_file, state, log_file)
                return 3
            except DiscoveryBlockedError as exc:
                checkpoint = read_discovery_checkpoint(out_dir, discovery_sig)
                if checkpoint:
                    all_rows = [dict(r) for r in checkpoint.get("rows", []) if isinstance(r, dict)]
                    resume_page = max(1, int(checkpoint.get("next_batch") or resume_page))
                pending_pages = discovery_rows_to_pending_pages(_rows_in_window(all_rows, window_from, window_to))
                if pending_pages:
                    safe_write_outputs_merged(out_dir, pending_pages, [], log_file, report_error_log)
                state.update(
                    status="paused_blocked", blocked=int(state.get("blocked", 0) or 0) + 1, current=exc.url,
                    message=f"Blocked during {window_from}..{window_to}. Checkpoint/report saved; retrying batch {resume_page} in {args.blocked_retry_seconds}s.",
                )
                safe_write_progress_json(progress_file, state, log_file)
                log_line(log_file, state["message"])
                if not wait_for_block_retry(args.blocked_retry_seconds, cancel_file, state, progress_file, log_file):
                    state.update(status="cancelled", message="Stopped by user while paused after site block", finished_at=datetime.now().isoformat(timespec="seconds"))
                    safe_write_progress_json(progress_file, state, log_file)
                    return 3
                rotate_http_sessions()
                try:
                    if COOKIE_SNAPSHOT_PATH:
                        COOKIE_SNAPSHOT_PATH.unlink(missing_ok=True)
                except OSError:
                    pass
                state.update(status="discovering", message=f"Fresh HTTP session; retrying rolling window from batch {resume_page}")
                safe_write_progress_json(progress_file, state, log_file)

        # Include spillover rows already discovered in earlier calls; de-duplicate by URL.
        selected_rows = _rows_in_window(all_rows, window_from, window_to)
        if args.limit > 0:
            remaining = max(0, int(args.limit) - total_completed)
            selected_rows = selected_rows[:remaining] if remaining else []

        # Put discovered rows into the report immediately, but merge logic never downgrades already fetched rows.
        if selected_rows:
            safe_write_outputs_merged(out_dir, discovery_rows_to_pending_pages(selected_rows), [], log_file, report_error_log)

        targets = [(r["url"], None, r.get("title", "")) for r in selected_rows]
        state.update(
            status="running", total=len(targets), completed=0, current=f"{window_from} to {window_to}",
            message=f"Processing {len(targets)} course page(s) for rolling window {window_from}..{window_to}",
        )
        safe_write_progress_json(progress_file, state, log_file)
        if targets:
            completed, links_count, cancelled = _process_rolling_targets(
                targets=targets, args=args, out_dir=out_dir, archive_root=archive_root,
                progress_file=progress_file, log_file=log_file, report_error_log=report_error_log,
                cancel_file=cancel_file, state=state,
            )
            total_completed += completed
            total_links += links_count
            if cancelled:
                state.update(status="cancelled", message="Stopped by user; HTML/report/checkpoints preserved", finished_at=datetime.now().isoformat(timespec="seconds"))
                safe_write_progress_json(progress_file, state, log_file)
                return 3

        # Window boundary is a durable commit point: history, report, then a fresh cookie/session jar.
        if all_rows:
            update_discovery_history(out_dir, all_rows)
        write_rolling_checkpoint(out_dir, rolling_sig, window_from, window_to, status="completed")
        state.update(status="maintenance", message=f"Two-month window complete. Reports saved; clearing app cookies/session before next window.")
        safe_write_progress_json(progress_file, state, log_file)
        log_line(log_file, f"Rolling window complete: {window_from}..{window_to}; courses={len(targets)}. Rotating HTTP sessions/cookies.")
        rotate_http_sessions()
        try:
            if COOKIE_SNAPSHOT_PATH:
                COOKIE_SNAPSHOT_PATH.unlink(missing_ok=True)
        except OSError:
            pass

        if args.limit > 0 and total_completed >= args.limit:
            break

        next_from, next_to = previous_two_month_window(window_from, overall_from, months_per_window=months)
        if next_from is None or next_to is None:
            break

        # If discovery did not execute any new batch and this window had no rows,
        # the listing is exhausted; there is nothing older to process.
        if not batch_completed_this_call and not selected_rows:
            break

        window_from, window_to = next_from, next_to
        write_rolling_checkpoint(out_dir, rolling_sig, window_from, window_to, status="in_progress")

    clear_rolling_checkpoint(out_dir)
    clear_discovery_checkpoint(out_dir)
    state.update(
        status="completed", total=total_completed, completed=total_completed, links_found=total_links,
        message="Rolling two-month processing finished", finished_at=datetime.now().isoformat(timespec="seconds"),
    )
    safe_write_progress_json(progress_file, state, log_file)
    log_line(log_file, f"Rolling run completed: courses={total_completed}, links={total_links}")
    return 0


def build_driver(page_timeout: int, headless: bool = False):
    try:
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
    except ImportError:
        raise RuntimeError("Browser mode requires Selenium. Install with: python -m pip install selenium")
    opts = Options()
    opts.add_argument("--disable-popup-blocking")
    opts.add_argument("--disable-notifications")
    opts.add_argument("--window-size=1440,1100")
    if headless:
        opts.add_argument("--headless=new")
    opts.add_experimental_option("prefs", {
        "download.prompt_for_download": True,
        "download_restrictions": 3,
        "profile.default_content_setting_values.automatic_downloads": 2,
    })
    driver = webdriver.Chrome(options=opts)
    driver.set_page_load_timeout(page_timeout)
    return driver


def main() -> int:
    global COOKIE_SNAPSHOT_PATH, CLEAR_SITE_COOKIES_ON_NEW_SESSION
    ap = argparse.ArgumentParser(description="Downloadly V21 rolling two-month discovery + cyclic retry + persistent HTML archive + one-row course report")
    ap.add_argument("--input", default=str(DEFAULT_INPUT))
    ap.add_argument("--output-dir", default=str(DEFAULT_OUTPUT))
    ap.add_argument("--operation", choices=("fetch", "extract-saved"), default="fetch")
    ap.add_argument("--source", choices=("discover", "file"), default="discover", help="For fetch mode: auto-discover courses or use --input URL file")
    ap.add_argument("--discover-base-url", default="https://downloadlynet.ir/")
    ap.add_argument("--discovery-pages", type=int, default=0, help="0 = scan all Load More/listing batches")
    ap.add_argument("--discovery-run", choices=("rolling", "full", "incremental"), default="rolling", help="Rolling two-month processing, full discovery, or incremental new-page checks")
    ap.add_argument("--incremental-known-pages", type=int, default=2, help="Incremental mode stops after this many consecutive known-only listing pages")
    ap.add_argument("--mode", choices=("offline", "browser"), default="offline")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--wait", type=float, default=4.0)
    ap.add_argument("--page-timeout", type=int, default=30)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--date-from", default="")
    ap.add_argument("--date-to", default="")
    ap.add_argument("--last-days", type=int, default=0)
    ap.add_argument("--refresh", action="store_true", help="Re-fetch even when archived HTML exists")
    ap.add_argument("--headless-browser", action="store_true")
    ap.add_argument("--progress-file", default="")
    ap.add_argument("--crash-log", default="")
    ap.add_argument("--log-file", default="")
    ap.add_argument("--cancel-file", default="")
    ap.add_argument("--cookie-state-file", default="", help="Non-sensitive metadata snapshot for this tool's Downloadly cookies")
    ap.add_argument("--clear-site-cookies", action="store_true", help="Clear this tool's Downloadly HTTP cookies before the run")
    ap.add_argument("--maintenance-seconds", type=int, default=180, help="Pause between requests to checkpoint/update reports every N seconds; 0 disables")
    ap.add_argument("--blocked-retry-seconds", type=int, default=180, help="When discovery is blocked, stay alive and retry the same checkpoint after N seconds; 0 retries immediately")
    ap.add_argument("--rolling-months", type=int, default=2, help="Calendar months per rolling discovery/fetch window")
    ap.add_argument("--report-buffer-courses", type=int, default=10, help="Update CSV/XLSX after this many newly archived course pages; 0 disables count trigger")
    ap.add_argument("--report-flush-seconds", type=int, default=60, help="Also update CSV/XLSX after this many seconds when buffered HTML exists; 0 disables time trigger")
    args = ap.parse_args()

    if (args.limit < 0 or args.last_days < 0 or args.discovery_pages < 0 or args.incremental_known_pages < 1
            or args.maintenance_seconds < 0 or args.blocked_retry_seconds < 0 or args.rolling_months < 1
            or args.report_buffer_courses < 0 or args.report_flush_seconds < 0):
        return 2
    if args.workers < 1:
        args.workers = 1
    args.workers = min(args.workers, 8 if args.mode == "offline" or args.operation == "extract-saved" else 3)

    out_dir = Path(args.output_dir).resolve()
    archive_root = out_dir / "html_archive"
    state_dir = out_dir / "state"
    logs_dir = out_dir / "logs"
    reports_dir = out_dir / "reports"
    out_dir.mkdir(parents=True, exist_ok=True)
    archive_root.mkdir(parents=True, exist_ok=True)
    state_dir.mkdir(parents=True, exist_ok=True)
    logs_dir.mkdir(parents=True, exist_ok=True)
    reports_dir.mkdir(parents=True, exist_ok=True)
    progress_file = Path(args.progress_file).resolve() if args.progress_file else state_dir / "run_progress.json"
    log_file = Path(args.log_file).resolve() if args.log_file else logs_dir / "run.log"
    report_error_log = logs_dir / "report_errors.log"
    cancel_file = Path(args.cancel_file).resolve() if args.cancel_file else state_dir / "cancel.requested"
    COOKIE_SNAPSHOT_PATH = Path(args.cookie_state_file).resolve() if args.cookie_state_file else state_dir / "downloadly_cookie_snapshot.json"
    CLEAR_SITE_COOKIES_ON_NEW_SESSION = bool(args.clear_site_cookies)
    if args.clear_site_cookies:
        try:
            COOKIE_SNAPSHOT_PATH.unlink(missing_ok=True)
        except OSError:
            pass
    try:
        cancel_file.unlink(missing_ok=True)
    except Exception:
        pass
    try:
        log_file.unlink(missing_ok=True)
    except Exception:
        pass

    date_from = parse_cli_date(args.date_from, "--date-from")
    date_to = parse_cli_date(args.date_to, "--date-to")
    if args.last_days > 0:
        today = date.today()
        date_from = today - timedelta(days=args.last_days - 1)
        date_to = today
    if date_from and date_to and date_from > date_to:
        log_line(log_file, "Invalid date range: from date is after to date")
        return 2

    if args.operation == "fetch" and args.source == "discover" and args.discovery_run == "rolling":
        return run_rolling_mode(
            args, out_dir=out_dir, archive_root=archive_root, progress_file=progress_file, log_file=log_file,
            report_error_log=report_error_log, cancel_file=cancel_file, date_from=date_from, date_to=date_to,
        )

    targets: list[tuple[str, Path | None, str]] = []
    discovery_rows: list[dict] = []
    if args.operation == "fetch" and args.source == "discover":
        discovery_state = {
            "status": "discovering", "operation": args.operation, "source": args.source, "mode": args.mode,
            "workers": args.workers, "total": 0, "completed": 0, "failed": 0,
            "blocked": 0, "reused": 0, "links_found": 0, "current": args.discover_base_url,
            "started_at": datetime.now().isoformat(timespec="seconds"), "message": "Discovering course/title pages"
        }
        safe_write_progress_json(progress_file, discovery_state, log_file)
        log_line(log_file, f"Automatic discovery started at {args.discover_base_url}")

        def discovery_progress(page_no, found, listing_url, message):
            discovery_state["current"] = listing_url
            discovery_state["total"] = found
            discovery_state["message"] = f"Listing page {page_no}: {message}; courses selected={found}"
            safe_write_progress_json(progress_file, discovery_state, log_file)
            log_line(log_file, discovery_state["message"])

        requested_incremental = (args.discovery_run == "incremental")
        known_urls = load_known_course_urls(out_dir) if requested_incremental else set()
        effective_incremental = requested_incremental and bool(known_urls)
        if requested_incremental and not known_urls:
            log_line(log_file, "Incremental discovery requested but no prior discovery/archive history exists; falling back to a full discovery run")
        elif effective_incremental:
            log_line(log_file, f"Incremental discovery: {len(known_urls)} known course URL(s); stop after {args.incremental_known_pages} known-only listing page(s)")
        scanned_rows: list[dict] = []
        initial_rows: list[dict] = []
        resume_page = 1
        checkpoint_sig = discovery_checkpoint_signature(
            args.discover_base_url, date_from, date_to, args.limit, args.discovery_pages
        )
        if not effective_incremental:
            checkpoint = read_discovery_checkpoint(out_dir, checkpoint_sig)
            if checkpoint:
                initial_rows = [dict(r) for r in checkpoint.get("rows", []) if isinstance(r, dict)]
                scanned_rows.extend(initial_rows)
                resume_page = max(1, int(checkpoint.get("next_batch") or 1))
                log_line(log_file, f"Resuming interrupted full discovery from batch {resume_page}; checkpoint has {len(initial_rows)} course(s)")

        def discovery_batch_complete(page_no, rows, next_page):
            if effective_incremental:
                return
            try:
                write_discovery_checkpoint(out_dir, checkpoint_sig, page_no, next_page, rows)
            except OSError as exc:
                log_line(log_file, f"Discovery checkpoint write skipped after retries: {exc}")

        def discovery_maintenance(page_no, rows, next_page):
            # This runs only between listing requests, so discovery is effectively paused while state/report files flush.
            discovery_state.update(
                status='maintenance', total=len(rows), current=f'Completed listing batch {page_no}',
                message=f'3-minute maintenance pause: saving checkpoint and updating CSV/Excel ({len(rows)} discovered courses)'
            )
            safe_write_progress_json(progress_file, discovery_state, log_file)
            if not effective_incremental:
                write_discovery_checkpoint(out_dir, checkpoint_sig, page_no, next_page, rows)
            if rows:
                update_discovery_history(out_dir, rows)
                safe_write_outputs(out_dir, discovery_rows_to_pending_pages(rows), [], log_file, report_error_log)
            log_line(log_file, f"Maintenance checkpoint complete after batch {page_no}; courses={len(rows)}. Resuming automatically.")
            discovery_state.update(status='discovering', message=f'Maintenance complete; resuming at batch {next_page}')
            safe_write_progress_json(progress_file, discovery_state, log_file)

        # Stay in the same worker process if the site temporarily blocks discovery.
        while True:
            try:
                discovery_rows = discover_downloadly_courses(
                    session=get_http_session(), base_url=args.discover_base_url, timeout=args.page_timeout,
                    max_pages=args.discovery_pages, date_from=date_from, date_to=date_to, limit=args.limit,
                    progress_callback=discovery_progress, known_urls=known_urls, incremental=effective_incremental,
                    stop_after_known_pages=args.incremental_known_pages, all_discovered_callback=scanned_rows.append,
                    initial_rows=initial_rows, start_page=resume_page, batch_complete_callback=discovery_batch_complete,
                    maintenance_seconds=args.maintenance_seconds, maintenance_callback=discovery_maintenance,
                    cancel_callback=lambda: cancel_requested(cancel_file),
                )
                break
            except DiscoveryCancelledError:
                checkpoint = read_discovery_checkpoint(out_dir, checkpoint_sig) if not effective_incremental else None
                recovery_rows = [dict(r) for r in (checkpoint.get('rows', []) if checkpoint else scanned_rows) if isinstance(r, dict)]
                if recovery_rows:
                    safe_write_outputs(out_dir, discovery_rows_to_pending_pages(recovery_rows), [], log_file, report_error_log)
                discovery_state.update(
                    status='cancelled', total=len(recovery_rows),
                    message=f'Stopped by user. Checkpoint preserved with {len(recovery_rows)} discovered course(s).',
                    finished_at=datetime.now().isoformat(timespec='seconds'),
                )
                safe_write_progress_json(progress_file, discovery_state, log_file)
                log_line(log_file, discovery_state['message'])
                return 3
            except DiscoveryBlockedError as exc:
                status = 'unknown' if exc.status_code is None else str(exc.status_code)
                checkpoint = read_discovery_checkpoint(out_dir, checkpoint_sig) if not effective_incremental else None
                recovery_rows = [dict(r) for r in (checkpoint.get('rows', []) if checkpoint else scanned_rows) if isinstance(r, dict)]
                retry_page = max(1, int(checkpoint.get('next_batch') or 1)) if checkpoint else resume_page
                if recovery_rows:
                    # Preserve useful progress in the only user-facing CSV/XLSX while waiting.
                    update_discovery_history(out_dir, recovery_rows)
                    safe_write_outputs(out_dir, discovery_rows_to_pending_pages(recovery_rows), [], log_file, report_error_log)
                discovery_state.update(
                    status='paused_blocked',
                    total=len(recovery_rows),
                    blocked=max(1, int(discovery_state.get('blocked', 0) or 0)),
                    current=exc.url,
                    message=f'Downloadly blocked discovery (HTTP {status}). Saved {len(recovery_rows)} courses; retrying batch {retry_page} automatically in {args.blocked_retry_seconds}s.',
                )
                safe_write_progress_json(progress_file, discovery_state, log_file)
                log_line(log_file, discovery_state['message'])
                if not wait_for_block_retry(args.blocked_retry_seconds, cancel_file, discovery_state, progress_file, log_file):
                    discovery_state.update(status='cancelled', message='Stopped by user while paused after site block', finished_at=datetime.now().isoformat(timespec='seconds'))
                    safe_write_progress_json(progress_file, discovery_state, log_file)
                    return 3
                reset_http_session()
                checkpoint = read_discovery_checkpoint(out_dir, checkpoint_sig) if not effective_incremental else None
                if checkpoint:
                    initial_rows = [dict(r) for r in checkpoint.get('rows', []) if isinstance(r, dict)]
                    scanned_rows = list(initial_rows)
                    resume_page = max(1, int(checkpoint.get('next_batch') or 1))
                else:
                    initial_rows = list(recovery_rows)
                    scanned_rows = list(recovery_rows)
                    resume_page = retry_page
                discovery_state.update(status='discovering', message=f'Automatic offline retry: resuming from batch {resume_page}')
                safe_write_progress_json(progress_file, discovery_state, log_file)
                log_line(log_file, discovery_state['message'])
        if scanned_rows:
            update_discovery_history(out_dir, scanned_rows)
        write_discovery_snapshot(out_dir, discovery_rows)
        if not effective_incremental:
            clear_discovery_checkpoint(out_dir)
        targets = [(r["url"], None, r.get("title", "")) for r in discovery_rows]
        kind = "new" if effective_incremental else "matching"
        # Keep the report useful immediately: all discovered rows appear as pending until fetched.
        safe_write_outputs(out_dir, discovery_rows_to_pending_pages(discovery_rows), [], log_file, report_error_log)
        log_line(log_file, f"Automatic discovery selected {len(targets)} {kind} course(s)")
    elif args.operation == "fetch":
        input_path = Path(args.input).resolve()
        if not input_path.exists():
            log_line(log_file, f"Input file not found: {input_path}")
            return 2
        urls = select_urls(read_urls(input_path), date_from=date_from, date_to=date_to, limit=args.limit)
        targets = [(u, None, "") for u in urls]
    else:
        saved = scan_archive(archive_root)
        urls = [u for u, _ in saved]
        chosen = set(select_urls(urls, date_from=date_from, date_to=date_to, limit=args.limit))
        targets = [(u, p, "") for u, p in saved if u in chosen]

    total = len(targets)
    target_order = {url: i for i, (url, _, _) in enumerate(targets)}
    state = {
        "status": "running", "operation": args.operation, "source": (args.source if args.operation == "fetch" else "saved"), "mode": args.mode,
        "workers": args.workers, "total": total, "completed": 0, "failed": 0,
        "blocked": 0, "reused": 0, "links_found": 0, "current": "",
        "started_at": datetime.now().isoformat(timespec="seconds"), "message": "Starting"
    }
    safe_write_progress_json(progress_file, state, log_file)
    log_line(log_file, f"Selected {total} course(s); operation={args.operation}; mode={args.mode}; workers={args.workers}")

    pages: list[PageRecord] = []
    all_links: list[LinkRecord] = []
    next_report_maintenance = time.monotonic() + max(1, args.maintenance_seconds) if args.maintenance_seconds > 0 else float("inf")

    def ordered_pages() -> list[PageRecord]:
        return sorted(pages, key=lambda p: target_order.get(p.requested_url, 10**9))

    def pages_with_pending() -> list[PageRecord]:
        processed = {canonical_parent_key(p.requested_url): p for p in pages}
        combined: list[PageRecord] = []
        for url, _archive_dir, preferred_title in targets:
            key = canonical_parent_key(url)
            if key in processed:
                combined.append(processed[key])
            else:
                d = parse_downloadly_url_date(url)
                combined.append(PageRecord(
                    parent_title=preferred_title or fallback_title_from_url(url), requested_url=url,
                    url_date=d.isoformat() if d else "", mode="discovery", fetch_status="discovered_pending",
                    http_status="", final_url="", saved_html="", dynamic_fragment=fragment_from_url(url),
                    extracted_links=0, title_source="discovery", error="",
                ))
        return combined
    if total == 0:
        report_ok = safe_write_outputs(out_dir, pages, all_links, log_file, report_error_log)
        state.update(
            status="completed" if report_ok else "completed_with_warnings",
            message="No matching courses" if report_ok else "No matching courses; report generation warning - see logs/report_errors.log",
            finished_at=datetime.now().isoformat(timespec="seconds"),
        )
        safe_write_progress_json(progress_file, state, log_file)
        return 0

    def task(item):
        url, archive_dir, preferred_title = item
        if args.operation == "extract-saved":
            page, links = extract_course_from_archive(archive_dir)
            return url, page, links, True
        page, links, reused = fetch_archive_extract_one(
            url, archive_root=archive_root, mode=args.mode, timeout=args.page_timeout,
            wait_seconds=args.wait, refresh=args.refresh, headless_browser=args.headless_browser,
            preferred_title=preferred_title,
        )
        return url, page, links, reused

    # Bounded scheduling: only workers tasks are active; stop requests prevent new work.
    pending_items = list(targets)
    active = {}
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        while pending_items and len(active) < args.workers and not cancel_requested(cancel_file):
            item = pending_items.pop(0)
            active[executor.submit(task, item)] = item
        while active:
            done_future = next(as_completed(list(active.keys())))
            item = active.pop(done_future)
            url = item[0]
            try:
                _, page, links, reused = done_future.result()
                pages.append(page)
                all_links.extend(links)
                state["completed"] += 1
                state["links_found"] += len(links)
                state["current"] = page.parent_title
                if reused:
                    state["reused"] += 1
                if page.fetch_status == "blocked":
                    state["blocked"] += 1
                if page.fetch_status in {"error", "http_error"}:
                    state["failed"] += 1
                log_line(log_file, f"{state['completed']}/{total} | {page.fetch_status} | links={len(links)} | {page.parent_title}")
            except Exception as exc:
                state["completed"] += 1
                state["failed"] += 1
                state["current"] = fallback_title_from_url(url)
                log_line(log_file, f"{state['completed']}/{total} | ERROR | {url} | {exc}")
                pages.append(PageRecord(
                    parent_title=fallback_title_from_url(url), requested_url=url,
                    url_date=(parse_downloadly_url_date(url).isoformat() if parse_downloadly_url_date(url) else ""),
                    mode=args.mode if args.operation == "fetch" else "saved", fetch_status="error",
                    http_status="", final_url="", saved_html="", dynamic_fragment=fragment_from_url(url),
                    extracted_links=0, title_source="url_fallback", error=str(exc),
                ))
            # Every 3 minutes, pause scheduling long enough to flush a durable partial CSV/XLSX.
            now = time.monotonic()
            if now >= next_report_maintenance:
                state["status"] = "maintenance"
                state["message"] = "3-minute maintenance pause: updating CSV/Excel report"
                safe_write_progress_json(progress_file, state, log_file)
                partial_report_ok = safe_write_outputs(out_dir, pages_with_pending(), all_links, log_file, report_error_log)
                state["status"] = "running"
                state["message"] = "Resumed automatically" if partial_report_ok else "Resumed; report write warning - see logs/report_errors.log"
                safe_write_progress_json(progress_file, state, log_file)
                log_line(log_file, f"3-minute report checkpoint complete at {state['completed']}/{total}; resuming automatically")
                next_report_maintenance = time.monotonic() + max(1, args.maintenance_seconds)
            else:
                state["message"] = "Stop requested; finishing active sessions" if cancel_requested(cancel_file) else "Running"
                safe_write_progress_json(progress_file, state, log_file)
            if not cancel_requested(cancel_file) and pending_items:
                nxt = pending_items.pop(0)
                active[executor.submit(task, nxt)] = nxt

    cancelled = cancel_requested(cancel_file)
    state["message"] = "Writing final CSV/Excel reports"
    safe_write_progress_json(progress_file, state, log_file)
    report_ok = safe_write_outputs(out_dir, ordered_pages(), all_links, log_file, report_error_log)
    if cancelled:
        final_status = "cancelled"
        final_message = "Stopped by user" if report_ok else "Stopped by user; report generation warning - see logs/report_errors.log"
    elif report_ok:
        final_status = "completed"
        final_message = "Finished"
    else:
        final_status = "completed_with_warnings"
        final_message = "Extraction finished, but CSV/Excel report generation had an error. See logs/report_errors.log"
    state.update(
        status=final_status,
        message=final_message,
        finished_at=datetime.now().isoformat(timespec="seconds"),
    )
    safe_write_progress_json(progress_file, state, log_file)
    log_line(log_file, f"Run {state['status']}: courses={len(pages)}, links={len(all_links)}, archived at {archive_root}")
    return 0 if not cancelled else 3


def _argv_value(flag: str) -> str:
    try:
        i = sys.argv.index(flag)
        return sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
    except ValueError:
        return ""


def _record_unhandled_crash() -> None:
    tb = traceback.format_exc()
    crash_value = _argv_value("--crash-log")
    if crash_value:
        crash_path = Path(crash_value).resolve()
    else:
        crash_path = DEFAULT_OUTPUT / "logs" / "worker_crash.log"
    try:
        crash_path.parent.mkdir(parents=True, exist_ok=True)
        with crash_path.open("a", encoding="utf-8") as f:
            f.write(f"\n[{datetime.now().isoformat(timespec='seconds')}] Unhandled worker exception\n{tb}\n")
    except Exception:
        pass
    progress_value = _argv_value("--progress-file")
    if progress_value:
        progress_path = Path(progress_value).resolve()
        payload = {}
        try:
            if progress_path.exists():
                payload = json.loads(progress_path.read_text(encoding="utf-8"))
        except Exception:
            payload = {}
        payload.update(
            status="crashed",
            message=f"Worker crashed unexpectedly. See {crash_path.name}",
            finished_at=datetime.now().isoformat(timespec="seconds"),
        )
        safe_write_progress_json(progress_path, payload)
    try:
        print(tb, file=sys.stderr, flush=True)
    except Exception:
        pass


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except BaseException:
        _record_unhandled_crash()
        raise SystemExit(99)
