# Start Here - 10-Minute Beginner Guide

This page is for someone who is comfortable double-clicking files but does not normally use Python.

## 1. Keep the whole tool in one folder

Do not run individual Python files from random locations. Keep the package together so its BAT file, Python code, configuration, and private runtime files stay in the same tool folder.

## 2. Install Python

Install Python 3.10 or newer from <https://www.python.org/downloads/windows/>.

After installation, open Command Prompt and test one of these:

```bat
python --version
```

```bat
py --version
```

## 3. Create `channels.txt`

Copy `channels.example.txt` and rename the copy to `channels.txt`.

Example:

```text
# One target per line
@channel_one
https://t.me/channel_two
A Channel I Already Joined
```

The tool never needs your channel list to be published to GitHub.

## 4. Obtain Telegram developer credentials

Go to <https://my.telegram.org/>, sign in, and use **API development tools** to obtain your own `api_id` and `api_hash`.

Do not use someone else's credentials and do not put yours into public screenshots or GitHub commits.

## 5. Double-click `START_DOWNLOAD.bat`

The first run creates a local `.venv` and installs Telethon inside it. This keeps Python dependencies isolated from the rest of your computer.

## 6. Sign in to Telegram

Enter the requested API ID/hash. The public build does not automatically write your API hash to disk. Telethon may request your Telegram verification code and, when enabled on your account, your two-step-verification password.

After a successful login, `telegram_session.session` is created. Keep it private. Advanced users can supply API credentials through `TG_API_ID` / `TG_API_HASH`, or create a private Git-ignored `telegram_settings.json` from the example file.

## 7. Wait for scan/download activity

The tool scans the channels you listed and downloads document/video media it can access. Running it again later is supported; complete files are skipped.

## 8. Find your downloaded files

Look under:

```text
downloads\<channel name>\Videos
downloads\<channel name>\Documents
```

## 9. Review the CSV report

Open `download_report.csv` in Excel or another spreadsheet program. It records the channel, message ID, filename, status, size, local path, and any error reported for attempted media.

## 10. Open the offline archive

When `export_html` is `true`, open:

```text
channel_exports\<channel name>\index.html
```

Use its search box and filter to find messages/captions and locally saved media.

## Before you publish your own fork

Double-click `PREPUBLISH_CHECK.bat` and then inspect `git status --short`. Never publish:

- `telegram_settings.json`
- `telegram_session.session`
- your real `channels.txt`
- `download_report.csv`
- `downloads/`
- `channel_exports/`

For more detail, return to [README.md](README.md).
