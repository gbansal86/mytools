# VideoHoarder UI Prototype — Final Design Specification

**Status:** approved-direction WPF prototype  
**Backend connection:** none — mock data only  
**Design principle:** Stacher-style workspace efficiency combined with the existing VideoHoarder feature set.

## 1. Locked shell

The primary shell is intentionally small:

**VideoHoarder | File | Downloads | Tools | Download | AI | Library | Subscriptions | Chapters | Operations**

Right side:

- Ctrl+K command palette
- Global activity summary
- Notifications
- Light/Dark toggle
- Settings

There is **no permanent large left navigation rail**. The active mode receives almost the entire application window.

## 2. Download mode

The Download screen follows the interaction pattern requested from the Stacher reference:

- URL / playlist / channel / course / M3U8-HLS entry at the top
- Download profiles and quick quality/subtitle selectors
- secondary settings in dialogs instead of permanent panels
- views: Active, Grid, List, Subscriptions, Log and History
- while downloading: compact job list on the left and a large selected-job console on the right
- queue-wide controls at the bottom

### Profiles

- Full Library
- Fast Download
- Transcript Only
- AI Research
- Media Only
- Audio Only

### Existing VideoHoarder capabilities represented

- Full Library / Media Only / Audio Only
- Best / 1080 / 720 / 480 / 360 quality
- VTT and SRT handling
- subtitles/transcripts
- comments
- Smart Resume
- embedded-video resolution
- playlist/channel intake
- M3U8/HLS / external sources
- browser-cookie fallback
- YouTube 403 fallback/update behavior
- queue workers
- parallel videos
- concurrent fragments
- metadata/info JSON/thumbnail
- pause/resume/retry/cancel/stop-style controls
- full selected-job log
- history and source inspection

![Download](screenshots/01-download-active.png)

### Download options

Settings are opened only when requested. The prototype includes sections for:

- General
- Formats & Quality
- Subtitles & Captions
- Extraction & Cookies
- Queue & Performance
- Automation
- File Naming
- Network & Advanced

![Download Options](screenshots/02-download-options.png)

## 3. AI mode

AI mode keeps processing, review and knowledge work separate from normal downloading.

Pipeline:

**Transcript → Clean → Translate → Analyze → Chapters → Report → Knowledge → Embeddings**

Workspace tabs:

- Jobs
- Results
- Review
- Packages
- Knowledge
- Ask AI
- Semantic Search

It represents current VideoHoarder functionality including local Ollama, ChatGPT exchange/packages, validation, retries, taxonomy/intelligence extraction, knowledge layer rebuilds, embeddings and semantic retrieval.

![AI](screenshots/03-ai.png)

## 4. Library mode

Library becomes the primary browsing and organization surface.

Saved views include:

- All Videos
- New This Week
- Unwatched
- Missing Transcript
- AI Complete
- Favorites
- Failed
- Archived

Main area supports Grid/List/Table, search, filters and bulk selection.

Bulk actions shown in the prototype:

- Play
- Add to collection
- Run AI pipeline
- Export
- Move
- Delete

The right inspector is contextual and collapsible, with:

**Overview | Player | Transcript | Chapters | AI | Files | History**

![Library](screenshots/04-library.png)

## 5. Subscriptions mode

Current provider state is represented honestly:

- **YouTube — Available**
- **Udemy — Planned**
- **RSS / Web — Planned**

The YouTube workspace exposes source selection, new items, downloaded counts, last-check time and per-source rules such as Review First, Auto-download and Download + AI.

![Subscriptions](screenshots/05-subscriptions.png)

## 6. Chapters mode

The Chapters workspace combines:

- video preview/player area
- manual and AI-generated chapter list
- timestamp editor
- split / merge
- AI Chapters
- import/export
- reusable chapter templates
- timeline visualization

This is intended to absorb the chapter-oriented parts of existing report intelligence and work with Clip Studio rather than replacing it.

![Chapters](screenshots/06-chapters.png)

## 7. Operations mode

Operations is the sixth permanent mode so maintenance/recovery features do not crowd daily-use screens.

It groups:

- Import & Repair
- Smart Resume Audit
- Missing Data
- Duplicates
- Cleanup
- Library Health
- Failure History
- Recovery Center
- Diagnostics
- Rebuild & Export
- Dependencies
- Logs
- Unified History

Risky actions use a **Preview → Apply → Undo** interaction pattern wherever technically possible.

![Operations](screenshots/07-operations.png)

## 8. Cross-mode features added to the prototype

### Global Activity

A compact top-right indicator summarizes downloads, AI jobs and warnings. Clicking it opens a temporary cross-mode activity surface rather than consuming permanent workspace.

### Notification Center

Notifications cover:

- completed downloads
- AI review warnings
- subscription discoveries
- health/maintenance warnings

### Command Palette

**Ctrl+K** exposes specialist actions without adding more permanent navigation. Example commands include:

- Rebuild Reports
- Smart Resume Audit
- Create ChatGPT Package
- Find Timestamp
- Open Logs
- Portable Tools Status

### Unified History

One chronological history surface combines download, AI, library, subscription and operations activity.

### Feature-state badges

The UI can explicitly label capabilities as:

- Available
- Experimental
- Planned
- Needs setup

This prevents planned integrations from being mistaken for implemented features.

### Portable tool status

Operations/Dependencies includes status rows for:

- yt-dlp
- FFmpeg
- Deno
- Ollama
- Python packages
- Selenium

### Drag & drop / clipboard / batch intake

The prototype accepts dropped text/files and exposes clipboard/batch actions in Download mode.

### Keyboard shortcuts

- Ctrl+K — command palette
- Ctrl+L — focus Download URL field
- Ctrl+F — current-mode search action
- Ctrl+Shift+V — clipboard import
- Space — pause/resume selected download prototype action
- F5 — refresh current mode
- Ctrl+H — unified history
- Ctrl+J — global activity
- Ctrl+, — settings
- F1 — shortcut reference

### Themes and app-state previews

The prototype supports light/dark switching and explicit preview states:

- Normal
- First Run
- Empty
- Loading
- Offline

The intent is that VideoHoarder should never show an unexplained blank screen.

## 9. Features intentionally not made into new permanent modes

These remain contextual or part of Operations/Tools:

- Settings
- Reports/export
- Failures
- Recovery
- Diagnostics
- Dependencies
- Logs
- Global history
- ChatGPT package administration
- command search

This keeps the primary navigation fixed at six modes.

## 10. Production architecture target

The prototype is intentionally presentation-only. The longer-term production architecture remains:

| Layer | Direction |
|---|---|
| Desktop UI | C# + WPF |
| UI pattern | MVVM |
| Visual language | Windows 11 / Fluent-inspired |
| Processing engine | Existing modular Python |
| Database | SQLite |
| Communication | Local IPC/API |
| Downloads | Existing yt-dlp / FFmpeg integration |
| AI/transcripts | Python |
| Reports | HTML only where appropriate |
| Background work | Dedicated Python worker/job service |
| Packaging | One portable Windows application |

## 11. Prototype portability

The working prototype on the development machine keeps the .NET SDK/runtime and caches under its own `tools` tree.

Repository publication omits the large SDK binaries. `Setup-Portable-Tools.cmd` recreates them locally under the cloned folder, preserving the folder-independent requirement without committing hundreds of megabytes of third-party runtime binaries.

## 12. Acceptance baseline

The design should be considered broken if a future revision:

- restores a permanent large sidebar,
- reduces the active mode to a small center panel,
- permanently displays settings that should open contextually,
- merges Download and Dashboard into the same screen,
- removes existing VideoHoarder capabilities without explicit approval,
- labels planned providers as already implemented,
- or replaces the Stacher-inspired download/log interaction model.

This document is the layout baseline for future implementation work.
