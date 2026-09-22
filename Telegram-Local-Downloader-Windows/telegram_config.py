"""Configuration and channel-input helpers for the downloader."""

import getpass
import json
import os
import re
from pathlib import Path

from telethon.errors import RPCError

ROOT = Path(__file__).resolve().parent
CHANNELS_FILE = ROOT / "channels.txt"
SETTINGS_FILE = ROOT / "telegram_settings.json"
DOWNLOAD_ROOT = ROOT / "downloads"
REPORT_FILE = ROOT / "download_report.csv"
SESSION_PATH = ROOT / "telegram_session"
OPTIONS_FILE = ROOT / "download_options.json"
ARCHIVE_ROOT = ROOT / "channel_exports"
DEFAULT_PARALLEL_DOWNLOADS = 3
MAX_PARALLEL_DOWNLOADS = 4
REPORT_COLUMNS = [
    "channel", "channel_id", "message_id", "file_name",
    "size_bytes", "status", "local_path", "error",
]


def safe_part(text, maximum=135):
    """Make Telegram-controlled text safe to use as a Windows filename part."""
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", str(text)).strip(" .") or "unnamed"
    reserved = {"CON", "PRN", "AUX", "NUL"}
    reserved.update(f"COM{i}" for i in range(1, 10))
    reserved.update(f"LPT{i}" for i in range(1, 10))
    if value.split(".")[0].upper() in reserved:
        value = "_" + value
    return value[:maximum].rstrip(" .") or "unnamed"


def load_options():
    """Read non-secret speed/export options."""
    if not OPTIONS_FILE.exists():
        OPTIONS_FILE.write_text(
            json.dumps({"parallel_downloads": DEFAULT_PARALLEL_DOWNLOADS, "export_html": True}, indent=2) + "\n",
            encoding="utf-8",
        )
    data = json.loads(OPTIONS_FILE.read_text(encoding="utf-8"))
    workers = data.get("parallel_downloads", DEFAULT_PARALLEL_DOWNLOADS)
    if type(workers) is not int or not (1 <= workers <= MAX_PARALLEL_DOWNLOADS):
        raise ValueError(f"download_options.json: parallel_downloads must be 1-{MAX_PARALLEL_DOWNLOADS}")
    export_html = data.get("export_html", True)
    if not isinstance(export_html, bool):
        raise ValueError("download_options.json: export_html must be true or false")
    return workers, export_html


def read_channels():
    """Read one user-provided channel target per line."""
    if not CHANNELS_FILE.exists():
        CHANNELS_FILE.write_text(
            "# One channel per line. Use @username or an exact title already visible to your account.\n"
            "@your_channel_username\n",
            encoding="utf-8",
        )
        raise RuntimeError(f"Edit {CHANNELS_FILE} and run again.")
    values = []
    for line in CHANNELS_FILE.read_text(encoding="utf-8-sig").splitlines():
        item = line.strip()
        if item and not item.startswith("#"):
            if item == "@your_channel_username":
                raise RuntimeError(f"Replace the placeholder channel in {CHANNELS_FILE}.")
            values.append(item)
    if not values:
        raise RuntimeError(f"Add at least one channel to {CHANNELS_FILE}.")
    return list(dict.fromkeys(values))


def get_credentials():
    """Read Telegram developer credentials without writing secrets to disk."""
    saved = json.loads(SETTINGS_FILE.read_text(encoding="utf-8")) if SETTINGS_FILE.exists() else {}
    raw_id = str(os.getenv("TG_API_ID") or saved.get("api_id") or "").strip()
    secret = str(os.getenv("TG_API_HASH") or saved.get("api_hash") or "").strip()
    if not raw_id:
        raw_id = input("Telegram API ID: ").strip()
    if not secret:
        secret = getpass.getpass("Telegram API hash (hidden): ").strip()
    if not raw_id.isdecimal() or not secret:
        raise RuntimeError("Telegram API ID must be numeric and API hash cannot be empty.")
    return int(raw_id), secret


def normalize_channel(raw):
    """Accept a public t.me URL or return the supplied username/title unchanged."""
    value = raw.strip().rstrip("/")
    if value.startswith(("https://t.me/", "http://t.me/", "t.me/")):
        value = value.split("t.me/", 1)[1].split("?", 1)[0].split("/", 1)[0]
    return value


async def resolve_channel(client, raw):
    """Resolve only targets the signed-in account can already access."""
    query = normalize_channel(raw)
    try:
        return await client.get_entity(query)
    except (ValueError, TypeError, RPCError):
        async for dialog in client.iter_dialogs():
            if dialog.name.casefold() == str(query).lstrip("@").casefold():
                return dialog.entity
        raise ValueError(f"Cannot resolve {raw!r}; use @username or the exact title already visible in Telegram.")
