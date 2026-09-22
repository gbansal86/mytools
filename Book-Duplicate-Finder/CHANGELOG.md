# Changelog

## v1.1

- Added validation for DjVuLibre downloads before extraction.
- Invalid cached DjVu downloads are automatically removed instead of being reused forever.
- Preferred DjVuLibre path uses the current Windows setup package unpacked locally with 7-Zip.
- Added an older official portable ZIP as a fallback source.
- Kept dependencies/helper tools local to the application folder where practical.
- Added beginner-oriented GitHub documentation and source annotations.

## v1.0

- Initial content-aware duplicate scanner.
- Exact SHA-256 detection.
- Cross-format text fingerprinting using hashed word shingles/sketches.
- Containment and similarity scoring.
- Page-image perceptual hashing for low-text scans/comics.
- SQLite fingerprint cache.
- HTML and CSV reports.
