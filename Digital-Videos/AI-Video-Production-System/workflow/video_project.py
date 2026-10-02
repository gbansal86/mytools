from __future__ import annotations

import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

PROJECT_DIRS = [
    "01_SOURCE",
    "02_ANALYSIS",
    "03_AUDIO",
    "04_TRANSCRIPT",
    "05_PLAN",
    "06_ASSETS/generated",
    "06_ASSETS/normalized",
    "06_ASSETS/thumbnails",
    "06_ASSETS/branding",
    "07_TIMELINE",
    "08_SUBTITLES",
    "09_RENDER/segments",
    "10_QA/checkpoints",
    "11_OUTPUT",
    "logs",
]

DEFAULT_STATE = {
    "state": "NEW",
    "completed_phases": [],
    "failed_phase": None,
    "message": "",
}

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def slugify(name: str) -> str:
    safe = []
    for ch in name.lower().strip():
        if ch.isalnum():
            safe.append(ch)
        elif ch in " -_":
            safe.append("-")
    return "".join(safe).strip("-") or "video"

def create_project(source: Path, projects_root: Path, name: str | None = None) -> Path:
    source = source.resolve()
    if not source.exists():
        raise FileNotFoundError(source)

    stamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    project_name = slugify(name or source.stem)
    project_id = f"{stamp}_{project_name}"
    project = projects_root.resolve() / project_id
    project.mkdir(parents=True, exist_ok=False)

    for d in PROJECT_DIRS:
        (project / d).mkdir(parents=True, exist_ok=True)

    dest = project / "01_SOURCE" / source.name
    shutil.copy2(source, dest)

    manifest = {
        "project_id": project_id,
        "project_name": project_name,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "source_filename": source.name,
        "source_sha256": sha256_file(source),
        "pipeline_version": "0.1.0",
        "plan_version": 0,
        "render_version": 0,
        "target_duration": None,
        "final_output": None,
    }

    (project / "project_manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    (project / "project_state.json").write_text(
        json.dumps(DEFAULT_STATE, indent=2), encoding="utf-8"
    )

    return project

def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python video_project.py <raw-video> [projects-root] [project-name]")
        raise SystemExit(2)

    source = Path(sys.argv[1])
    root = Path(sys.argv[2]) if len(sys.argv) >= 3 else Path("VIDEO_PROJECTS")
    name = sys.argv[3] if len(sys.argv) >= 4 else None
    project = create_project(source, root, name)
    print(project)

if __name__ == "__main__":
    main()
