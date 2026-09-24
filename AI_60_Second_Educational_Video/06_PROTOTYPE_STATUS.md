# 06 — Motion prototype status (2026-09-24)

## Actually completed
- Creator/viewer re-review: one primary lesson, **training versus using a trained model**, with a continuous spam-email example and a factual caveat about inference.
- New 99-word provisional eight-scene script in [voice_script_v03.txt](voice_script_v03.txt).
- **The exact editable Python source** for a reproducible, original eight-scene motion animatic: [render_animatic.py](render_animatic.py). It animates icons/particles, arrows, example-to-model paths, a staged output, and an end recap.
- Local preview was rendered: 60.000 seconds, 720×1280, 24 fps, H.264, no audio stream. Eight representative scene frames were inspected and the MP4 decoded without errors. The local MP4/contact sheet/project bundle are delivered separately in the conversation, **not hosted in this repo**.
- Cross-platform font fallback was added for Windows/Linux. The arrow in the two-stage scene now connects TRAINING to USE MODEL instead of implying a raw example automatically is the trained model.

## Windows quick start
Install Python 3.11+ and FFmpeg (ffmpeg must be on PATH); from this folder:

```powershell
py -m pip install -r requirements.txt
py render_animatic.py --output motion_preview.mp4
```

The script attempts Windows Arial and Linux DejaVu Sans; install a usable TrueType fallback if neither is found. Output is intentionally 720×1280/24 fps and silent. The output file is recreated on rerun. Do not label or upload it as the polished finished Short.

## Creator approval questions
1. Does the first 3-second hook create a concrete question worth answering?
2. Can a first-time viewer repeat “training first, inference later” without rewatching?
3. Are the spam paths and distinction of stages obvious without sound?
4. Is the final recap legible at phone size?

## Pending gates (must not be described as complete)
- Record or generate and **listen to** a licensed, natural-sounding voice with human cadence. Retiming must follow actual words, not current placeholder time slots.
- Create polished infographic/3D **editable** asset layers. Current map is a 2D “3D-style” visual metaphor, not moving Blender 3D geometry.
- Animate the camera and true 3D branches if desired; replace illustrative dots with coherent object animation.
- Align captions/annotations to the actual voice and add authorized sound/music.
- Export a final 1080×1920 30 fps H.264/AAC version; phone-size learning test and rights/factual/accessibility QA.

## Resume point
Begin at **G2: natural voice read-through** using [voice_script_v03.txt](voice_script_v03.txt). Measure duration; if needed, shorten/rewrite rather than accelerate. Then update timecodes and affected scene source. Full sample output and exact original renderer are supplied separately in the conversation download bundle, so this repository contains the durable process and source even if the working video link expires.
