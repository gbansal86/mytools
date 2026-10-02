# Windows Application Architecture Plan

## Goal

Standardize the technology choices for the Windows applications in this repository so each tool uses the framework that best fits its workload.

The long-term recommendation is to use three main approaches:

1. **C# + WPF** for Windows-native utilities.
2. **Tauri + React + TypeScript** for rich desktop applications with dashboards, media, search, filters, and complex workflows.
3. **Python** mainly as the processing/AI/automation backend, with **CustomTkinter** reserved for quick prototypes and very small tools.

---

# Decision Rule

Use this for future applications:

```text
New application
     |
     +-- Mostly Windows/system/hardware/files?
     |        |
     |        +-- YES -> C# + WPF
     |
     +-- Rich dashboard/media/catalog/search/AI?
     |        |
     |        +-- YES -> Tauri + React + TypeScript
     |
     +-- Small personal utility/prototype?
              |
              +-- YES -> Python + CustomTkinter
```

Do not force one GUI framework onto every project.

---

# Recommended Stack by Application

| Application | Recommended UI | Backend / Engine | Reason |
|---|---|---|---|
| VideoHoarder | Tauri + React + TypeScript | Python + SQLite + yt-dlp + FFmpeg + AI | Rich library, reports, search, jobs, transcript status |
| Telegram Content Catalog Manager | Tauri + React + TypeScript | Python + Telethon + SQLite | Tables, thumbnails, filters, search, sync, duplicate review |
| Telegram Search Engine | C# WPF or Tauri | Python/Telethon + SQLite FTS5 | WPF for simple utility; Tauri if it becomes a full research UI |
| Local AI Video/Audio Generator | Tauri + React | Python + PyTorch/CUDA + FFmpeg + Whisper/TTS | Keep AI isolated from GUI so the app stays responsive |
| Video Duplicate Finder | Tauri + React | Python + FFmpeg/FFprobe | Best fit for thumbnails, video preview, grouped duplicates |
| Duplicate Document Finder | C# WPF | .NET, optional Python parsers | Mostly filesystem, hashing, metadata, move/delete operations |
| Nested Archive Extractor | C# WPF | 7-Zip/CLI | Small native Windows utility |
| Unzip-All Utility | C# WinForms/WPF | .NET | Simple native utility; Python is unnecessary long-term |
| USB Port Explorer | C# WPF | Windows APIs + WMI/PnP | Strong Windows hardware integration |
| Windows PC Diagnostic Master | C# WPF | PowerShell + WMI/CIM + Windows APIs | Native access to diagnostics, services, registry, hardware |
| LDPlayer Repair Tool | C# WPF | ADB + PowerShell + Windows networking commands | Reliable process and system control |
| Nuditag / Image Classification | Tauri + React | Python + ONNX/PyTorch + OpenCV | ML remains in Python; rich image review in React |
| Course HTML Viewer | Tauri + React | Local filesystem / SQLite | Already web/content oriented, ideal for modern UI |
| Course / Catalog Scraper | Tauri + React | Python + browser/HTTP + SQLite | Complex jobs, progress, filters, export UI |
| Downloadly Report Extractor | Tauri + React | Python + browser automation + reporting | Good job/status interface while preserving Python logic |
| Google Drive Downloader GUI | C# WPF | rclone | Native wrapper around rclone with progress/logs |
| yt-dlp Video Downloader GUI | Tauri + React | yt-dlp + FFmpeg | Modern queue, thumbnails, format selection, progress |
| FFmpeg Utilities | C# WPF | FFmpeg + FFprobe | Native wrapper around CLI tools |
| Folder Rename Utility | C# WPF/WinForms | .NET filesystem | Very small Windows-native tool |
| VideoHoarder Packaging Utility | C# WPF | .NET/Python where needed | Mostly filesystem, ZIP, manifest, validation |
| Affiliate / Deals Manager | Tauri + React | Python + SQLite + APIs | Product cards, images, filters, posting workflow |
| Magazine / Article Research Catalog | Tauri + React | Python + SQLite | Spreadsheet-like filtering, ratings, links, images |
| Browser Extension / Research Catalog | Tauri + React | Python + SQLite | Same rich catalog/search model |

---

# Stack A — C# + WPF

Use for applications that mainly interact with Windows itself.

Best suited to:

- WMI / CIM
- Registry
- USB and PnP devices
- Services
- Processes
- PowerShell
- Windows networking
- Filesystem tools
- Hardware information
- Native dialogs
- CLI wrappers

Typical architecture:

```text
C# WPF GUI
    |
    +-- Windows APIs
    +-- WMI / CIM
    +-- Registry
    +-- PowerShell
    +-- Filesystem
    +-- External tools
            |
            +-- FFmpeg
            +-- 7-Zip
            +-- ADB
            +-- rclone
```

### Main advantages

- Native Windows feel
- Low runtime overhead
- Excellent process management
- Strong Windows API access
- Easy EXE packaging
- Mature Visual Studio tooling
- Better fit than Python for hardware/system utilities

---

# Stack B — Tauri + React + TypeScript

Use for larger applications with complex interfaces.

Best suited to:

- dashboards
- media grids
- video preview
- large tables
- filters
- search
- logs
- settings
- job queues
- reports
- multi-page apps
- AI workflows

Suggested frontend libraries:

- React
- TypeScript
- Tailwind CSS
- shadcn/ui
- TanStack Table
- Zustand or another small state manager

Typical architecture:

```text
React + TypeScript
        |
      Tauri
        |
   Rust command layer
        |
  +-----+-----------------------+
  |                             |
Python workers              Native commands
  |                             |
  +-- PyTorch                   +-- Filesystem
  +-- Whisper                   +-- Process control
  +-- XTTS                      +-- OS integration
  +-- OpenCV
  +-- Telethon
  +-- yt-dlp
  +-- scraping
  +-- AI models
        |
   SQLite / Files
```

### Main advantages

- Modern interface
- Much lighter than Electron
- Strong fit for media and data-heavy apps
- Existing Python backends can remain
- GUI can stay responsive while Python performs long jobs

---

# Stack C — Python + CustomTkinter

Reserve this for:

- prototypes
- experiments
- test harnesses
- quick internal tools
- one-off utilities
- model testers
- temporary helpers

Use it when speed of development matters more than long-term architecture.

Avoid making it the default for applications that grow into large multi-page tools.

---

# Core Architecture Rule

Do not put the full application logic inside the GUI process.

Prefer:

```text
GUI
 |
Job Controller
 |
Worker Processes
 |
Storage
```

For example:

```text
Application.exe

Frontend
|
+-- Dashboard
+-- Jobs
+-- Search
+-- Reports
+-- Logs
+-- Settings

Worker Manager
|
+-- Python worker
+-- FFmpeg
+-- yt-dlp
+-- PowerShell
+-- ADB
+-- Other CLI tools

Storage
|
+-- SQLite
+-- JSON
+-- Logs
+-- Media
+-- Reports
```

This prevents long-running operations from freezing the UI.

---

# Worker Communication

For simple tools:

```text
GUI
 |
Start process
 |
Read stdout/stderr
 |
Parse progress
```

For larger tools, use structured communication such as:

- JSON over stdin/stdout
- local HTTP API
- WebSocket
- named pipes
- local IPC

Recommended first choice: **JSON over stdin/stdout** because it is simple and easy to debug.

Example:

```json
{
  "event": "progress",
  "job_id": "video_001",
  "percent": 68,
  "message": "Transcribing audio"
}
```

---

# Standard Job Model

Large applications should share a consistent job-state model.

Suggested states:

```text
queued
starting
running
paused
completed
failed
cancelled
retrying
```

Each job should track:

- job ID
- type
- input
- output
- created time
- start time
- end time
- percent complete
- current status
- last error
- log path
- retry count

This is especially useful for VideoHoarder, Telegram tools, AI generation, duplicate scanning, and downloader applications.

---

# Resource Monitoring

AI and media-heavy applications should optionally show:

- CPU
- RAM
- GPU
- VRAM
- disk free space
- disk read/write
- network activity
- active workers
- queued jobs

This is useful for:

- Whisper
- TTS
- image generation
- video generation
- FFmpeg
- duplicate scanning

---

# Migration Strategy

Do not rewrite working applications all at once.

## Phase 1 — Separate processing from GUI

Keep existing Python logic.

Move processing into reusable modules that do not depend on PySide6/Tkinter widgets.

Before:

```text
PySide6 Window
   |
download_video()
process_transcript()
generate_report()
```

After:

```text
GUI
 |
Worker Interface
 |
download_video()
process_transcript()
generate_report()
```

## Phase 2 — Add a stable worker interface

Create commands such as:

```text
scan
download
process
cancel
status
export
```

Return machine-readable JSON instead of GUI-specific callbacks.

## Phase 3 — Replace only the frontend

Choose:

```text
Windows/system utility -> C# WPF

Rich application -> Tauri + React
```

Keep the Python engine where it already works well.

## Phase 4 — Improve packaging

The installer should avoid requiring the user to manually configure Python, FFmpeg, or other dependencies when licensing and packaging rules allow.

---

# When PySide6 Still Makes Sense

PySide6 does not need to be removed from every existing project.

Keep it when:

- the current application is stable
- the UI is not complicated
- migration provides little practical benefit
- Python-only development is preferred
- cross-platform support is important

Do not rewrite stable software only to change frameworks.

Migrate when the application has a clear need for better responsiveness, maintainability, richer UI, or Windows-native integration.

---

# Recommended Repository Layout

## Larger Tauri + Python application

```text
project/
|
+-- frontend/
|   +-- React
|   +-- TypeScript
|   +-- Tauri
|
+-- backend/
|   +-- python/
|       +-- workers/
|       +-- services/
|       +-- models/
|
+-- shared/
|   +-- schemas/
|   +-- config/
|
+-- data/
+-- logs/
+-- tests/
+-- docs/
+-- scripts/
+-- packaging/
+-- README.md
```

## C# Windows utility

```text
project/
|
+-- src/
|   +-- App/
|   +-- Views/
|   +-- ViewModels/
|   +-- Services/
|   +-- Models/
|
+-- scripts/
+-- tools/
+-- tests/
+-- docs/
+-- packaging/
+-- README.md
```

---

# Final Standard

```text
                     MYTOOLS APPLICATIONS

          +----------------+----------------+
          |                                 |
     C# + WPF                      Tauri + React
          |                                 |
   Windows utilities                   Rich apps
          |                                 |
          +---------------+-----------------+
                          |
                       Python
                          |
              Processing / AI engine
                          |
      +---------+---------+---------+---------+
      |         |         |         |         |
   Whisper   PyTorch   Telethon   OpenCV   yt-dlp
                          |
                     FFmpeg / CLI
```

## Core Principle

**Use the best technology for each layer instead of forcing one language or framework to do everything.**

- **C#** owns Windows-native tooling.
- **React/Tauri** owns rich desktop interfaces.
- **Python** owns AI, automation, scraping, and data processing.
- Specialized CLI tools such as **FFmpeg, yt-dlp, 7-Zip, rclone, and ADB** remain dedicated engines.

This approach keeps the applications easier to maintain, more responsive, and easier to grow over time.
