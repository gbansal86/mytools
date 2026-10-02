from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

PHASES = [
    ("ANALYZED", "analyze"),
    ("TRANSCRIBED", "transcribe"),
    ("PLANNING_REQUIRED", "planning"),
]

def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))

def save_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")

def set_state(project: Path, state_name: str, message: str = "") -> None:
    p = project / "project_state.json"
    state = load_json(p)
    state["state"] = state_name
    state["message"] = message
    save_json(p, state)

def source_video(project: Path) -> Path:
    files = [p for p in (project / "01_SOURCE").iterdir() if p.is_file()]
    if not files:
        raise RuntimeError("No source video in 01_SOURCE")
    return files[0]

def require_exe(name: str) -> str:
    exe = shutil.which(name)
    if not exe:
        raise RuntimeError(f"Required executable not found on PATH: {name}")
    return exe

def analyze(project: Path) -> None:
    ffprobe = require_exe("ffprobe")
    src = source_video(project)
    cmd = [
        ffprobe, "-v", "error",
        "-show_format", "-show_streams",
        "-of", "json", str(src)
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    probe = json.loads(result.stdout)

    out = project / "02_ANALYSIS" / "media_probe.json"
    save_json(out, probe)

    video = next((s for s in probe.get("streams", []) if s.get("codec_type") == "video"), {})
    audio = next((s for s in probe.get("streams", []) if s.get("codec_type") == "audio"), {})
    duration = probe.get("format", {}).get("duration")

    summary = [
        "# Analysis Summary",
        "",
        f"- Source: {src.name}",
        f"- Duration: {duration}",
        f"- Resolution: {video.get('width')}x{video.get('height')}",
        f"- Frame rate: {video.get('r_frame_rate')}",
        f"- Video codec: {video.get('codec_name')}",
        f"- Audio codec: {audio.get('codec_name')}",
        f"- Audio sample rate: {audio.get('sample_rate')}",
        "",
        "Next: extract audio and create transcript.",
    ]
    (project / "02_ANALYSIS" / "analysis_summary.md").write_text(
        "\n".join(summary), encoding="utf-8"
    )
    set_state(project, "ANALYZED", "Technical analysis completed.")

def extract_audio(project: Path) -> Path:
    ffmpeg = require_exe("ffmpeg")
    src = source_video(project)
    wav = project / "03_AUDIO" / "source_audio.wav"
    cmd = [
        ffmpeg, "-y", "-i", str(src),
        "-vn", "-ac", "1", "-ar", "16000",
        "-c:a", "pcm_s16le", str(wav)
    ]
    subprocess.run(cmd, check=True)
    return wav

def transcribe(project: Path) -> None:
    wav = extract_audio(project)
    txt = project / "04_TRANSCRIPT" / "raw_transcript.txt"
    js = project / "04_TRANSCRIPT" / "raw_transcript.json"

    try:
        from faster_whisper import WhisperModel
    except Exception:
        txt.write_text(
            "Automatic transcription unavailable. Install faster-whisper or place "
            "a timestamped transcript in this folder, then ask ChatGPT to create "
            "05_PLAN/execution_plan.json using CHATGPT_PLANNER_PROMPT.md.\n",
            encoding="utf-8"
        )
        save_json(js, {"status": "transcription_required", "audio": str(wav.name)})
        set_state(project, "PLANNING_REQUIRED", "Transcript needs to be supplied/aligned.")
        return

    model = WhisperModel("small", device="cpu", compute_type="int8")
    segments, info = model.transcribe(str(wav), vad_filter=True)

    rows = []
    lines = []
    for seg in segments:
        row = {
            "start": round(seg.start, 3),
            "end": round(seg.end, 3),
            "text": seg.text.strip()
        }
        rows.append(row)
        lines.append(f"[{seg.start:0.3f} --> {seg.end:0.3f}] {seg.text.strip()}")

    save_json(js, {"language": info.language, "segments": rows})
    txt.write_text("\n".join(lines), encoding="utf-8")
    set_state(project, "PLANNING_REQUIRED", "Transcript ready; ChatGPT planning required.")

def status(project: Path) -> None:
    state = load_json(project / "project_state.json")
    print(json.dumps(state, indent=2))

def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: python pipeline.py <project-folder> <analyze|transcribe|status>")
        raise SystemExit(2)

    project = Path(sys.argv[1]).resolve()
    action = sys.argv[2].lower()

    if action == "analyze":
        analyze(project)
    elif action == "transcribe":
        transcribe(project)
    elif action == "status":
        status(project)
    else:
        raise SystemExit(f"Unknown action: {action}")

if __name__ == "__main__":
    main()
