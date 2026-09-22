# Troubleshooting

## Python not found

Install Python 3.10+ from <https://www.python.org/downloads/windows/> and reopen Command Prompt. Verify `python --version` or `py --version` works.

## Virtual environment cannot be created

Try running this manually in the tool folder:

```bat
python -m venv .venv
```

If that fails, repair/reinstall Python and ensure the standard `venv` component is installed.

## Telethon installation fails

Check your internet connection and try:

```bat
.venv\Scripts\python.exe -m pip install "telethon>=1.36,<2"
```

`cryptg` is optional. If its binary wheel is unavailable for your Python version, the downloader continues with Telethon's normal crypto implementation.

## `channels.txt` is missing or still has the placeholder

Copy `channels.example.txt` to `channels.txt`, then replace `@your_channel_username` with channels your account can access.

## A channel cannot be resolved

Try, in this order:

1. Public `@username`.
2. Public `https://t.me/...` link.
3. Exact channel title shown in your Telegram dialog list.
4. Exact channel title shown in your Telegram dialog list.

The tool does not use invite links to auto-join channels.

## Telegram verification code / two-step verification

Telethon uses Telegram's normal authentication flow. Enter the verification code sent by Telegram. If your account has two-step verification, Telegram may also request that password.

Never share these values in public logs or screenshots.

## `FloodWait` / Telegram asks the program to wait

Telegram applies server-side rate limits. The downloader respects Telegram's wait instruction. Repeatedly restarting the program can make troubleshooting harder; normally allow the wait to finish.

## Downloads seem slower with more parallel files

`parallel_downloads` can be 1-4. More parallel work is not always faster because performance depends on Telegram rate limits, network bandwidth, storage speed, CPU crypto speed, and file sizes. Try `2` or `3` if `4` is unstable or slower.

## A previously downloaded file is downloaded again

The tool verifies local file presence and expected size when Telegram provides one. If the existing file is incomplete, moved, renamed, or has a different size, it can be downloaded again.

## A photo message is missing

The current code intentionally downloads Telegram document/video media. Ordinary photo-only messages are excluded.

## CSV report opens with strange apostrophes in some cells

That can be intentional. Values beginning with spreadsheet formula characters are prefixed so Excel-like programs do not interpret Telegram-controlled text as a formula.

## Offline HTML shows a message but no local file link

Possible reasons:

- That message had no downloadable document/video.
- Download failed.
- The local file was moved/deleted.
- The local file size no longer matches the expected size.

Check `download_report.csv` and re-run the downloader.

## I deleted credentials from Git but they were committed before

Deleting a file in a new commit does not erase old Git history. Treat exposed API credentials/session files as compromised, rotate/revoke them as appropriate, and purge the secret from repository history before relying on the repository as sanitized.

## Run the built-in privacy check

Double-click:

```text
PREPUBLISH_CHECK.bat
```

A clean public source tree should report `PRE-PUBLISH CHECK PASSED`.
