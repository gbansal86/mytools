# Video Project Format

Yes: **every video is saved as a Video Project**, not just as one MP4.

Recommended structure:

```
VIDEO_PROJECTS/
└── 2026-09-29_india-un_001/
    ├── project_manifest.json
    ├── project_state.json
    ├── style_config.json
    ├── 01_SOURCE/
    │   ├── original_video.mp4
    │   ├── user_logo.png
    │   └── user_assets/
    ├── 02_ANALYSIS/
    │   ├── media_probe.json
    │   ├── analysis_summary.md
    │   └── contact_sheet.jpg
    ├── 03_AUDIO/
    │   ├── source_audio.wav
    │   └── cleaned_audio.wav
    ├── 04_TRANSCRIPT/
    │   ├── raw_transcript.json
    │   ├── raw_transcript.txt
    │   └── aligned_words.json
    ├── 05_PLAN/
    │   ├── execution_plan.json
    │   ├── execution_plan.md
    │   └── decisions.log
    ├── 06_ASSETS/
    │   ├── asset_manifest.json
    │   ├── generated/
    │   ├── normalized/
    │   ├── thumbnails/
    │   └── branding/
    ├── 07_TIMELINE/
    │   ├── audio_edit_map.json
    │   ├── video_timeline.json
    │   ├── final_audio.wav
    │   └── ffmpeg_filtergraph.txt
    ├── 08_SUBTITLES/
    │   ├── subtitles.srt
    │   ├── subtitles.ass
    │   └── subtitle_style.json
    ├── 09_RENDER/
    │   ├── segments/
    │   ├── render_log.txt
    │   ├── render_state.json
    │   └── preview.mp4
    ├── 10_QA/
    │   ├── qa_report.json
    │   ├── qa_report.html
    │   └── checkpoints/
    ├── 11_OUTPUT/
    │   ├── final_video.mp4
    │   ├── final_thumbnail.jpg
    │   ├── final_transcript.txt
    │   └── project_summary.html
    └── logs/
        └── pipeline.log
```

## Why save the whole project?

If the user later says:
- move an image 2 seconds later,
- change the logo,
- change subtitle colors,
- add a different ending,
- make a 60-second version,
- create Shorts/Reels,
- translate the captions,
- rerender at 4K,

the system does **not** restart from the raw source.

It opens the saved Video Project, changes only the required plan/timeline assets, and rerenders the affected parts.

## Project identity

Each project gets:
- `project_id`,
- `project_name`,
- creation time,
- source SHA256,
- pipeline version,
- plan version,
- render version.

This prevents accidentally mixing assets from two videos.
