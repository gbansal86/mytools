"""Local dependency bootstrap for Book Duplicate Finder.

This helper keeps the tool portable and beginner-friendly. It uses the user's
existing Python installation, but installs Python packages into ``./deps`` and
helper programs into ``./tools`` instead of intentionally installing them
system-wide.

It also validates DjVuLibre downloads before extraction. This prevents an HTML
redirect/error page from being mistaken for a ZIP file, which was the v1.0
DjVu installer problem fixed in v1.1.
"""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEPS = ROOT / "deps"
TOOLS = ROOT / "tools"
DOWNLOADS = ROOT / "downloads"
REQ = ROOT / "requirements-local.txt"

SEVEN_ZIP_VERSION = "2603"
SEVEN_ZIP_BOOTSTRAP_URL = "https://www.7-zip.org/a/7zr.exe"
DJVU_SETUP_NAME = "DjVuLibre-3.5.29_DjView-4.12_Setup.exe"
DJVU_SETUP_URLS = [
    "https://downloads.sourceforge.net/project/djvu/DjVuLibre_Windows/3.5.29%2B4.12/DjVuLibre-3.5.29_DjView-4.12_Setup.exe",
    "https://master.dl.sourceforge.net/project/djvu/DjVuLibre_Windows/3.5.29%2B4.12/DjVuLibre-3.5.29_DjView-4.12_Setup.exe?download=",
]
# Old portable ZIP is kept only as a fallback if the current setup package
# cannot be downloaded/extracted on a particular SourceForge mirror.
DJVU_ZIP_NAME = "djvulibre-3.5.20+djview-4.3-win32.zip"
DJVU_ZIP_URLS = [
    "https://downloads.sourceforge.net/project/djvu/DjVuLibre_Windows/3.5.20%2B4.3/djvulibre-3.5.20%2Bdjview-4.3-win32.zip",
    "https://master.dl.sourceforge.net/project/djvu/DjVuLibre_Windows/3.5.20%2B4.3/djvulibre-3.5.20%2Bdjview-4.3-win32.zip?download=",
]


def banner(msg: str) -> None:
    print("\n" + "=" * 68)
    print(msg)
    print("=" * 68)


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1024:
        print(f"Already downloaded: {dest.name}")
        return
    print(f"Downloading: {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 BookDuplicateFinder/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)
    print(f"Saved: {dest} ({dest.stat().st_size:,} bytes)")


def _starts_with(path: Path, magic: bytes) -> bool:
    try:
        with path.open("rb") as f:
            return f.read(len(magic)) == magic
    except OSError:
        return False


def valid_pe(path: Path) -> bool:
    # Windows executables start with the DOS MZ signature. Requiring a
    # reasonable size also rejects SourceForge HTML/error pages.
    return path.exists() and path.stat().st_size > 1_000_000 and _starts_with(path, b"MZ")


def valid_zip(path: Path) -> bool:
    try:
        return path.exists() and path.stat().st_size > 100_000 and zipfile.is_zipfile(path)
    except OSError:
        return False


def download_validated(urls: list[str], dest: Path, validator, description: str) -> None:
    """Download with cache validation and SourceForge mirror fallback.

    A previous version only checked file size, so an HTML redirect/error page
    could be cached forever with a .zip extension. This routine validates the
    actual file signature/format and automatically removes bad cached files.
    """
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        if validator(dest):
            print(f"Already downloaded and validated: {dest.name}")
            return
        print(f"Removing invalid cached download: {dest.name}")
        try:
            dest.unlink()
        except OSError:
            pass

    errors: list[str] = []
    for i, url in enumerate(urls, 1):
        part = dest.with_suffix(dest.suffix + ".part")
        try:
            if part.exists():
                part.unlink()
            print(f"Downloading {description} (source {i}/{len(urls)}):")
            print(f"  {url}")
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) BookDuplicateFinder/1.1",
                    "Accept": "*/*",
                },
            )
            with urllib.request.urlopen(req, timeout=180) as r, open(part, "wb") as f:
                shutil.copyfileobj(r, f)
            if not validator(part):
                head = b""
                try:
                    with part.open("rb") as f:
                        head = f.read(120).lower()
                except OSError:
                    pass
                hint = " (received HTML instead of the file)" if b"<html" in head or b"<!doctype" in head else ""
                raise RuntimeError(f"downloaded file failed validation{hint}; size={part.stat().st_size:,} bytes")
            part.replace(dest)
            print(f"Saved and validated: {dest} ({dest.stat().st_size:,} bytes)")
            return
        except Exception as exc:
            errors.append(f"source {i}: {exc}")
            try:
                if part.exists():
                    part.unlink()
            except OSError:
                pass
    raise RuntimeError(f"Could not download a valid {description}. " + " | ".join(errors))


def extract_zip(src: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(src, "r") as z:
        z.extractall(dest)


def find_tool(name: str) -> Path | None:
    lname = name.lower()
    for p in TOOLS.rglob("*"):
        if p.is_file() and p.name.lower() == lname:
            return p
    return None


def install_python_deps() -> None:
    DEPS.mkdir(parents=True, exist_ok=True)
    marker = DEPS / ".installed"
    # Always let pip verify/update dependencies; --target keeps everything local.
    cmd = [
        sys.executable, "-m", "pip", "install",
        "--disable-pip-version-check",
        "--upgrade",
        "--target", str(DEPS),
        "-r", str(REQ),
    ]
    print("Installing/updating Python packages inside:")
    print(f"  {DEPS}")
    print("Command:", " ".join(f'"{x}"' if " " in x else x for x in cmd))
    subprocess.check_call(cmd)
    marker.write_text("ok\n", encoding="utf-8")


def install_7zip() -> None:
    # CHM/CBR need the full 7z.exe + 7z.dll set. 7za.exe is intentionally not
    # used because the standalone "a" build supports only a limited format set.
    if find_tool("7z.exe") and find_tool("7z.dll"):
        print("Full local 7-Zip command-line files already available.")
        return

    arch = platform.machine().lower()
    if "arm" in arch or "aarch64" in arch:
        installer_name = f"7z{SEVEN_ZIP_VERSION}-arm64.exe"
    elif arch in {"x86", "i386", "i686"}:
        installer_name = f"7z{SEVEN_ZIP_VERSION}.exe"
    else:
        installer_name = f"7z{SEVEN_ZIP_VERSION}-x64.exe"

    bootstrap_exe = DOWNLOADS / "7zr.exe"
    installer = DOWNLOADS / installer_name
    download(SEVEN_ZIP_BOOTSTRAP_URL, bootstrap_exe)
    download(f"https://www.7-zip.org/a/{installer_name}", installer)

    dest = TOOLS / "7zip"
    if dest.exists():
        shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True, exist_ok=True)

    cp = subprocess.run(
        [str(bootstrap_exe), "x", str(installer), f"-o{dest}", "-y"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120
    )
    if cp.returncode not in (0, 1):
        raise RuntimeError(f"Could not unpack the 7-Zip installer locally (code {cp.returncode}).\n{cp.stdout[-2000:]}")
    if not find_tool("7z.exe") or not find_tool("7z.dll"):
        raise RuntimeError("7z.exe/7z.dll were not found after local extraction.")
    print("Full local 7-Zip installed without a system-wide install.")


def install_djvu() -> None:
    if find_tool("djvutxt.exe") and find_tool("ddjvu.exe") and find_tool("djvused.exe"):
        print("DjVuLibre command-line tools already available locally.")
        return

    # Remove the bad cache filename used by v1.0. It may contain a SourceForge
    # HTML page even though its extension says .zip.
    legacy_bad = DOWNLOADS / "djvulibre-win32.zip"
    if legacy_bad.exists() and not valid_zip(legacy_bad):
        print(f"Removing invalid v1.0 DjVu cache: {legacy_bad.name}")
        try:
            legacy_bad.unlink()
        except OSError:
            pass

    dest = TOOLS / "djvulibre"
    if dest.exists():
        shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True, exist_ok=True)

    errors: list[str] = []

    # Preferred path: current official Windows setup package, unpacked locally
    # with our bundled 7-Zip. Nothing is installed system-wide.
    setup = DOWNLOADS / DJVU_SETUP_NAME
    try:
        download_validated(DJVU_SETUP_URLS, setup, valid_pe, "DjVuLibre Windows package")
        seven = find_tool("7z.exe")
        if not seven:
            raise RuntimeError("7z.exe is unavailable, so the DjVuLibre setup cannot be unpacked locally")
        cp = subprocess.run(
            [str(seven), "x", str(setup), f"-o{dest}", "-y"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180,
        )
        if cp.returncode not in (0, 1):
            raise RuntimeError(f"7-Zip could not unpack DjVuLibre setup (code {cp.returncode}). {cp.stdout[-1200:]}")
        if find_tool("djvutxt.exe") and find_tool("ddjvu.exe"):
            print("Local DjVuLibre tools installed from the current Windows package.")
            return
        raise RuntimeError("setup unpacked, but djvutxt.exe/ddjvu.exe were not found")
    except Exception as exc:
        errors.append(f"current Windows package: {exc}")
        shutil.rmtree(dest, ignore_errors=True)
        dest.mkdir(parents=True, exist_ok=True)

    # Fallback: older official portable ZIP. Direct downloads.sourceforge.net
    # URLs are used rather than the /download web page that caused the v1.0 bug.
    archive = DOWNLOADS / DJVU_ZIP_NAME
    try:
        download_validated(DJVU_ZIP_URLS, archive, valid_zip, "DjVuLibre portable ZIP")
        extract_zip(archive, dest)
        if not find_tool("djvutxt.exe") or not find_tool("ddjvu.exe"):
            raise RuntimeError("portable ZIP extracted, but required command-line tools were not found")
        print("Local DjVuLibre tools installed from the portable fallback package.")
        return
    except Exception as exc:
        errors.append(f"portable ZIP fallback: {exc}")

    raise RuntimeError("DjVuLibre local installation failed. " + " | ".join(errors))


def ensure_config_files() -> None:
    sp = ROOT / "search_paths.txt"
    ep = ROOT / "exclude_paths.txt"
    if not sp.exists():
        sp.write_text("# One search folder per line\nD:\\Books\n", encoding="utf-8")
    if not ep.exists():
        ep.write_text("# One excluded folder per line\n", encoding="utf-8")


def main() -> int:
    os.chdir(ROOT)
    ensure_config_files()

    banner("STEP 1/4 - LOCAL PYTHON DEPENDENCIES")
    try:
        install_python_deps()
    except Exception as exc:
        print(f"ERROR installing Python dependencies: {exc}")
        print("Nothing is installed globally; all Python packages are meant to stay in .\\deps")
        return 10

    banner("STEP 2/4 - LOCAL CHM SUPPORT")
    try:
        install_7zip()
    except Exception as exc:
        print(f"WARNING: Could not install local 7-Zip: {exc}")
        print("PDF/EPUB/etc. scanning can continue, but CHM/CBR support may be unavailable.")

    banner("STEP 3/4 - LOCAL DJVU SUPPORT")
    try:
        install_djvu()
    except Exception as exc:
        print(f"WARNING: Could not install local DjVuLibre tools: {exc}")
        print("Other formats can continue; DJVU support may be unavailable.")

    banner("STEP 4/4 - SCAN")
    scanner = ROOT / "book_duplicate_finder.py"
    rc = subprocess.call([sys.executable, str(scanner)])
    return int(rc)


if __name__ == "__main__":
    raise SystemExit(main())
