# Book Duplicate Finder

A Windows-friendly Python utility for finding **exact and near-duplicate books/documents by content**, not merely by filename or file size.

It is meant for collections where the same book may exist as a PDF, EPUB, CHM, DJVU, MOBI/AZW, DOCX, text file, or comic archive, and where one copy may have a different cover, different compression, extra pages, missing pages, or a slightly different OCR/text layer.

> **Safety:** the tool does **not** delete, move, rename, or overwrite your books. It only scans, caches fingerprints, and creates reports for you to review.

## What problem does it solve?

Normal duplicate finders are excellent when two files are byte-for-byte identical. They are much less useful when the files contain the same book but are technically different files.

Example:

| File | What changed? | Ordinary SHA-256 duplicate check | This tool |
|---|---|---:|---:|
| `Book.pdf` vs copied `Book.pdf` | Nothing | Finds it | Finds it |
| `Book.pdf` vs recompressed PDF | Compression | Misses it | Can find it |
| `Book.pdf` vs `Book.epub` | Different format | Misses it | Can find it |
| 320-page copy vs 326-page copy | Extra pages | Misses it | Can flag high containment |
| Scanned PDF vs scanned DJVU | Container/scan encoding | Misses it | Can use sampled page-image fingerprints |

## Supported / attempted formats

- PDF
- EPUB
- CHM
- DJVU / DJV
- MOBI / AZW / AZW3
- FB2
- TXT
- RTF
- HTML / HTM / XHTML
- DOCX
- CBZ / CBR

Some formats depend on helper tools or on the file not being DRM-protected/corrupted. Extraction failures are recorded in `results\scan_errors_*.csv` rather than stopping the whole scan.

## Requirements

You only need to install **Python 3** yourself.

Recommended:

- Windows 10 or Windows 11
- Python 3.10+ (newer supported Python 3 releases should generally work)
- Internet access on the first run so Python packages and optional local helper tools can be downloaded
- Enough free disk space for local dependencies, temporary extraction, cache, and reports

The launcher intentionally keeps downloaded components inside this tool folder whenever possible.

## Folder layout

Before the first run:

```text
Book-Duplicate-Finder/
├─ RUN.bat                      <- double-click this
├─ bootstrap.py                 <- installs/updates local dependencies
├─ book_duplicate_finder.py     <- scanner and matching logic
├─ search_paths.txt             <- folders you WANT to scan
├─ exclude_paths.txt            <- folders you DO NOT want to scan
├─ settings.ini                 <- thresholds and scanner settings
├─ requirements-local.txt       <- Python packages
├─ README.md
├─ TECHNICAL_NOTES.md
├─ TROUBLESHOOTING.md
└─ CHANGELOG.md
```

After the first run, additional folders are created automatically:

```text
deps/       local Python packages
tools/      local helper programs such as 7-Zip / DjVuLibre
downloads/  downloaded installer/archive cache
cache/      SQLite fingerprint cache
results/    HTML and CSV reports
```

These generated folders are intentionally excluded from Git.

## Quick start for non-technical users

### Step 1 - Download the tool

Download or clone this repository, then open the `Book-Duplicate-Finder` folder.

### Step 2 - Tell it where your books are

Open `search_paths.txt` in Notepad. Put **one folder per line**.

Example:

```text
D:\Books
E:\Ebooks
F:\PDF Collection
```

Quotes are optional. Blank lines and lines beginning with `#` are ignored.

### Step 3 - Optionally exclude folders

Open `exclude_paths.txt` and add folders you do not want scanned.

Example:

```text
D:\Books\Already Reviewed
E:\Ebooks\Temporary
```

### Step 4 - Run it

Double-click:

```text
RUN.bat
```

The launcher checks for Python 3 and then runs `bootstrap.py`.

### Step 5 - First-run installation

The bootstrap performs four visible stages:

1. **Local Python dependencies** - packages are placed under `deps\`.
2. **Local CHM/CBR support** - full 7-Zip command-line files are unpacked under `tools\`.
3. **Local DJVU support** - DjVuLibre command-line tools are unpacked under `tools\`.
4. **Scan** - the actual document scan begins.

If an optional helper download fails, other supported formats can still continue.

### Step 6 - Read the report

When the scan ends, the main HTML report normally opens automatically.

Reports are saved under `results\`:

```text
duplicate_report_YYYYMMDD_HHMMSS.html
duplicate_pairs_YYYYMMDD_HHMMSS.csv
scan_errors_YYYYMMDD_HHMMSS.csv
```

## How to read the result

The main classifications are:

| Class | Plain-English meaning |
|---|---|
| `EXACT` | The files have the same SHA-256 content hash. |
| `HIGH` | Very strong content or page-image similarity. |
| `PROBABLE` | Strong evidence that the files are the same/near-same document. |
| `REVIEW` | Similar enough to inspect manually; do not assume it is safe to delete. |

The report also shows:

- file path
- format
- file size
- page count when available
- extracted word count
- content containment
- Jaccard/sketch similarity
- image similarity where applicable
- title similarity
- a simple hint when one file appears to have more pages or substantially more extracted words

### What is “containment”?

Containment answers a useful question for different editions/copies:

> “How much of the smaller document appears to exist inside the larger document?”

This is why a 320-page book and a 326-page copy can still be recognized even though they are not identical.

### What is “Jaccard” here?

The scanner breaks normalized text into overlapping word groups, hashes those groups, and keeps a compact sketch. Jaccard-like similarity estimates how much those content fingerprints overlap.

You do not need to understand the math to use the report; higher percentages mean stronger overlap.

## Incremental scans / why later runs are faster

Fingerprints are cached in:

```text
cache\fingerprints.sqlite
```

If a file's path, size, and modification timestamp have not changed, its saved fingerprint is reused on later runs.

To force a completely fresh scan, close the program and delete `cache\fingerprints.sqlite`. The next run will rebuild it.

## Important limitations

- A similarity match is **not** a deletion recommendation.
- Different editions can share most text while still containing meaningful changes.
- Poor OCR can reduce text-based similarity.
- Image-based PDFs/DJVUs are sampled rather than OCRing every page.
- Blank/common pages can occasionally look visually similar; the image scorer tries to reduce this effect but cannot eliminate it completely.
- EPUB “page counts” are not fixed in the same way as PDF pages, so page count may be unavailable.
- DRM-protected Kindle books are not decrypted by this tool.
- Corrupted archives/documents may appear in the error CSV.

## Configuration

Most users should start with the defaults in `settings.ini`.

Useful settings include:

- `extensions` - file types to scan
- `min_file_size` - ignore tiny files
- `max_text_chars` - maximum normalized text retained per document
- `sketch_size` - size of the content fingerprint
- `image_samples` - number of sampled images/pages for image-heavy files
- `low_text_chars` - when to fall back toward image comparison
- `high_*`, `probable_*`, `review_*` - classification thresholds
- `open_report_after_scan` - automatically open the HTML report

See [TECHNICAL_NOTES.md](./TECHNICAL_NOTES.md) before changing similarity thresholds.

## Troubleshooting

Common problems, including the old `djvulibre-win32.zip` / “File is not a zip file” issue, are documented in [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## Privacy and safety

Scanning is performed locally on your computer. The tool does not intentionally upload your book contents anywhere. Internet access is used by the bootstrap to download Python dependencies and optional helper programs.

The scanner opens source files for reading and writes only to its own generated `cache\` and `results\` areas (plus temporary extraction directories managed by Python/Windows).

## Third-party components

The bootstrap can download/use:

- **7-Zip** for CHM/CBR extraction. See the 7-Zip project for its licensing terms.
- **DjVuLibre** for DJVU text/page processing. See the DjVuLibre project for its licensing terms.
- Python packages listed in `requirements-local.txt`, each under its own upstream license.

Those third-party projects are not bundled in this Git repository; the bootstrap downloads them locally when needed.

## Version

Current package version documented here: **v1.1**.

The v1.1 bootstrap fixes the earlier DjVuLibre download-cache problem where an HTML redirect/error page could be saved with a `.zip` extension and then reused on later runs.
