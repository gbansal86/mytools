from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]

LINK_RE = re.compile(r"!?[[^]]*](([^)]+))")
EXCLUDED_PARTS = {".git", ".venv", "venv", "__pycache__"}

REQUIRED_ROOT_FILES = {
    "LICENSE",
    "README.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "SUPPORT.md",
    "CODE_OF_CONDUCT.md",
    "TESTING.md",
    "RELEASING.md",
    "ROADMAP.md",
    "OSS_PROJECT_OVERVIEW.md",
    "MAINTAINERS.md",
    "GOVERNANCE.md",
    "THREAT_MODEL.md",
    "TOOL_GALLERY.md",
}


def markdown_files() -> list[Path]:
    return sorted(
        p
        for p in ROOT.rglob("*.md")
        if not any(part in EXCLUDED_PARTS for part in p.parts)
    )


def local_target(raw: str) -> str | None:
    target = raw.strip()

    if not target or target.startswith("#"):
        return None

    if target.startswith("<"):
        end = target.find(">")
        if end > 0:
            target = target[1:end]
    else:
        match = re.match(r"(S+)", target)
        if not match:
            return None
        target = match.group(1)

    lowered = target.lower()
    if lowered.startswith(
        ("http://", "https://", "mailto:", "tel:", "data:", "javascript:")
    ):
        return None

    target = target.split("#", 1)[0].split("?", 1)[0]
    target = unquote(target)
    return target or None


def validate_required_files(errors: list[str]) -> None:
    for name in sorted(REQUIRED_ROOT_FILES):
        if not (ROOT / name).is_file():
            errors.append(f"Missing required root file: {name}")


def validate_tool_folders(errors: list[str]) -> list[Path]:
    tool_dirs = sorted(
        p
        for p in ROOT.iterdir()
        if p.is_dir() and not p.name.startswith(".")
    )

    for tool_dir in tool_dirs:
        for required in ("README.md", "LICENSE"):
            if not (tool_dir / required).is_file():
                errors.append(f"{tool_dir.name}: missing {required}")

    return tool_dirs


def validate_markdown_links(errors: list[str]) -> None:
    root_resolved = ROOT.resolve()

    for doc in markdown_files():
        text = doc.read_text(encoding="utf-8")
        for match in LINK_RE.finditer(text):
            target = local_target(match.group(1))
            if target is None:
                continue

            candidate = (doc.parent / target).resolve()
            try:
                candidate.relative_to(root_resolved)
            except ValueError:
                errors.append(
                    f"{doc.relative_to(ROOT)} -> {target} escapes repository root"
                )
                continue

            if not candidate.exists():
                errors.append(f"{doc.relative_to(ROOT)} -> {target}")


def validate_readme_catalog(tool_dirs: list[Path], errors: list[str]) -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for tool_dir in tool_dirs:
        expected = f"./{tool_dir.name}/"
        if expected not in readme:
            errors.append(
                f"README.md does not link to top-level tool directory {tool_dir.name}"
            )


def main() -> int:
    errors: list[str] = []
    validate_required_files(errors)
    tool_dirs = validate_tool_folders(errors)
    validate_markdown_links(errors)
    validate_readme_catalog(tool_dirs, errors)

    if errors:
        print("Repository documentation validation failed:")
        for error in errors:
            print(f" - {error}")
        return 1

    print(
        f"Documentation integrity OK: {len(markdown_files())} Markdown files, "
        f"{len(tool_dirs)} tool directories."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
