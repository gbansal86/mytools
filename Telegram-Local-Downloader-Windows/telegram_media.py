"""Media classification, file validation, formatting and CSV report helpers."""

import csv
import mimetypes
from pathlib import Path

from telethon.tl.types import DocumentAttributeFilename, DocumentAttributeVideo
from telegram_config import REPORT_COLUMNS, REPORT_FILE, ROOT, safe_part

# ---------- Telegram media classification / local filename helpers --------

def media_info(message):
    document = message.document
    if document is None:
        return None  # photos and text-only messages are excluded
    original = None
    is_video = (document.mime_type or "").lower().startswith("video/")
    for attr in document.attributes or []:
        if isinstance(attr, DocumentAttributeFilename):
            original = attr.file_name
        if isinstance(attr, DocumentAttributeVideo):
            is_video = True
    category = "Videos" if is_video else "Documents"
    if not original:
        ext = mimetypes.guess_extension(document.mime_type or "") or (".mp4" if is_video else ".bin")
        original = ("video" if is_video else "document") + ext
    original_path = Path(safe_part(original, 150))
    stem = safe_part(original_path.stem, 115)
    extension = "." + safe_part(original_path.suffix.lstrip("."), 15) if original_path.suffix else ""
    return category, f"{message.id}_{stem}{extension}", int(getattr(document, "size", 0) or 0)


def complete_file(target, expected_size):
    try:
        size = target.stat().st_size
        return size > 0 and (not expected_size or size == expected_size)
    except FileNotFoundError:
        return False


def existing_file(target, expected_size):
    """Recognize and repair extensionless filenames created by the earlier package."""
    if complete_file(target, expected_size):
        return True
    if target.suffix:
        old_name = target.with_name(target.stem + target.suffix.lstrip("."))
        if complete_file(old_name, expected_size):
            target.parent.mkdir(parents=True, exist_ok=True)
            old_name.replace(target)
            return True
    return False


def csv_safe(value):
    """Prevent spreadsheet-formula injection in generated CSV reports."""
    if not isinstance(value, str):
        return value
    check = value.lstrip()
    if check.startswith(("=", "+", "-", "@", "\t", "\r", "\n")):
        return "'" + value
    return value


def write_report(row):
    first = not REPORT_FILE.exists() or REPORT_FILE.stat().st_size == 0
    safe_row = {column: csv_safe(row.get(column, "")) for column in REPORT_COLUMNS}
    with REPORT_FILE.open("a", encoding="utf-8-sig", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=REPORT_COLUMNS)
        if first:
            writer.writeheader()
        writer.writerow(safe_row)


def size_text(count):
    count = float(max(0, count))
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if count < 1024 or unit == "TB":
            return f"{count:.1f}{unit}" if unit != "B" else f"{count:.0f}B"
        count /= 1024


def duration_text(seconds):
    if seconds is None or seconds < 0:
        return "--"
    seconds = int(seconds)
    if seconds < 60:
        return f"{seconds}s"
    if seconds < 3600:
        return f"{seconds // 60}m{seconds % 60:02d}s"
    return f"{seconds // 3600}h{(seconds % 3600) // 60:02d}m"
