from __future__ import annotations

"""
Custom include/exclude wrapper around Nuditag.

This helper reads SearchPaths.txt and ExcludePaths.txt, discovers supported
video files, prunes excluded directory trees before scoring, and writes CSV
reports using Nuditag's standard columns:

    path, media_type, tag, score

Safety: this module only reads media and writes reports. It never deletes,
moves, renames, or modifies a video file.
"""

import argparse
import csv
import os
from pathlib import Path

from nuditag.media import MediaKind, VIDEO_EXTENSIONS
from nuditag.pool import default_worker_count, media_scorer

FIELD_NAMES = ("path", "media_type", "tag", "score")


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Scan configured video paths with Nuditag while pruning excluded "
            "directory trees before scoring."
        )
    )
    parser.add_argument("--root", required=True)
    parser.add_argument("--search-file", required=True)
    parser.add_argument("--exclude-file", required=True)
    parser.add_argument("--full-report", required=True)
    parser.add_argument("--nsfw-report", required=True)
    parser.add_argument("--frames", type=int, default=32)
    parser.add_argument("--threshold", type=float, default=0.40)
    parser.add_argument(
        "--workers",
        type=int,
        default=0,
        help="0 = use Nuditag's automatic worker count",
    )
    return parser.parse_args()


def clean_config_line(line: str) -> str | None:
    """Return a usable path line or None for blank/comment-only lines."""
    value = line.strip()
    if not value or value.startswith("#") or value.startswith(";"):
        return None

    # Allow quoted paths copied from Explorer or another document.
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1].strip()

    value = os.path.expandvars(os.path.expanduser(value))
    return value or None


def read_path_file(path: Path) -> list[Path]:
    """Read one path per line using UTF-8 with optional BOM."""
    result: list[Path] = []
    if not path.exists():
        return result

    with path.open("r", encoding="utf-8-sig", errors="replace") as handle:
        for raw in handle:
            value = clean_config_line(raw)
            if value:
                result.append(Path(value))
    return result


def norm(path: Path | str) -> str:
    """Canonical comparison key; normcase makes it case-insensitive on Windows."""
    return os.path.normcase(os.path.abspath(os.path.normpath(str(path))))


def is_same_or_below(path: Path | str, root: Path | str) -> bool:
    """True when path is root itself or is anywhere underneath root."""
    p = norm(path)
    r = norm(root)
    try:
        return os.path.commonpath([p, r]) == r
    except ValueError:
        # Different drive letters are not parent/child of one another.
        return False


def is_excluded(path: Path | str, excludes: list[Path]) -> bool:
    """Exclusion always wins, even when a parent is in SearchPaths.txt."""
    return any(is_same_or_below(path, excluded) for excluded in excludes)


def dedupe_excludes(paths: list[Path]) -> list[Path]:
    """Remove duplicate or redundant nested exclusions."""
    unique: list[Path] = []

    for candidate in paths:
        absolute = Path(os.path.abspath(str(candidate)))

        if any(norm(absolute) == norm(existing) for existing in unique):
            continue
        if any(is_same_or_below(absolute, existing) for existing in unique):
            continue

        # If the new entry is broader, narrower earlier entries are redundant.
        unique = [
            existing
            for existing in unique
            if not is_same_or_below(existing, absolute)
        ]
        unique.append(absolute)

    return unique


def prepare_search_roots(paths: list[Path], excludes: list[Path]) -> list[Path]:
    """Validate/dedupe search roots while preserving the user's order."""
    roots: list[Path] = []

    for candidate in paths:
        absolute = Path(os.path.abspath(str(candidate)))

        if is_excluded(absolute, excludes):
            print(f"SKIP search path (excluded): {absolute}")
            continue
        if not absolute.exists():
            print(f"SKIP search path (not found): {absolute}")
            continue
        if not absolute.is_dir():
            print(f"SKIP search path (not a folder): {absolute}")
            continue

        if any(norm(absolute) == norm(existing) for existing in roots):
            print(f"SKIP duplicate search path: {absolute}")
            continue

        if any(is_same_or_below(absolute, existing) for existing in roots):
            print(f"SKIP overlapping search path: {absolute}")
            continue

        # If a later entry is broader than earlier roots, keep only the broader one.
        narrower = [
            existing for existing in roots if is_same_or_below(existing, absolute)
        ]
        for existing in narrower:
            print(f"REMOVE narrower search path covered by {absolute}: {existing}")
            roots.remove(existing)

        roots.append(absolute)

    return roots


def is_link_or_junction(path: Path) -> bool:
    """Avoid symlink/junction loops and unexpected traversal."""
    try:
        if path.is_symlink():
            return True
    except OSError:
        return True

    isjunction = getattr(os.path, "isjunction", None)
    if isjunction is not None:
        try:
            return bool(isjunction(path))
        except OSError:
            return True

    return False


def collect_videos(
    roots: list[Path],
    excludes: list[Path],
) -> dict[str, Path]:
    """
    Walk search roots, prune excluded trees, and return unique video files.

    dict insertion order intentionally preserves SearchPaths.txt root order.
    """
    videos: dict[str, Path] = {}
    extensions = {ext.lower() for ext in VIDEO_EXTENSIONS}

    def walk_error(error):
        filename = getattr(error, "filename", None) or "unknown path"
        print(f"SKIP unreadable folder: {filename} ({error})")

    for search_root in roots:
        print(f"\nWalking: {search_root}")

        for current, dirs, files in os.walk(
            search_root,
            topdown=True,
            onerror=walk_error,
            followlinks=False,
        ):
            current_path = Path(current)

            if is_excluded(current_path, excludes):
                dirs[:] = []
                continue

            kept_dirs: list[str] = []
            for dirname in dirs:
                child = current_path / dirname

                if is_excluded(child, excludes):
                    continue
                if is_link_or_junction(child):
                    continue

                kept_dirs.append(dirname)

            kept_dirs.sort(key=str.casefold)
            files.sort(key=str.casefold)
            dirs[:] = kept_dirs

            for filename in files:
                path = current_path / filename

                if path.suffix.lower() not in extensions:
                    continue
                if is_excluded(path, excludes):
                    continue

                videos.setdefault(norm(path), path)

    return videos


def read_existing_report(
    report: Path,
    threshold: float,
) -> dict[str, dict]:
    """
    Load usable old rows so interrupted/repeated runs can reuse scores.

    Existing numeric scores are re-tagged against the current threshold.
    """
    rows: dict[str, dict] = {}

    if not report.exists():
        return rows

    try:
        with report.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)

            for row in reader:
                try:
                    if row.get("media_type", "").lower() != "video":
                        continue
                    score = float(row["score"])
                    path = Path(row["path"])
                except (KeyError, TypeError, ValueError):
                    continue

                rows[norm(path)] = {
                    "path": str(path),
                    "media_type": "video",
                    "tag": "nsfw" if score >= threshold else "sfw",
                    "score": round(score, 4),
                }

    except (OSError, csv.Error) as error:
        print(f"WARNING: Could not read old report; it will be rebuilt: {error}")
        return {}

    return rows


def rewrite_retained_report(
    report: Path,
    candidates: dict[str, Path],
    old_rows: dict[str, dict],
    threshold: float,
) -> dict[str, dict]:
    """
    Synchronize the report with the CURRENT include/exclude rules.

    Rows for paths that are no longer in scope are removed from the current
    report instead of lingering forever.
    """
    report.parent.mkdir(parents=True, exist_ok=True)
    retained: dict[str, dict] = {}

    for key, candidate in candidates.items():
        row = old_rows.get(key)
        if row is None:
            continue

        try:
            score = float(row["score"])
        except (TypeError, ValueError, KeyError):
            continue

        retained[key] = {
            "path": str(candidate),
            "media_type": "video",
            "tag": "nsfw" if score >= threshold else "sfw",
            "score": round(score, 4),
        }

    temp = report.with_suffix(report.suffix + ".sync.tmp")

    with temp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=FIELD_NAMES,
            lineterminator="\n",
        )
        writer.writeheader()

        # Keep the same discovery order as candidates.
        for key in candidates:
            if key in retained:
                writer.writerow(retained[key])

        handle.flush()

    os.replace(temp, report)
    return retained


def append_scores(
    report: Path,
    pending: list[Path],
    existing: dict[str, dict],
    frames: int,
    threshold: float,
    workers: int,
):
    """
    Score unprocessed videos and flush every completed row immediately.

    Row-by-row flushing is what makes Ctrl+C/restart useful.
    """
    if not pending:
        return

    media_files = [(path, MediaKind.VIDEO) for path in pending]

    with report.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=FIELD_NAMES,
            lineterminator="\n",
        )

        with media_scorer(frames, workers) as score_all:
            scored = score_all(media_files)

            for index, (path, media_kind, score, note) in enumerate(
                scored,
                start=1,
            ):
                if note:
                    print(note)

                if score is None:
                    print(f"[{index}/{len(pending)}] SKIPPED: {path}")
                    continue

                rounded = round(float(score), 4)
                tag = "nsfw" if rounded >= threshold else "sfw"

                row = {
                    "path": str(path),
                    "media_type": media_kind.value,
                    "tag": tag,
                    "score": rounded,
                }

                writer.writerow(row)
                handle.flush()
                existing[norm(path)] = row

                print(
                    f"[{index}/{len(pending)}] "
                    f"{tag.upper():4s} {rounded:.4f}  {path}"
                )


def write_nsfw_report(
    full_report: Path,
    nsfw_report: Path,
    threshold: float,
) -> int:
    """Create the easy-to-review NSFW-only CSV."""
    nsfw_report.parent.mkdir(parents=True, exist_ok=True)
    flagged: list[dict] = []

    if full_report.exists():
        with full_report.open(
            "r",
            encoding="utf-8-sig",
            newline="",
        ) as handle:
            reader = csv.DictReader(handle)

            for row in reader:
                try:
                    score = float(row["score"])
                except (KeyError, TypeError, ValueError):
                    continue

                if (
                    row.get("media_type", "").lower() == "video"
                    and score >= threshold
                ):
                    flagged.append(
                        {
                            "path": row.get("path", ""),
                            "media_type": "video",
                            "tag": "nsfw",
                            "score": round(score, 4),
                        }
                    )

    temp = nsfw_report.with_suffix(nsfw_report.suffix + ".tmp")

    with temp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=FIELD_NAMES,
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(flagged)
        handle.flush()

    os.replace(temp, nsfw_report)
    return len(flagged)


def main() -> int:
    args = parse_args()

    if args.frames < 1:
        print("ERROR: --frames must be at least 1.")
        return 2
    if not 0 <= args.threshold <= 1:
        print("ERROR: --threshold must be between 0 and 1.")
        return 2

    root = Path(args.root)
    search_file = Path(args.search_file)
    exclude_file = Path(args.exclude_file)
    full_report = Path(args.full_report)
    nsfw_report = Path(args.nsfw_report)

    search_paths = read_path_file(search_file)
    excludes = read_path_file(exclude_file)

    # Never scan the scanner's own installation/model/report tree.
    excludes.append(root)
    excludes = dedupe_excludes(excludes)

    if not search_paths:
        print(f"ERROR: No search paths are configured in {search_file}")
        return 2

    roots = prepare_search_roots(search_paths, excludes)

    if not roots:
        print(
            "ERROR: No usable search paths remain after "
            "validation/exclusion."
        )
        return 2

    print("\nSEARCH ROOTS")
    for path in roots:
        print(f"  + {path}")

    print("\nEXCLUDED TREES")
    for path in excludes:
        print(f"  - {path}")

    print("\nFinding supported video files...")
    candidates = collect_videos(roots, excludes)
    print(f"\nFound {len(candidates):,} unique supported video file(s).")

    old_rows = read_existing_report(full_report, args.threshold)
    retained = rewrite_retained_report(
        full_report,
        candidates,
        old_rows,
        args.threshold,
    )

    pending = [
        path
        for key, path in candidates.items()
        if key not in retained
    ]

    print(f"Already analysed and still in scope: {len(retained):,}")
    print(f"New/unanalysed videos to score:       {len(pending):,}")

    workers = args.workers if args.workers > 0 else default_worker_count()

    print(f"Frames per video: {args.frames}")
    print(f"Workers:          {workers}")
    print(f"NSFW threshold:   {args.threshold:.2f}")

    interrupted = False

    try:
        append_scores(
            full_report,
            pending,
            retained,
            args.frames,
            args.threshold,
            workers,
        )
    except KeyboardInterrupt:
        interrupted = True
        print("\nScan interrupted. Completed rows have been preserved.")

    flagged_count = write_nsfw_report(
        full_report,
        nsfw_report,
        args.threshold,
    )

    completed = 0
    if full_report.exists():
        with full_report.open(
            "r",
            encoding="utf-8-sig",
            newline="",
        ) as handle:
            completed = sum(1 for _ in csv.DictReader(handle))

    print("\nSUMMARY")
    print(f"Videos currently in scope:    {len(candidates):,}")
    print(f"Videos with completed score:  {completed:,}")
    print(f"NSFW videos in report:        {flagged_count:,}")
    print(f"Full report:                  {full_report}")
    print(f"NSFW-only report:             {nsfw_report}")

    return 130 if interrupted else 0


if __name__ == "__main__":
    raise SystemExit(main())
