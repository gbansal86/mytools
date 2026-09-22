#!/usr/bin/env python3
"""Install portable FFmpeg beside this tool using Python's standard library."""
from __future__ import annotations

import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RUNTIME = ROOT / "_runtime"
DOWNLOADS = RUNTIME / "downloads"
FFMPEG_DIR = RUNTIME / "ffmpeg"
LOG = ROOT / "install_log.txt"
URLS = [
    "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
]
BLOCK = 1024 * 1024
TIMEOUT = 30


def log(message: str) -> None:
    line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {message}"
    print(line)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def human(n: int) -> str:
    value = float(n)
    for unit in ["B", "KB", "MB", "GB"]:
        if value < 1024 or unit == "GB":
            return f"{value:.1f} {unit}"
        value /= 1024
    return str(n)


def verified(path: str | Path) -> bool:
    try:
        return subprocess.run([str(path), "-version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15).returncode == 0
    except Exception:
        return False


def find_local(name: str) -> Path | None:
    if not FFMPEG_DIR.exists():
        return None
    return next(FFMPEG_DIR.rglob(f"{name}.exe"), None)


def download(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temp = target.with_suffix(target.suffix + ".part")
    temp.unlink(missing_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 VideoDuplicateFinder/1.0"})
    log(f"Downloading {url}")
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response, temp.open("wb") as out:
        total = int(response.headers.get("Content-Length", "0") or 0)
        done = 0
        started = time.time()
        while True:
            chunk = response.read(BLOCK)
            if not chunk:
                break
            out.write(chunk)
            done += len(chunk)
            elapsed = max(time.time() - started, 0.001)
            speed = done / elapsed
            if total:
                print(f"\r  {done * 100 / total:6.2f}%  {human(done)} / {human(total)}  {human(int(speed))}/s", end="", flush=True)
            else:
                print(f"\r  {human(done)} downloaded  {human(int(speed))}/s", end="", flush=True)
    print()
    if temp.stat().st_size < 100_000:
        temp.unlink(missing_ok=True)
        raise RuntimeError("Downloaded file is unexpectedly small.")
    temp.replace(target)


def install() -> tuple[Path, Path]:
    sys_ffmpeg, sys_ffprobe = shutil.which("ffmpeg"), shutil.which("ffprobe")
    if sys_ffmpeg and sys_ffprobe and verified(sys_ffmpeg) and verified(sys_ffprobe):
        log(f"System FFmpeg already works: {sys_ffmpeg}")
        return Path(sys_ffmpeg), Path(sys_ffprobe)

    local_ffmpeg, local_ffprobe = find_local("ffmpeg"), find_local("ffprobe")
    if local_ffmpeg and local_ffprobe and verified(local_ffmpeg) and verified(local_ffprobe):
        log(f"Portable FFmpeg already works: {local_ffmpeg}")
        return local_ffmpeg, local_ffprobe

    archive = DOWNLOADS / "ffmpeg-release-essentials.zip"
    last_error: Exception | None = None
    for url in URLS:
        try:
            download(url, archive)
            last_error = None
            break
        except Exception as exc:
            last_error = exc
            log(f"Download failed: {exc}")
    if last_error:
        raise RuntimeError(f"Could not download FFmpeg: {last_error}")

    print("Extracting FFmpeg...")
    if FFMPEG_DIR.exists():
        shutil.rmtree(FFMPEG_DIR)
    FFMPEG_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as zf:
        zf.extractall(FFMPEG_DIR)

    local_ffmpeg, local_ffprobe = find_local("ffmpeg"), find_local("ffprobe")
    if not local_ffmpeg or not local_ffprobe:
        raise RuntimeError("FFmpeg extracted, but ffmpeg.exe/ffprobe.exe were not found.")
    if not verified(local_ffmpeg) or not verified(local_ffprobe):
        raise RuntimeError("Extracted FFmpeg failed its verification test.")
    log(f"Portable FFmpeg installed: {local_ffmpeg}")
    return local_ffmpeg, local_ffprobe


def main() -> int:
    LOG.write_text("Video Duplicate Finder prerequisite log\n", encoding="utf-8")
    print("=" * 68)
    print("VIDEO DUPLICATE FINDER - PREREQUISITE SETUP")
    print("=" * 68)
    print(f"Python: {sys.executable}")
    print(f"Version: {sys.version.splitlines()[0]}")
    if sys.version_info < (3, 10):
        raise RuntimeError("Python 3.10 or newer is required.")
    ffmpeg, ffprobe = install()
    print("\nSUCCESS")
    print(f"FFmpeg : {ffmpeg}")
    print(f"FFprobe: {ffprobe}")
    print("\nNext: edit video_paths.txt, then run run_duplicate_scan.bat")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        log(f"FAILED: {type(exc).__name__}: {exc}")
        print(f"\nInstallation failed. See: {LOG}")
        raise SystemExit(1)
