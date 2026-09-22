# Troubleshooting - Book Duplicate Finder

## `Python 3 was not found`

Install Python 3 from the official Python website. During Windows setup, enable the option to add Python to `PATH`, then open a new Command Prompt or rerun `RUN.bat`.

You can verify Python with either:

```bat
py -3 --version
```

or:

```bat
python --version
```

## `search_paths.txt has no active folders`

Open `search_paths.txt` and add at least one real folder, one per line:

```text
D:\Books
E:\Ebooks
```

Do not add individual book filenames there; add folders.

## `Search path does not exist`

Check for spelling mistakes, disconnected USB/external drives, changed drive letters, or unavailable network shares.

## First run is slow

This is expected. The first run may download dependencies and has to extract/fingerprint every supported file. Later runs reuse `cache\fingerprints.sqlite` for unchanged files.

## `Could not install local 7-Zip`

PDF/EPUB/etc. scanning can still continue, but CHM/CBR extraction may be unavailable.

Check:

- internet connection
- firewall/proxy restrictions
- antivirus blocking downloaded executables
- write permission to the tool folder

You can delete the tool's `downloads\` and `tools\7zip\` folders and rerun `RUN.bat` to force a clean local helper download.

## `File is not a zip file` for DjVuLibre

This was the main v1.0 bootstrap issue. A SourceForge web/redirect/error page could be saved as `djvulibre-win32.zip`, and the old installer treated any sufficiently large cached file as a completed download.

**v1.1 fixes this** by validating cached/downloaded files before extraction and removing the invalid old cache automatically.

If you still have a problem:

1. Close the scanner.
2. Delete the local `downloads\` folder.
3. Delete `tools\djvulibre\` if it exists.
4. Run `RUN.bat` again.

Other formats can still be scanned if DjVuLibre installation fails.

## DJVU files show extraction errors

Look for `djvutxt.exe`, `ddjvu.exe`, and `djvused.exe` somewhere under:

```text
tools\djvulibre\
```

If they are missing, delete `downloads\` and `tools\djvulibre\`, then rerun the launcher with internet access.

## CHM files show extraction errors

The scanner requires the **full** `7z.exe` plus its local DLLs. It intentionally does not rely on the limited standalone `7za.exe` build.

Check that `7z.exe` and `7z.dll` exist somewhere under:

```text
tools\7zip\
```

Then rerun the scan.

## MOBI/AZW/AZW3 fails

Kindle containers vary. The Python `mobi` package may not parse every file, and DRM-protected content is not decrypted by this scanner.

The failure should be recorded in `results\scan_errors_*.csv` while the rest of the library continues.

## A scanned PDF is not detected as similar

Possible reasons:

- sampled pages differ significantly
- one scan has borders/rotation/cropping/watermarks
- the files have enough bad OCR text to stay primarily on the text path
- the duplicate threshold is too strict for that pair
- image sampling missed corresponding pages

You can cautiously increase `image_samples` or lower the `review_image_similarity` threshold in `settings.ini`, but this can also increase false positives.

## Too many false positives

Raise `review_containment`, `review_jaccard`, and/or `review_image_similarity` slightly. Do not change all thresholds dramatically at once.

Also remember that a duplicate **group** can be transitive: A can match B and B can match C, creating one group even when A and C are less similar.

## Too few matches

Possible options:

- lower review/probable thresholds gradually
- lower `minimum_shared_sketch_hashes` (broader/slower candidate generation)
- increase `sketch_size`
- increase `image_samples` for scanned libraries

Make one change at a time and compare against a known test set.

## Report did not open automatically

Open the newest file manually from:

```text
results\duplicate_report_*.html
```

Also verify this setting:

```ini
[output]
open_report_after_scan = yes
```

## Need a complete rescan

Delete:

```text
cache\fingerprints.sqlite
```

Do not delete the source books. The cache database contains fingerprints only.

## Antivirus warning

The script downloads command-line helper executables from upstream projects and invokes them locally. Some security tools treat newly downloaded executables or scripts cautiously.

Review the URLs in `bootstrap.py`, scan the files with your normal security software, and do not bypass organizational security policy if the machine is managed.

## Where are errors recorded?

Open the newest:

```text
results\scan_errors_*.csv
```

It contains the original file path, extension, and extraction exception so failed formats/files can be diagnosed without stopping the entire scan.
