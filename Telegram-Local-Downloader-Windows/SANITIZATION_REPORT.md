# Public-Sharing Sanitization Report

## Summary

The supplied archive was reviewed for credentials, authenticated session material, personal/local filesystem data, real Telegram targets, generated runtime data, and obvious code-level injection risks.

## Findings in the supplied archive

### Critical — Telegram API credentials present

`telegram_settings.json` contained a real Telegram API ID and API hash. These values were removed from the public package and replaced by `telegram_settings.example.json` containing placeholders. The real settings filename remains Git-ignored.

Treat the original credentials as exposed. Before publishing the repository, replace/revoke them as appropriate in the Telegram developer account, especially if the original ZIP or repository was ever shared beyond a trusted location.

### High — Download history exposed local and Telegram metadata

`download_report.csv` contained a Windows user-profile path, a real channel name/ID, message IDs, filenames, file sizes, and download history. The report was removed from the public package and `download_report*.csv` is now ignored by Git.

The downloader was also changed to write relative paths into future CSV reports instead of absolute user-profile paths.

### Medium — Real channel target present

`channels.txt` contained a real Telegram channel URL. It was removed and replaced by `channels.example.txt`. The real `channels.txt` is now ignored by Git.

### Low — Generated Python cache included

`__pycache__/` and `.pyc` output were removed and are now ignored.

## Code hardening performed

- Added spreadsheet-formula neutralization for string fields written to `download_report.csv`.
- Changed generated CSV paths from absolute paths to repository-relative paths.
- Changed HTML archive `messages.jsonl` target paths to relative paths while retaining backward compatibility with older absolute-path archives.
- Added a restrictive Content Security Policy to generated offline HTML as defense in depth.
- Removed the Telegram account ID/name from the normal sign-in success console message.
- Expanded `.gitignore` for credentials, sessions, real channel lists, reports, downloads, generated HTML archives, caches, logs, local environments, and editor/OS files.
- Added `PREPUBLISH_CHECK.bat` and `prepublish_check.py` for a dependency-free privacy/secret preflight.
- Added public-safe `README.md`, `SECURITY.md`, examples, and `requirements.txt`.

## Verification performed

- Python syntax compilation: passed.
- CSV formula-injection guard test: passed.
- HTML escaping test using script/image injection strings: passed.
- HTML Content Security Policy presence: passed.
- Relative-path archive test: passed.
- Scan for the specific API credentials, channel identity, and Windows user path found in the original archive: passed (not present).
- Pre-publication checker: passed.

## Important before making a GitHub repository public

1. Use only the sanitized package, not the original ZIP.
2. Run `PREPUBLISH_CHECK.bat`.
3. Run `git status --short` and inspect the staged diff before pushing.
4. Never force-add ignored session, credentials, reports, channel lists, downloads, or channel exports.
5. If any secret was ever committed to Git, purge it from Git history; a later deletion commit is not sufficient.
6. This public release now includes the MIT License (`LICENSE`) as requested by the repository owner.
