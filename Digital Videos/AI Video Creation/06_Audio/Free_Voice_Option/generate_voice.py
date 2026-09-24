#!/usr/bin/env python3
"""No-cost online Edge voice sample. Audio is a draft until listened to and approved."""
import argparse
import asyncio
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VOICES = {"andrew": "en-US-AndrewNeural", "brian": "en-US-BrianNeural", "guy": "en-US-GuyNeural"}

def duration_seconds(path):
    try:
        result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                 "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
                                check=True, capture_output=True, text=True, timeout=20)
        return round(float(result.stdout.strip()), 3)
    except (OSError, ValueError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return None

async def generate(text, voice, rate, output):
    try:
        import edge_tts
    except ImportError as exc:
        raise SystemExit("Missing edge-tts. Run START_FREE_VOICE.bat or: py -m pip install -U edge-tts") from exc
    await edge_tts.Communicate(text=text, voice=voice, rate=rate).save(str(output))

def main():
    parser = argparse.ArgumentParser(description="Generate a free-access expert-style narration sample")
    parser.add_argument("--voice", choices=VOICES, default="andrew")
    parser.add_argument("--rate", default="-5%", help="Speaking rate, e.g. -5%%; do not speed up to force scene length")
    parser.add_argument("--text", type=Path, default=ROOT / "scene01_narration.txt")
    parser.add_argument("--outdir", type=Path, default=ROOT / "output")
    args = parser.parse_args()
    text = args.text.read_text(encoding="utf-8-sig").strip()
    if not text:
        raise SystemExit("Narration file is empty.")
    args.outdir.mkdir(parents=True, exist_ok=True)
    outfile = args.outdir / f"scene01_{args.voice}_EXPERT_VOICE_SAMPLE.mp3"
    try:
        asyncio.run(generate(text, VOICES[args.voice], args.rate, outfile))
    except Exception as exc:
        print(f"Voice generation failed: {exc}", file=sys.stderr)
        print("Check internet access and service availability. No paid fallback is used.", file=sys.stderr)
        return 2
    if not outfile.exists() or outfile.stat().st_size < 1000:
        print("No usable audio was produced; do not mark the scene as voiced.", file=sys.stderr)
        return 3
    seconds = duration_seconds(outfile)
    report = {
        "file": str(outfile), "voice": VOICES[args.voice], "rate": args.rate,
        "text": text, "duration_seconds": seconds, "scene_duration_seconds": 10.0,
        "voice_review": "PENDING — listen for confident technical expertise and a human cadence",
        "sync_review": "PENDING — do not force playback speed to fit",
        "license_review": "PENDING — verify your intended use is permitted by the service",
    }
    report_path = args.outdir / f"scene01_{args.voice}_voice_review.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Voice MP3: {outfile}")
    print(f"Review report: {report_path}")
    if seconds is None:
        print("ffprobe unavailable; duration has not been measured.")
    else:
        print(f"Measured speech: {seconds:.3f}s, video scene: 10.000s")
        if seconds > 10:
            print("Audio is longer than the scene. Adjust text or scene timing; do not rush the voice.")
    print("Listen to the MP3. Upload it in this chat for review and synchronization.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
