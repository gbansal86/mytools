# Video Chapter & Timeline Manager

## Purpose

Create a reusable chapter/timeline system for video projects where chapters are stored separately from the rendered video and can be imported, reused, combined, shifted, and exported to multiple editing tools.

The main goal is to make a chapter more than just a timestamp. A chapter should be able to contain the script, narration, visual prompt, generated image/video, music, annotations, transitions, and reusable metadata.

## Recommended Architecture

Use a tool-neutral master format and export adapters:

```
ChatGPT / Planning
       |
       v
MASTER TXT / JSON TIMELINE
       |
   +---+------------------+
   |          |           |
   v          v           v
LosslessCut  Kdenlive   FFmpeg
   |          |           |
 quick cuts  full edit   automation
 chapters    effects     rendering
   +----------+-----------+
              |
              v
          FINAL VIDEO
```

Recommended stack:

- **Kdenlive** - primary free/open-source editor for full timeline editing.
- **LosslessCut** - fast lossless cutting, segment labels, chapter import/export, and quick chapter editing.
- **FFmpeg** - automated concatenation, timestamp shifting, chapter embedding, rendering, metadata generation.
- **Optional DaVinci Resolve** - professional editing when required.
- **Optional Shotcut** - simpler editor with timeline marker support.

## Tool Comparison

| Tool | Cost | Chapters / Markers | Reusable Assets | Full Editing | Automation Friendliness | Primary Role |
|---|---|---:|---:|---:|---:|---|
| LosslessCut | Free/open-source source + store builds | Excellent | Moderate | Limited | Excellent | Fast chapter/cut manager |
| Kdenlive | Free/open source | Excellent | Excellent | Excellent | Good | Main editor |
| DaVinci Resolve | Free + Studio | Excellent | Excellent | Excellent | Moderate | Professional finishing |
| Shotcut | Free/open source | Good | Moderate | Good | Moderate | Simpler editor |
| MKVToolNix | Free/open source | Excellent | Limited | No | Good | MKV chapter management |
| FFmpeg | Free/open source | Excellent | Excellent via scripts | Automated | Excellent | Backend engine |

## LosslessCut Features Relevant to This Project

LosslessCut is useful as a fast timeline/chapter utility rather than the only editor.

Important capabilities:

- Lossless cutting without re-encoding where possible.
- Remove unwanted sections.
- Rearrange segments.
- Join compatible files without quality loss.
- Smart Cut support around non-keyframe boundaries.
- Combine compatible video/audio/subtitle streams.
- Remove or extract individual tracks.
- Container conversion such as MKV to MP4 where compatible.
- Video thumbnails and audio waveform.
- Frame/keyframe navigation.
- Manual timestamp entry.
- Undo/redo.
- Named segment labels.
- Segment tags and annotations.
- Save segment lists in project files.
- Metadata inspection.
- Rotation/orientation metadata handling.
- Timecode offset handling.
- Frame screenshots.
- Scene-change detection.
- Black-scene detection.
- Silent-audio detection.
- Auto-split by duration, section count, or approximate size.
- Read/edit MP4/MKV chapter markers.
- Import/export segment/chapter information in several text/XML-based formats.

## Why Kdenlive Is the Best Main Editor for This Workflow

Kdenlive has two useful marker concepts:

### Clip Markers

Markers tied to a source clip.

Useful when a reusable clip has internal points such as:

```
Reusable Clip: Browser Cookie Animation

00:00 Hook
00:03 Browser Opens
00:06 Cookie Created
00:10 Request Sent
00:14 Response Returned
```

If the clip is reused elsewhere, its clip markers remain meaningful.

### Timeline Markers / Guides

Markers tied to the assembled project timeline.

Useful for:

- Chapters
- Scene boundaries
- Review notes
- Narration changes
- Visual transitions
- YouTube chapter export

Kdenlive also supports reusable assets and nested sequences, which makes it suitable for treating every chapter as a reusable module.

## Reusable Chapter Concept

Instead of storing only:

```
00:10 - 00:25 Explanation
```

store a complete scene module:

```
[CHAPTER]
id = CH03
name = How Cookies Work
duration = 12
reusable = yes

SCRIPT:
Your browser receives a cookie from the website...

VOICE:
speaker = narrator_male_01
audio = narration_ch03.wav

VISUAL:
type = animation
asset = cookie_flow_animation.mp4

IMAGE:
asset = browser_cookie_diagram.png
prompt = 3D browser-cookie flow diagram...

MUSIC:
asset = tech_background_01.wav
volume = -18dB

ANNOTATIONS:
00:02 Browser
00:05 Cookie
00:08 Web Server

TRANSITION_IN:
fade

TRANSITION_OUT:
crossfade
```

## Import Formats

The manager should accept at least three input modes.

### 1. Absolute Timeline

```
00:00 - 00:05 | HOOK
00:05 - 00:15 | WHAT IS A COOKIE
00:15 - 00:28 | COOKIE CREATED
00:28 - 00:42 | COOKIE SENT BACK
00:42 - 00:52 | PRIVACY
00:52 - 01:00 | SUMMARY
```

### 2. Duration-Only Timeline

This is particularly useful for ChatGPT-generated plans.

```
HOOK | 5
PROBLEM | 8
EXPLANATION | 15
DEMO | 17
SUMMARY | 10
CTA | 5
```

The manager automatically calculates:

```
00:00 - 00:05 | HOOK
00:05 - 00:13 | PROBLEM
00:13 - 00:28 | EXPLANATION
00:28 - 00:45 | DEMO
00:45 - 00:55 | SUMMARY
00:55 - 01:00 | CTA
```

### 3. Percentage-Based Template

Useful for applying the same structure to videos of different lengths.

```
Hook          | 0-10%
Problem       | 10-25%
Explanation   | 25-60%
Demo          | 60-85%
Conclusion    | 85-100%
```

The same template can be applied to:

- 60-second Shorts
- 3-minute explainers
- 15-minute videos
- longer documentaries

## Automatic Multi-Video Chapter Offsetting

The manager should recalculate chapter positions when videos are combined.

Input:

```
VIDEO A - 60 sec
Hook          00:00-00:05
Explanation   00:05-00:45
Summary       00:45-01:00

VIDEO B - 90 sec
Intro         00:00-00:10
Demo          00:10-01:10
Conclusion    01:10-01:30
```

Combined result:

```
00:00-00:05 Hook
00:05-00:45 Explanation
00:45-01:00 Summary
01:00-01:10 Intro
01:10-02:10 Demo
02:10-02:30 Conclusion
```

All internal annotations, subtitles, narration cues, markers, and effects should shift by the same offset.

## Proposed GUI

```
+-----------------------------------------------------+
|          VIDEO CHAPTER / TIMELINE MANAGER           |
+-----------------------------------------------------+
| Video: Browser_Cookies.mp4        Duration 01:00    |
|                                                     |
| Start     End       Chapter                 Enabled |
| 00:00     00:05     Hook                      [x]   |
| 00:05     00:15     What is a Cookie          [x]   |
| 00:15     00:28     Cookie Created            [x]   |
| 00:28     00:42     Cookie Returned           [x]   |
| 00:42     00:52     Privacy                   [x]   |
| 00:52     01:00     Summary                   [x]   |
|                                                     |
| [+ Chapter] [Delete] [Move Up] [Move Down]          |
+-----------------------------------------------------+
| [Import TXT] [Import CSV] [Import Video Chapters]   |
| [Save Template] [Load Template]                     |
|                                                     |
| [Add Video] [Combine Timelines]                     |
|                                                     |
| EXPORT                                              |
| [LosslessCut] [Kdenlive] [YouTube] [FFmpeg]        |
| [JSON] [CSV] [TXT] [SRT/VTT]                       |
+-----------------------------------------------------+
```

## Reusable Chapter Library

Recommended library design:

```
Reusable-Chapters/
|
+-- Hooks/
|   +-- Question-Hook/
|   +-- Shocking-Fact/
|   +-- Before-After/
|
+-- Explanations/
|   +-- Flow-Diagram/
|   +-- 3D-Explainer/
|   +-- Screen-Demo/
|
+-- Comparisons/
|   +-- Before-After/
|   +-- A-vs-B/
|
+-- CTAs/
|   +-- Subscribe/
|   +-- Watch-Next/
|
+-- Endings/
    +-- Summary/
    +-- Closing-Statement/
```

Each reusable module may contain:

```
chapter.json
script.txt
voice.wav
image.png
video.mp4
music.wav
annotations.json
subtitles.srt
thumbnail.png
```

## Suggested Master Project Structure

```
Video-Project/
|
+-- project.json
+-- timeline.txt
+-- timeline.csv
+-- chapters.json
|
+-- Chapters/
|   +-- CH01_Hook/
|   +-- CH02_Problem/
|   +-- CH03_Explanation/
|   +-- CH04_Demo/
|   +-- CH05_Summary/
|
+-- Assets/
|   +-- Images/
|   +-- Video/
|   +-- Audio/
|   +-- Music/
|   +-- SFX/
|   +-- Subtitles/
|
+-- Exports/
|   +-- losslesscut/
|   +-- kdenlive/
|   +-- ffmpeg/
|   +-- youtube/
|
+-- Output/
    +-- final_video.mp4
```

## Export Targets

The manager should generate:

- LosslessCut-compatible segment/chapter files.
- Kdenlive marker/project helper files where practical.
- FFmpeg metadata chapter file.
- YouTube chapter text.
- CSV.
- JSON.
- TXT.
- SRT.
- VTT.
- Human-readable HTML report.

## Future Integration With VideoProductionStudio

The chapter manager should eventually connect to the existing video-production pipeline:

```
IDEA
 |
 v
SCRIPT
 |
 v
CHAPTER PLAN
 |
 v
TIMELINE MANAGER
 |
 +--> image prompts
 +--> image generation
 +--> narration/TTS
 +--> music/SFX
 +--> video generation
 +--> annotations
 +--> subtitles
 |
 v
CHAPTER RENDERING
 |
 v
MASTER TIMELINE
 |
 v
FINAL VIDEO
```

A project should therefore be restartable at chapter level. If Chapter 4 is bad, only Chapter 4 should need regeneration.

## Implementation Priorities

### Phase 1
- TXT import.
- CSV import/export.
- Duration-to-timestamp conversion.
- Editable chapter table.
- Save/load JSON project.
- YouTube chapter export.
- FFmpeg chapter metadata export.

### Phase 2
- Add videos and automatically offset timelines.
- Import chapters embedded in MP4/MKV.
- LosslessCut export.
- Chapter validation: gaps, overlaps, negative duration, out-of-range timestamps.
- Waveform/video preview.

### Phase 3
- Reusable chapter library.
- Nested scene assets.
- Narration/image/video/music references.
- Annotation and subtitle timing.
- Percentage templates.
- Kdenlive integration.

### Phase 4
- Automatic chapter rendering.
- Regenerate only selected chapters.
- Drag-and-drop chapter reuse across projects.
- Version history.
- HTML project report.
- Integration into VideoProductionStudio.

## Design Principle

The application's own **JSON/TXT format should remain the source of truth**.

Do not make LosslessCut, Kdenlive, DaVinci Resolve, or any other editor's project format the master database.

Editors should be treated as export/import targets.

This keeps the workflow portable and allows the same chapters, prompts, audio, annotations, and timelines to be reused across different editors and future video-generation engines.
