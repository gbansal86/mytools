"""Offline, searchable per-channel HTML export. No network calls or dependencies.

Exports source message text/captions and links to files saved by the downloader.
This is a custom local index, not Telegram Desktop's official HTML export.
"""
from __future__ import annotations

import html
import json
import os
from pathlib import Path
from urllib.parse import quote


# One ChannelArchive instance owns one channel's private local export folder.
# It records messages as JSONL during the scan and renders a searchable HTML
# page only after the scan, so partially-written HTML is not left behind.

class ChannelArchive:
    def __init__(self, root: Path, folder_name: str, channel_title: str, channel_id: int, username: str | None = None):
        self.root = root
        self.directory = root / folder_name
        self.directory.mkdir(parents=True, exist_ok=True)
        self.records = self.directory / "messages.jsonl"
        self.page = self.directory / "index.html"
        self.title = str(channel_title)
        self.channel_id = int(channel_id)
        self.username = str(username or "").lstrip("@")
        self.count = 0
        self._stream = None

    def start(self):
        # A fresh successful scan replaces a previous index; each line is one message.
        self._stream = self.records.open("w", encoding="utf-8", newline="\n")

    def record(self, message, info, target: Path | None):
        if self._stream is None:
            raise RuntimeError("Archive must be started before recording")
        when = getattr(message, "date", None)
        data = {
            "id": int(message.id),
            "date": when.isoformat() if when is not None else "",
            "text": str(getattr(message, "raw_text", "") or ""),
            "type": info[0] if info else ("Photo (not downloaded)" if getattr(message, "photo", None) else "Message"),
            "filename": info[1] if info else "",
            "size_bytes": info[2] if info else 0,
            # Store a relative path so the archive does not expose the Windows user profile.
            "target": os.path.relpath(target, self.directory) if target is not None else "",
        }
        self._stream.write(json.dumps(data, ensure_ascii=False) + "\n")
        self.count += 1
        if self.count % 200 == 0:
            self._stream.flush()

    def close(self):
        if self._stream is not None:
            self._stream.close()
            self._stream = None

    def link_for(self, message_id):
        if self.username:
            # Telegram usernames are letters/digits/underscores; guard against crafted URLs.
            if all(x.isalnum() or x == "_" for x in self.username):
                return f"https://t.me/{self.username}/{message_id}"
        # t.me/c links to private supergroups/channels are accessible only to members.
        if self.channel_id > 0:
            return f"https://t.me/c/{self.channel_id}/{message_id}"
        return ""

    def _local_link(self, target: str, expected_size: int):
        if not target:
            return ""
        path = Path(target)
        if not path.is_absolute():
            path = self.directory / path
        try:
            if not path.is_file():
                return ""
            size = path.stat().st_size
            if not size or (expected_size and size != expected_size):
                return ""
            relative = Path(os.path.relpath(path, self.directory)).parts
            # Percent-encode each path segment; never insert raw filename into HTML.
            return "/".join(quote(part, safe="") for part in relative)
        except (OSError, ValueError):
            return ""

    def render(self):
        """Write via a temporary file so an open browser never sees half a page."""
        self.close()
        if not self.records.exists():
            return
        temp = self.page.with_suffix(".html.tmp")
        with self.records.open("r", encoding="utf-8") as source, temp.open("w", encoding="utf-8", newline="\n") as out:
            out.write('''<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; object-src 'none'; form-action 'none'">
<title>''')
            out.write(html.escape(self.title, quote=True))
            out.write(''' — Channel Archive</title>
<style>
:root{color-scheme:light dark}*{box-sizing:border-box}body{font:15px/1.5 system-ui,Segoe UI,Arial,sans-serif;max-width:1120px;margin:0 auto;padding:26px;background:#111827;color:#f3f4f6}
header{position:sticky;top:0;background:#111827ee;padding:10px 0 18px;z-index:2;backdrop-filter:blur(6px)}h1{font-size:25px;margin:0 0 6px}p{margin:5px 0}.muted{color:#9ca3af}input,select{border:1px solid #4b5563;border-radius:9px;padding:11px;background:#1f2937;color:white;font-size:15px}input{width:min(100%,620px)}.controls{display:flex;gap:10px;flex-wrap:wrap;margin-top:14px}.msg{margin:12px 0;padding:17px;border:1px solid #374151;border-radius:13px;background:#1f2937}.meta{font-size:13px;color:#9ca3af;margin-bottom:9px;display:flex;gap:13px;flex-wrap:wrap}.body{white-space:pre-wrap;overflow-wrap:anywhere;max-height:500px;overflow:auto}.links{margin-top:12px;display:flex;flex-wrap:wrap;gap:12px}a{color:#93c5fd;text-decoration:none}a:hover{text-decoration:underline}.filename{overflow-wrap:anywhere}.pill{display:inline-block;background:#374151;padding:2px 9px;border-radius:99px}.empty{margin-top:18px;color:#fbbf24}
</style></head><body><header><h1>''')
            out.write(html.escape(self.title))
            out.write('''</h1><p class="muted">Offline channel message archive · Times as provided by Telegram (UTC) · Local file links work only on this computer.</p>
<div class="controls"><input type="search" id="search" placeholder="Search messages, captions, filenames, message IDs…" aria-label="Search messages">
<select id="kind"><option value="all">All messages</option><option value="Videos">Videos</option><option value="Documents">Documents</option><option value="Message">Text / other</option><option value="saved">Files saved locally</option></select></div>
<p id="count" class="muted"></p></header><main id="messages">
''')
            count = 0
            saved = 0
            for raw in source:
                if not raw.strip():
                    continue
                try:
                    item = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                count += 1
                message_id = int(item.get("id", 0))
                kind = str(item.get("type", "Message"))
                text = str(item.get("text", ""))
                filename = str(item.get("filename", ""))
                date = str(item.get("date", ""))
                local = self._local_link(str(item.get("target", "")), int(item.get("size_bytes", 0)))
                if local:
                    saved += 1
                origin = self.link_for(message_id)
                searchable = f"{message_id} {date} {kind} {filename} {text}".casefold()
                out.write('<article class="msg" data-kind="')
                out.write(html.escape(kind, quote=True))
                out.write('" data-saved="')
                out.write("yes" if local else "no")
                out.write('" data-search="')
                out.write(html.escape(searchable, quote=True))
                out.write('"><div class="meta"><span>Message #')
                out.write(str(message_id))
                out.write('</span><time>')
                out.write(html.escape(date[:19].replace("T", " ") + " UTC" if date else "Date unavailable"))
                out.write('</time><span class="pill">')
                out.write(html.escape(kind))
                out.write('</span></div>')
                if text:
                    out.write('<div class="body">')
                    out.write(html.escape(text))
                    out.write('</div>')
                if filename:
                    out.write('<p class="filename">📎 ')
                    out.write(html.escape(filename))
                    out.write('</p>')
                out.write('<div class="links">')
                if local:
                    out.write('<a href="' + html.escape(local, quote=True) + '" target="_blank" rel="noopener">Open downloaded file</a>')
                elif filename:
                    out.write('<span class="muted">File not saved locally yet</span>')
                if origin:
                    out.write('<a href="' + html.escape(origin, quote=True) + '" target="_blank" rel="noopener noreferrer">Open Telegram message</a>')
                out.write('</div></article>\n')
            out.write('''</main><p class="empty" id="empty" hidden>No matching messages.</p><script>
const search=document.getElementById('search'),kind=document.getElementById('kind'),nodes=[...document.querySelectorAll('.msg')],counter=document.getElementById('count'),empty=document.getElementById('empty');
function filter(){let q=search.value.toLocaleLowerCase().trim(),k=kind.value,shown=0;for(let n of nodes){let match=(!q||n.dataset.search.includes(q))&&(k==='all'||(k==='saved'&&n.dataset.saved==='yes')||(k==='Message'&&n.dataset.kind!=='Videos'&&n.dataset.kind!=='Documents')||n.dataset.kind===k);n.hidden=!match;if(match)shown++;}counter.textContent=`Showing ${shown.toLocaleString()} of ${nodes.length.toLocaleString()} messages`;empty.hidden=shown!==0;}
search.addEventListener('input',filter);kind.addEventListener('change',filter);filter();
</script></body></html>''')
        temp.replace(self.page)
        return {"messages": count, "saved": saved, "page": self.page, "records": self.records}
