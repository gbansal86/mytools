# 04 — Review and release checklist

## Content and instruction
- [ ] The learning outcome can be restated after one viewing.
- [ ] Training versus inference and generative outputs are not conflated.
- [ ] Spam example uses “likely”; routing example does not attribute all routing to AI.
- [ ] Every moving arrow corresponds to an actual explanation, not decorative noise.
- [ ] The final recap is legible for at least 2 seconds at phone size.

## Audio and accessibility
- [ ] Listen to voice end-to-end at normal speed on phone speakers and headphones.
- [ ] Human-sounding, expressive but not imitating an identifiable person without consent.
- [ ] Word-cued labels/captions match what is spoken; captions have high contrast.
- [ ] No captions obscured by platform interface; avoid flashing/glare and abrupt audio peaks.
- [ ] Include an editable SRT; inspect captions for scientific terms and typos.

## Technical (verify actual file; do not assume)
```bash
ffprobe -v error -show_entries format=duration -show_entries stream=codec_name,width,height,r_frame_rate -of json final.mp4
ffmpeg -v error -i final.mp4 -f null -
```
- [ ] 1080x1920 portrait, 30 fps target, H.264 video + AAC audio.
- [ ] Duration <= 60.0 sec; voice finishes before the cut; no black/blank accidental frames.
- [ ] Each scene visibly moves its **own objects and paths**, not only a crop/zoom of a static poster.
- [ ] Inspect stills at first/middle/last frame of every scene; check handoffs and spelling.
- [ ] Render review MP4, correct all issues, then rerun every affected check.

## Public-repository and platform release
- [ ] All included fonts, music, SFX, images, narration and source video have documented rights.
- [ ] No private source YouTube footage, cookies, tokens, personal identifiers or large copyrighted reference assets committed.
- [ ] Version source project, text scripts, prompts, timings, source asset manifest and reusable code; use a release or suitable storage for large final video.
- [ ] Do not claim a tool generated a human voice or 3D animation until the actual file is rendered and verified.
- [ ] Keep one changelog entry and a frozen manifest for every released video.

## What constitutes success
The project is NOT complete at the concept-art, storyboard, documentation, or static slideshow stage. It is complete only when a verified 60-second narrated MP4 with moving infographic paths and moving mind-map branches, readable annotations, captions, passed QA and verified reuse rights is delivered.
