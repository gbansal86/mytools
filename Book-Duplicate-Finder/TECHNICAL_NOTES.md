# Technical Notes - Book Duplicate Finder

This document explains what the program does internally without requiring you to read the full source code.

## 1. Processing pipeline

For every supported file, the scanner broadly performs the following sequence:

```text
Find file
  -> calculate SHA-256
  -> extract text and/or sampled page images
  -> normalize extracted text
  -> create hashed word-shingle sketch
  -> cache fingerprint in SQLite
  -> generate plausible candidate pairs
  -> calculate pair similarity
  -> classify EXACT / HIGH / PROBABLE / REVIEW
  -> group related matches
  -> write HTML + CSV reports
```

The scanner deliberately separates **candidate generation** from **full pair comparison**. Comparing every document against every other document would become very expensive for a large library.

## 2. Exact duplicate detection

Every file receives a SHA-256 hash. Files with the same SHA-256 value are classified as `EXACT`.

This is the strongest and simplest duplicate case, but it cannot detect a recompressed PDF, a PDF converted to EPUB, or a copy with extra pages.

## 3. Text normalization

Extracted text is lower-cased and simplified before fingerprinting. The normalizer removes or reduces noise such as:

- URLs
- simple `page 12` / `pg 12` forms
- common `12 / 300` style page indicators
- punctuation differences
- standalone numbers
- repeated whitespace

If extracted content is very large, the configured character limit keeps representative text from the beginning, middle, and end instead of keeping only the beginning.

## 4. Word shingles and sketches

Normalized text is split into overlapping groups of words. With the default settings:

- `shingle_words = 5`
- `shingle_step = 2`

Each shingle is hashed to a 64-bit BLAKE2b-derived value. Instead of storing every shingle, the scanner keeps a bounded set of the lowest hash values (`sketch_size`, default 512).

This creates a small content fingerprint that can be compared efficiently.

## 5. Similarity measures

### Jaccard-like sketch overlap

`sketch_jaccard()` estimates how much the two compact content sketches overlap.

### Containment

`containment_from_jaccard()` estimates the fraction of the smaller document's unique shingle population represented by the intersection.

Containment is particularly useful when document B contains nearly all of document A plus an appendix, cover pages, advertisements, or another small section.

### Image similarity

For documents with little extracted text, the scanner can sample pages/images and calculate perceptual hashes (`pHash`).

For each sampled page in the smaller sample set, it finds the closest perceptual-hash match in the other file. A blend of average and center score is used to reduce the effect of accidental blank/common pages.

### Title similarity

Cleaned filenames are compared with RapidFuzz. Title similarity is not enough by itself to declare a duplicate; it mainly helps candidate generation and can rescue a `REVIEW` match when content still has meaningful overlap.

## 6. Candidate generation

The scanner avoids an all-vs-all comparison by creating candidates from several signals:

1. same exact SHA-256
2. shared content-sketch hash values
3. similar filename/title tokens plus plausible word/page-length ratios
4. image fingerprints when text/page counts are unavailable

Very common sketch hashes/tokens are ignored above safety limits so generic content does not create enormous candidate sets.

## 7. Default classifications

The values below come from `settings.ini`.

### HIGH

Text path:

```text
containment >= 0.965 AND jaccard >= 0.72
```

or image path:

```text
image similarity >= 0.90
```

### PROBABLE

Text path:

```text
containment >= 0.90 AND jaccard >= 0.58
```

or image path:

```text
image similarity >= 0.84
```

### REVIEW

Text path:

```text
containment >= 0.80 AND jaccard >= 0.45
```

or image path:

```text
image similarity >= 0.78
```

A strongly matching cleaned title can also rescue a weaker pair into `REVIEW` only when the content/image evidence still meets additional minimums.

These are heuristics, not guarantees.

## 8. Format extraction

| Format | Method |
|---|---|
| PDF | PyMuPDF text extraction; sampled rendered pages when text is scarce |
| EPUB | EbookLib + BeautifulSoup document text |
| DOCX | python-docx paragraphs and table-cell text |
| TXT / HTML / XHTML / FB2 | direct text/HTML parsing |
| RTF | striprtf |
| CHM | extract locally with full 7-Zip, then parse HTML/text files |
| DJVU | DjVuLibre `djvutxt`; page count via `djvused`; sampled rendering via `ddjvu` when needed |
| CBZ | ZIP extraction + sampled images |
| CBR | 7-Zip extraction + sampled images |
| MOBI / AZW / AZW3 | Python `mobi` package; DRM is not bypassed |

## 9. Cache design

Fingerprints are stored in SQLite at:

```text
cache/fingerprints.sqlite
```

The cache key is the full file path. A cached fingerprint is reused only when both file size and nanosecond modification timestamp match the stored values.

This makes repeated scans significantly faster for unchanged libraries.

## 10. Reports

The program generates:

- HTML grouped report for visual review
- CSV of matching pairs for sorting/filtering in Excel or other tools
- CSV of extraction errors

Matched pairs are grouped with a simple disjoint-set/union-find structure. Therefore, a group may contain A, B, and C when A matches B and B matches C even if a direct A-vs-C pair did not cross a reporting threshold. Review groups as collections rather than assuming every pair is identical.

## 11. Dependency bootstrap

`bootstrap.py` intentionally installs Python packages with `pip --target ./deps`.

For CHM/CBR support, it downloads 7-Zip's small extractor and installer, then unpacks the full command-line files locally.

For DJVU support, v1.1 validates downloaded files before extraction. The preferred DjVuLibre Windows setup must look like a real Windows PE file (`MZ` signature plus a reasonable size). The fallback ZIP must pass `zipfile.is_zipfile()`.

This validation prevents an HTML SourceForge redirect/error response from being silently cached as a `.zip` file.

## 12. Tuning advice

Lower thresholds produce more candidate matches and more false positives. Higher thresholds produce cleaner reports but may miss altered editions/scans.

For a first large-library run, keep the defaults. If you later tune them, change one family at a time and compare reports against a manually reviewed sample set.
