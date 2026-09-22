# START HERE — Video Duplicate Finder

This page is for someone who does **not** want to understand the code. Follow these steps in order.

![First-time setup](docs/setup-guide.svg)

## 1. What this tool does

It finds videos that appear to contain the same visual content even when the copies have different:

- file names;
- file sizes;
- resolutions such as 720p and 1080p;
- bitrates;
- containers such as MP4 and MKV;
- codecs;
- small timing differences.

The scanner does **not** delete videos.

## 2. What you need

- Windows 10 or Windows 11.
- Python 3.10 or newer.
- Internet access the first time if FFmpeg is not already available.

No extra Python packages are required.

## 3. First-time setup

Double-click:

```text
INSTALL_FIRST.bat
```

This checks Python and prepares FFmpeg. If FFmpeg is missing, a portable copy is placed inside this tool folder under:

```text
_runtime\ffmpeg\
```

Nothing needs to be permanently added to the Windows PATH for the portable FFmpeg copy.

## 4. Tell the tool where your videos are

Open:

```text
video_paths.txt
```

Put one folder on each line:

```text
D:\Videos
E:\Downloaded Videos
F:\Old Videos
```

All subfolders are included automatically.

Lines beginning with `#` are ignored.

## 5. Scan for duplicates

Double-click:

```text
run_duplicate_scan.bat
```

The first scan can take longer because fingerprints must be created. Later scans reuse the fingerprint cache for unchanged files.

When the scan finishes, look for:

```text
duplicate_groups.txt
duplicate_report.csv
video_fingerprint_cache.json
```

The easiest file to understand is `duplicate_groups.txt`.

## 6. Review duplicate candidates visually

Double-click:

```text
run_duplicate_review.bat
```

Your browser opens a local review page.

![Review page](docs/review-guide.svg)

For each duplicate group:

1. Play both/all videos.
2. Compare the beginning, middle, and end.
3. Decide which copy you want to keep.
4. Tick **Mark for delete** on the unwanted copy.
5. Click **Process Selected**.

Selected files are moved to the **Windows Recycle Bin**, not permanently erased.

## 7. Safety rules built into the review page

- The scanner itself never deletes videos.
- The review page blocks deleting every remaining video in the same duplicate group.
- If you select a **Suggested KEEP** file, it asks for an extra confirmation.
- Deletion attempts are recorded in:
  `deleted_files_log.csv`.
- The browser review server is local-only at `127.0.0.1`.

## 8. If a video does not play in the browser

This is usually a browser codec limitation, not a damaged video.

Use **Open folder** and play the file with your normal media player such as VLC or MPC-HC.

## 9. If FFmpeg is reported missing

Run:

```text
INSTALL_FIRST.bat
```

The scanner checks both the normal Windows PATH and the local:

```text
_runtime\ffmpeg\
```

## 10. If something fails

Look for:

```text
install_log.txt
```

For full explanations, tuning, limitations, and troubleshooting, read:

- [README.md](README.md)
- [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)

## Simple workflow

![Complete workflow](docs/workflow.svg)

> **Recommended practice:** never delete based only on the score. Use the score to find likely duplicates, then visually confirm before processing them.
