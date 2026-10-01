# Downloadly Catalog Manager V30

A Windows desktop cataloging tool that discovers Downloadly posts, maintains a durable SQLite queue, archives source HTML, extracts reportable links/metadata, and publishes CSV, Excel, and searchable HTML catalogs.

## V30 highlights

- Fast HTTP processing with **1–100 selectable workers**; default remains 3.
- **Automatic headless Selenium fallback** when a normal HTTP request receives a verification/block page.
- Selenium recovery is limited to **2 simultaneous browser instances**, even with high HTTP concurrency.
- Items still blocked after the fallback are **deferred instead of freezing the whole queue**.
- Manual GUI sessions can **reattach to an already-running worker** for the same data folder.
- Closing the GUI safely stops a manual worker; force-stop terminates the worker process tree after the grace period.
- Start/Resume clears stale pause/stop/cancel control files.
- Rebuild from saved HTML, duplicate grouping, background scheduling, report buffering, and updater/data preservation remain supported.

## Safety and scope

This project inventories page metadata and links. Headless Selenium is used only as ordinary page rendering/recovery. It does **not** solve CAPTCHAs, bypass explicit human-verification controls, copy browser credentials/cookies, or intentionally download linked course archives/media.

## Quick start

1. Download/extract the V30 package.
2. Double-click `Launch_Downloadly_GUI.vbs`.
3. The private Python environment is created automatically and dependencies (including Selenium) are installed.
4. Existing V23+ users can use **Update from ZIP**; `data`, `runtime`, logs, update backups, support packages, and `config/urls.txt` are preserved.

Recommended starting settings: 3 workers, report every 100 items, report interval 300 seconds, timeout 45 seconds. Increase worker count gradually because very high concurrency can increase site blocking and local resource use.

## Architecture

`Discovery → durable SQLite queue → parallel processing → HTML archive → CSV/XLSX/searchable HTML publishing`

Important paths:
- `data/state/catalog.db` — durable source of truth
- `data/discovery/discovered_items.csv` — discovery queue export
- `data/html_archive/` — saved source HTML
- `data/reports/` — CSV/XLSX output
- `data/catalog/catalog.html` — searchable catalog
- `data/logs/` — run/scheduler/crash logs

## Testing

V30 package test suite: **121 passed** in the build environment.
