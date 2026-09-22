"""Dependency-free pre-publication privacy check for this repository."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

FORBIDDEN_EXACT = {
    "telegram_settings.json",
    "channels.txt",
    "download_report.csv",
    ".env",
}
FORBIDDEN_PREFIXES = ("telegram_session",)
FORBIDDEN_DIRS = {"downloads", "channel_exports", ".venv", "__pycache__", ".git"}
TEXT_EXTENSIONS = {".py", ".bat", ".md", ".txt", ".json", ".yml", ".yaml", ".toml", ".ini", ".cfg", ".csv"}

PATTERNS = [
    ("Telegram API hash", re.compile(r'(?i)["\']?api_hash["\']?\s*[:=]\s*["\'][0-9a-f]{32}["\']')),
    ("Windows user profile path", re.compile(r'(?i)\b[A-Z]:\\Users\\[^\\\r\n]+')),
    ("possible phone number", re.compile(r'(?<!\d)\+\d{9,15}(?!\d)')),
]


def iter_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in FORBIDDEN_DIRS for part in path.relative_to(ROOT).parts[:-1]):
            continue
        yield path


def main() -> int:
    problems: list[str] = []

    for path in ROOT.iterdir():
        name = path.name
        if name in FORBIDDEN_EXACT or name.startswith(FORBIDDEN_PREFIXES):
            problems.append(f"private runtime item present: {name}")

    for path in iter_files():
        if path.suffix.lower() not in TEXT_EXTENSIONS and path.name != ".gitignore":
            continue
        # Example templates intentionally contain placeholder credential keys.
        if path.name == "telegram_settings.example.json":
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            problems.append(f"cannot read {path.relative_to(ROOT)}: {exc}")
            continue
        for label, pattern in PATTERNS:
            if pattern.search(text):
                problems.append(f"{label} found in {path.relative_to(ROOT)}")

    if problems:
        print("PRE-PUBLISH CHECK FAILED")
        for problem in problems:
            print(f" - {problem}")
        print("\nRemove or sanitize the listed data before publishing.")
        return 1

    print("PRE-PUBLISH CHECK PASSED")
    print("No known credential/session/runtime files or obvious personal Windows paths were found.")
    print("Still review git status and the staged diff before every public push.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
