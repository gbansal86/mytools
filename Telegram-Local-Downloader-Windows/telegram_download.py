"""Download accessible Telegram channel videos/documents to this PC.

Uses Telethon only to read channel messages and download media. No upload,
forwarding, sending, or automatic channel-joining operations are performed.
"""

import asyncio
import sys
import time
from pathlib import Path

from telethon import TelegramClient
from telethon.errors import FloodWaitError

from channel_html_export import ChannelArchive
from telegram_config import (
    ARCHIVE_ROOT, DOWNLOAD_ROOT, REPORT_FILE, ROOT, SESSION_PATH,
    get_credentials, load_options, read_channels, resolve_channel, safe_part,
)
from telegram_media import duration_text, existing_file, media_info, size_text, write_report
from telegram_progress import Job, Progress

# ---------- Network/download execution ------------------------------------

async def download_one(client, message, job, progress):
    target = job.target
    partial = target.with_name(f"{target.stem}.partial{target.suffix}")
    last_error = None
    for attempt in range(1, 4):
        try:
            partial.unlink(missing_ok=True)
            if attempt > 1:
                print(f"  Retry {attempt}/3")
            progress.restart_file(job)
            result = await client.download_media(
                message, file=str(partial),
                progress_callback=lambda current, total: progress.update(job, current, total)
            )
            if not result:
                raise RuntimeError("Telegram returned no media file")
            actual = Path(result)
            if not actual.exists() or actual.stat().st_size == 0:
                raise RuntimeError("Downloaded file is missing or empty")
            if job.expected_size and actual.stat().st_size != job.expected_size:
                raise RuntimeError(f"Incorrect size: expected {job.expected_size}, got {actual.stat().st_size}")
            actual.replace(target)
            progress._clear_line()
            return target.stat().st_size
        except FloodWaitError as exc:
            last_error = exc
            progress._clear_line()
            print(f"  Telegram rate limit: waiting {exc.seconds + 5}s")
            await asyncio.sleep(exc.seconds + 5)
        except Exception as exc:
            last_error = exc
            progress._clear_line()
            print(f"  Attempt {attempt}/3 failed: {type(exc).__name__}: {exc}")
            if attempt < 3:
                await asyncio.sleep(2 * attempt)
    partial.unlink(missing_ok=True)
    raise RuntimeError(f"Could not download after 3 attempts: {last_error}")


# ---------- Main orchestration --------------------------------------------

async def main():
    print("=" * 65)
    print("TELEGRAM CHANNEL -> WINDOWS | UNLIMITED LOCAL DOWNLOADS")
    print("=" * 65)
    channels = read_channels()
    workers_count, export_html = load_options()
    api_id, api_hash = get_credentials()
    DOWNLOAD_ROOT.mkdir(exist_ok=True)
    counters = {"scanned": 0, "eligible": 0, "already": 0, "channel_errors": 0}
    jobs = []
    archives = []
    total_known_bytes = 0

    async with TelegramClient(str(SESSION_PATH), api_id, api_hash) as client:
        await client.get_me()
        print("Telegram sign-in successful.")
        print(f"Download folder: {DOWNLOAD_ROOT}")
        print("\nPHASE 1/2: Scanning channel histories and counting all files...")
        print("The total becomes available after the scan finishes. Scanning can take time.")
        for raw in channels:
            print(f"\nScanning: {raw}")
            scanned_here = 0
            try:
                entity = await resolve_channel(client, raw)
                title = getattr(entity, "title", None) or getattr(entity, "username", None) or raw
                channel_id = int(entity.id)
                folder_name = f"{safe_part(title, 75)}_{channel_id}"
                folder = DOWNLOAD_ROOT / folder_name
                archive = (ChannelArchive(ARCHIVE_ROOT, folder_name, title, channel_id,
                           getattr(entity, "username", None)) if export_html else None)
                if archive:
                    archive.start()
                    archives.append(archive)
                try:
                    async for message in client.iter_messages(entity, limit=None):
                        counters["scanned"] += 1
                        scanned_here += 1
                        if scanned_here % 200 == 0:
                            print(f"  Scanning... {scanned_here} messages, {counters['eligible']} media files found", flush=True)
                        info = media_info(message)
                        target = folder / info[0] / info[1] if info else None
                        if archive:
                            archive.record(message, info, target)
                        if info is None:
                            continue
                        counters["eligible"] += 1
                        category, filename, size = info
                        if existing_file(target, size):
                            counters["already"] += 1
                            continue
                        jobs.append(Job(entity, title, channel_id, message.id, filename, size, target))
                        total_known_bytes += size
                finally:
                    if archive:
                        archive.close()
                print(f"  Scanned {scanned_here} messages in {title}.")
                if archive:
                    summary = archive.render()
                    print(f"  HTML created: {summary['page']} ({summary['messages']} messages)")
            except Exception as exc:
                counters["channel_errors"] += 1
                print(f"  CHANNEL ERROR: {type(exc).__name__}: {exc}")
                print("  Verify its name, your account's access, and the channel saving settings.")

        progress = Progress(len(jobs), total_known_bytes, counters["already"])
        print(f"\nPHASE 2/2: Downloading with {workers_count} simultaneous file(s)...")
        print(f"Media messages found: {counters['eligible']} | Already present: {counters['already']}")
        print(f"Files to download: {len(jobs)} | Known download size: {size_text(total_known_bytes)}")
        # A small worker pool uses the SAME authenticated Telegram client.
        # No account sharing, channel forwarding, or aggressive unbounded concurrency.
        pending = asyncio.Queue()
        for job in jobs:
            pending.put_nowait(job)

        async def worker():
            while True:
                try:
                    job = pending.get_nowait()
                except asyncio.QueueEmpty:
                    return
                try:
                    if existing_file(job.target, job.expected_size):
                        progress.finished += 1
                        progress.already_present += 1
                        progress._clear_line()
                        print(f"Already saved: {job.filename}")
                        progress._render(force=True)
                        continue
                    job.target.parent.mkdir(parents=True, exist_ok=True)
                    progress.start_file(job)
                    row = dict(channel=job.channel, channel_id=job.channel_id,
                               message_id=job.message_id, file_name=job.filename,
                               size_bytes=job.expected_size, status="",
                               local_path=str(job.target.relative_to(ROOT)), error="")
                    try:
                        message = await client.get_messages(job.entity, ids=job.message_id)
                        if message is None or message.document is None:
                            raise RuntimeError("Message is no longer available or has no downloadable media")
                        actual_size = await download_one(client, message, job, progress)
                        row["status"] = "downloaded"
                        progress.end_file(True, job, actual_size)
                    except Exception as exc:
                        error = f"{type(exc).__name__}: {exc}"
                        row["status"] = "failed"
                        row["error"] = error
                        progress.end_file(False, job, error=error)
                    write_report(row)
                finally:
                    pending.task_done()

        await asyncio.gather(*(worker() for _ in range(min(workers_count, len(jobs)))))
        progress._clear_line()

        if archives:
            print("\nUpdating HTML links for completed local downloads...")
            for archive in archives:
                try:
                    summary = archive.render()
                    print(f"  {summary['page']} | {summary['messages']} messages | {summary['saved']} saved-file links")
                except Exception as exc:
                    print(f"  HTML update failed for {archive.title}: {type(exc).__name__}: {exc}")

        print("\n" + "=" * 65)
        print("FINISHED")
        print(f"Channel messages scanned: {counters['scanned']}")
        print(f"Media files found: {counters['eligible']}")
        print(f"Downloaded this run: {progress.downloaded}")
        print(f"Already downloaded: {progress.already_present}")
        print(f"Failed downloads: {progress.failed}")
        print(f"Channel scan errors: {counters['channel_errors']}")
        print(f"Elapsed time: {duration_text(time.monotonic() - progress.started)}")
        print(f"Files: {DOWNLOAD_ROOT}")
        print(f"Report: {REPORT_FILE}")
        if archives:
            print(f"Searchable channel HTML: {ARCHIVE_ROOT}")
        print("Nothing was uploaded or forwarded to Telegram.")
        if progress.failed:
            print("Run START_DOWNLOAD.bat again to retry files that failed.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, EOFError):
        print("\nStopped. Run START_DOWNLOAD.bat again; completed files are skipped.")
    except Exception as exc:
        print(f"\nERROR: {type(exc).__name__}: {exc}")
        sys.exit(1)
