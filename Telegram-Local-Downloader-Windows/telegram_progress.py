"""Console progress model used by parallel Telegram downloads."""

import time
from dataclasses import dataclass
from pathlib import Path

from telegram_media import duration_text, size_text

# ---------- Download job/progress models ----------------------------------

@dataclass
class Job:
    entity: object
    channel: str
    channel_id: int
    message_id: int
    filename: str
    expected_size: int
    target: Path


class Progress:
    """One throttled CMD status line tracking parallel file transfers."""

    def __init__(self, total_files, total_known_bytes, already_present):
        self.total_files = total_files
        self.total_known_bytes = total_known_bytes
        self.already_present = already_present
        self.finished = 0
        self.downloaded = 0
        self.failed = 0
        self.completed_bytes = 0
        self.started = time.monotonic()
        self.active = {}
        self.last_line_len = 0
        self.last_render = 0

    def _clear_line(self):
        if self.last_line_len:
            print("\r" + " " * self.last_line_len + "\r", end="", flush=True)
            self.last_line_len = 0

    def start_file(self, job):
        self.active[id(job)] = {"job": job, "current": 0, "total": job.expected_size,
                                "started": time.monotonic(), "updated": time.monotonic()}
        self._clear_line()
        print(f"START: {job.filename}", flush=True)
        self._render(force=True)

    def restart_file(self, job):
        state = self.active[id(job)]
        state["current"] = 0
        state["started"] = time.monotonic()
        state["updated"] = time.monotonic()

    def update(self, job, current, total):
        state = self.active.get(id(job))
        if state is None:
            return
        state["current"] = max(0, int(current or 0))
        state["total"] = max(int(total or 0), job.expected_size)
        state["updated"] = time.monotonic()
        self._render()

    def _render(self, force=False):
        now = time.monotonic()
        if not force and now - self.last_render < 0.65:
            return
        self.last_render = now
        running_bytes = sum(item["current"] for item in self.active.values())
        elapsed = max(now - self.started, 0.01)
        average_speed = (self.completed_bytes + running_bytes) / elapsed
        total_eta = ((self.total_known_bytes - self.completed_bytes - running_bytes) / average_speed
                     if self.total_known_bytes and average_speed > 0 else None)
        pct = self.finished * 100 / self.total_files if self.total_files else 100
        if self.active:
            state = max(self.active.values(), key=lambda x: x["updated"])
            current, total = state["current"], state["total"]
            percent = current * 100 / total if total else 0
            file_elapsed = max(now - state["started"], 0.01)
            file_speed = current / file_elapsed
            file_eta = (max(0, total-current) / file_speed if total and file_speed > 0 else None)
            filename = state["job"].filename[:32]
            line = (f"ACTIVE {len(self.active)} | {filename} {percent:4.1f}% "
                    f"{size_text(current)}/{size_text(total)} {size_text(file_speed)}/s "
                    f"ETA {duration_text(file_eta)} | ALL {self.finished}/{self.total_files} "
                    f"({pct:.1f}%) {size_text(average_speed)}/s total ETA {duration_text(total_eta)}")
        else:
            line = f"ALL {self.finished}/{self.total_files} ({pct:.1f}%) | {size_text(average_speed)}/s"
        line = line[:180]
        print("\r" + line + " " * max(0, self.last_line_len-len(line)), end="", flush=True)
        self.last_line_len = len(line)

    def end_file(self, success, job, actual_size=0, error=""):
        self._clear_line()
        self.active.pop(id(job), None)
        self.finished += 1
        if success:
            self.downloaded += 1
            self.completed_bytes += job.expected_size or actual_size
            print(f"SAVED: {job.target}")
        else:
            self.failed += 1
            print(f"FAILED: {job.filename} | {error}")
        print(f"OVERALL: processed {self.finished}/{self.total_files} | new {self.downloaded} | "
              f"failed {self.failed} | already present {self.already_present} | "
              f"elapsed {duration_text(time.monotonic()-self.started)}", flush=True)
        self._render(force=True)
