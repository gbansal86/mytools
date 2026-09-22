# Security and Privacy Notes

This project handles Telegram authentication and user-accessible channel data, so the distinction between **source code** and **runtime data** is important.

## Never publish these runtime files

- `telegram_settings.json`
- `telegram_session*` / `*.session*`
- `.env` files containing credentials
- `channels.txt` when it contains your real channel list
- `download_report*.csv`
- `downloads/`
- `channel_exports/`
- logs containing local paths, Telegram identifiers, or account details

Telegram session files are especially sensitive because they represent an authenticated login session. Treat them like credentials.

## Built-in safeguards

The repository includes `.gitignore`, `PREPUBLISH_CHECK.bat`, and `prepublish_check.py` to reduce accidental exposure. These are guardrails, not a substitute for reviewing what you commit.

Before a public push:

1. Run `PREPUBLISH_CHECK.bat`.
2. Run `git status --short`.
3. Inspect the staged diff.
4. Confirm no real credentials/session/channel list/output files are staged.

## If a secret was committed

Deleting the file in a later commit does not remove it from Git history. Purge the secret from repository history and replace/revoke the exposed credential or session as appropriate before relying on the repository as sanitized.

## Generated HTML/JSONL archives

Channel exports can contain message text/captions, channel identifiers, message IDs, filenames, and local archive metadata. They are runtime data, not source code, and should remain private by default.

## CSV safety

The downloader neutralizes cells beginning with spreadsheet formula characters before writing `download_report.csv`. This reduces formula-injection risk when a report containing Telegram-controlled channel titles or filenames is opened in spreadsheet software.

## HTML safety

The local archive HTML escapes message text, titles, and filenames, percent-encodes local path segments, and includes a restrictive Content Security Policy. The generated archive is still private data and should not be automatically published.

## Responsible use

Use this utility only for Telegram content that your account is legitimately authorized to access and archive. The code is not designed to bypass Telegram access controls or protected-content restrictions.

## License vs. security

The source code is MIT licensed. The MIT license grants broad rights to use/modify/redistribute the source; it does **not** grant rights to private Telegram content, third-party copyrighted files, credentials, or account/session data processed by the tool.
