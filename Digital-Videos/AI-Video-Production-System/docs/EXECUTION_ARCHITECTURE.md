# Execution Architecture

## Who decides what to do?

The system has two layers:

1. **Creative Director / Planner (ChatGPT)**
   - understands the raw video,
   - selects the hook,
   - decides what speech to keep,
   - decides which explanatory visuals are needed,
   - decides exactly when each visual starts and ends,
   - chooses subtitle emphasis,
   - chooses the ending,
   - writes `execution_plan.json`.

2. **Deterministic Local Executor (Python + FFmpeg)**
   - creates the Video Project folder,
   - probes media,
   - extracts audio,
   - transcribes/alignment when a local model is available,
   - prepares images,
   - executes the approved timeline,
   - renders,
   - runs QA,
   - saves every intermediate and final artifact,
   - resumes after a crash without starting from zero.

The local executor does not invent editorial decisions. The plan controls the render.

## Pipeline state machine

```
NEW
  ↓
INGESTED
  ↓
ANALYZED
  ↓
TRANSCRIBED
  ↓
PLANNING_REQUIRED
  ↓
PLAN_READY
  ↓
ASSETS_READY
  ↓
TIMELINE_READY
  ↓
RENDERING
  ↓
QA
  ├── FAIL → FIX_REQUIRED → RENDERING
  └── PASS → COMPLETE
```

Every state is persisted in `project_state.json`.

## Phase 0 — Create Video Project

Input:
- raw video,
- optional branding/logo,
- optional reference style pack.

Output:
- a new project directory with a unique project id,
- source copied or linked into `01_SOURCE`,
- `project_manifest.json`,
- `project_state.json`.

## Phase 1 — Technical analysis

Tools:
- FFprobe,
- Python.

Collect:
- duration,
- codec,
- width/height,
- fps,
- audio streams,
- sample rate,
- bitrate,
- rotation,
- container metadata.

Outputs:
- `02_ANALYSIS/media_probe.json`,
- `02_ANALYSIS/analysis_summary.md`.

## Phase 2 — Audio + transcript

Tools:
- FFmpeg for audio extraction,
- Faster-Whisper / WhisperX when installed,
- otherwise ChatGPT transcription/manual transcript may be supplied.

Outputs:
- `03_AUDIO/source_audio.wav`,
- `04_TRANSCRIPT/raw_transcript.json`,
- `04_TRANSCRIPT/raw_transcript.txt`.

The transcript must contain timestamps.

## Phase 3 — Creative planning

The Planner reads:
- analysis summary,
- transcript,
- style configuration,
- source-frame contact sheet,
- user instructions.

It writes:
- `05_PLAN/execution_plan.json`,
- `05_PLAN/execution_plan.md`.

The plan contains:
- final target duration,
- opening hook,
- source segments to keep,
- source segments to remove,
- final audio order,
- every context image request,
- every image start/end condition,
- subtitle rules,
- logo placement,
- transitions,
- ending cards,
- QA checkpoints.

This is the single source of truth.

## Phase 4 — Asset creation

For every planned visual, create an entry in:
`06_ASSETS/asset_manifest.json`

Each asset includes:
- id,
- purpose,
- prompt,
- source/reference,
- generated file,
- target ratio,
- topic phrase,
- expected start/end time,
- evidence label if needed.

ChatGPT can generate the images. Local tools then normalize them to the output resolution.

## Phase 5 — Final audio construction

FFmpeg assembles the selected speech segments in the exact order from the plan.

Outputs:
- `07_TIMELINE/final_audio.wav`,
- `07_TIMELINE/audio_edit_map.json`.

This audio becomes the final master clock.

## Phase 6 — Subtitle alignment

Subtitles are aligned against `final_audio.wav`, NOT against the raw source.

Outputs:
- `08_SUBTITLES/aligned_words.json`,
- `08_SUBTITLES/subtitles.srt`,
- `08_SUBTITLES/subtitles.ass`.

ASS contains the style:
- white normal text,
- yellow/gold important words,
- red strongest emphasis,
- translucent dark backing.

## Phase 7 — Build deterministic visual timeline

Create:
`07_TIMELINE/video_timeline.json`

Each timeline event contains:
- final start time,
- final end time,
- source type (video/image/title/end-card),
- source file,
- crop,
- overlay,
- transition,
- subtitle enabled/disabled,
- audio continuation.

Important rule:
**context images are keyed to the FINAL AUDIO phrase timing.**

## Phase 8 — Render

Primary renderer:
- FFmpeg.

Attempt:
1. normal high-quality render.

If it exceeds resource limits:
2. automatically switch to segmented render.

Segmented mode:
- render source-video chunks,
- render still-image chunks,
- concatenate,
- burn subtitles in manageable sections,
- mux final audio,
- make one final delivery encode only when required.

## Phase 9 — QA

Automated checks:
- final file exists,
- target duration,
- video/audio stream durations,
- 1920x1080,
- expected fps,
- audio present,
- no zero-byte segments,
- no missing planned assets.

Visual checkpoints:
- extract frames around every planned insert,
- extract frames around end-card transitions,
- save contact sheet.

Outputs:
- `10_QA/qa_report.json`,
- `10_QA/qa_report.html`,
- `10_QA/checkpoints/`.

If QA fails, state becomes `FIX_REQUIRED` and the renderer uses the failed checks to rerun only affected sections.

## Phase 10 — Delivery

Outputs:
- `11_OUTPUT/final_video.mp4`,
- `11_OUTPUT/final_thumbnail.jpg`,
- `11_OUTPUT/final_transcript.txt`,
- `11_OUTPUT/project_summary.html`.

The complete project remains reproducible after final delivery.
