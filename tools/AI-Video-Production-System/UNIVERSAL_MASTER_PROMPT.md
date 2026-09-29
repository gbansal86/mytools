# UNIVERSAL MASTER PROMPT — RAW VIDEO → FINISHED HIGH-QUALITY EXPLAINER VIDEO IN ONE GO

I am uploading a **raw source video**.

Your job is to turn it into a **finished, polished YouTube/news-explainer video**, including:
- analyzing the raw video
- identifying the strongest hook
- editing the speech/audio
- removing repetition and weak sections
- creating all necessary context images
- creating title/thumbnail-style opening graphics
- adding subtitles
- highlighting important words
- improving video quality
- adding visual inserts at the correct spoken moments
- creating an ending visual
- rendering the final MP4
- reviewing the final video before delivery

Do **not** stop after giving me a plan.
Do **not** repeatedly ask me for approval unless an essential asset or factual decision genuinely cannot be inferred.
The goal is to produce the **finished downloadable MP4 in one workflow**.

## 1. Analyze the raw video first
Before editing, inspect the complete source. Determine source duration, resolution, frame rate, audio quality, speakers, subject/topic, repeated sections, weak sections, strongest statements, natural sentence boundaries, important names, dates, places, statistics, claims, key visual concepts, strongest opening quote, and strongest ending. Create an internal transcript with timestamps.

## 2. Determine the best final length
Do not automatically keep the original duration. Choose the most effective duration based on content and viewer retention. Never cut in the middle of a sentence.

## 3. Create a master edited audio timeline first
Create the final speech/audio edit **before building visuals**. Preserve complete sentences and natural pauses. Remove repetition and dead space. Listen to every transition. The resulting edited audio becomes the **MASTER TIMELINE** for the whole video.

Everything else must synchronize to this audio:
- original footage
- context images
- subtitles
- title cards
- graphics
- ending

Never build the visual runtime separately from the audio runtime.

## 4. Automatically select the best opening hook
Find the strongest line in the source. Do not assume the raw video's beginning is the best beginning. If a stronger statement occurs later, move it to the opening.

## 5. Automatically create required visual inserts
Create supporting visuals only when they genuinely explain spoken content. Typical categories include people, locations, maps, timelines, physical-damage illustrations, statistics, organizations, diplomatic/policy positions, and historical references.

## 6. Strict image-topic synchronization
**An image must not appear before the audio begins discussing that image's subject.**

For every insert:
1. identify the exact spoken phrase
2. identify its start time in the FINAL EDITED AUDIO
3. start the image at or immediately after that phrase begins
4. keep it only while the topic remains relevant
5. return to source footage when the topic changes

Never anticipate a topic visually.

## 7. Original video remains the backbone
Do not turn the entire video into a slideshow. Use source footage as the primary visual and context images to explain important points and reduce monotony.

## 8. Cropping and reframing
Crop unnecessary left/right space if needed, preserve speakers and important nameplates, avoid cutting heads/hands, avoid stretching, and use restrained punch-ins only.

## 9. Source attribution
Preserve legitimate source attribution from the raw footage unless explicitly told otherwise. Never fabricate or replace attribution.

## 10. Optional branding / corner logo
If branding is provided:
- place it in the specified logo area
- preserve aspect ratio
- use crop-to-fill if needed
- leave no black/empty margins
- do not stretch
- do not cover faces/text
- do not obscure source attribution

If no branding is provided, do not invent permanent branding.

## 11. Subtitles must be generated from FINAL AUDIO
Never reuse raw-video transcript timestamps after audio has been edited.

After the audio edit:
1. transcribe/align the final edited audio
2. generate phrase-level or word-level timestamps
3. build captions from those timestamps

This prevents progressive subtitle drift.

## 12. Subtitle visual style
- Normal words: **WHITE**
- Important words: **YELLOW / GOLD**
- Strong/high-impact terms: **RED**
- generally 2–6 words per caption beat
- large bold sans-serif
- lower-center safe region
- semi-transparent dark background
- subtle outline/shadow
- never cover faces
- avoid important logos/nameplates
- no giant paragraphs

## 13. Automatic keyword emphasis
Select emphasis intelligently from names, dates, locations, numbers, major nouns and important verbs. Do not highlight every second word.

## 14. Video quality enhancement
Improve source footage carefully:
- mild denoise
- slight sharpening
- subtle contrast recovery
- subtle saturation correction
- quality scaling

Do not oversharpen, hallucinate details, reconstruct faces aggressively, or create artificial skin.

## 15. Generated visual style
Use a consistent **premium news-explainer / documentary graphic** language:
- 16:9
- 1920×1080
- cinematic but credible
- clear typography
- restrained colors
- strong visual hierarchy
- readable on mobile
- no excessive clutter

## 16. Factual integrity
Generated visuals must help explain claims, not pretend to independently prove them. When appropriate label them:
- **ILLUSTRATION**
- **SPEECH REFERENCE**
- **CLAIM MADE IN SPEECH**

## 17. Transitions
Prefer clean cuts, short 0.15–0.3 sec dissolves, and subtle pushes/zooms. Avoid shaking, spinning, excessive wipes, random particles, and flashy template effects unless requested.

## 18. Audio
Preserve the original speaker voice whenever possible. Use mild compression, normalization, high-pass filtering, or noise reduction only when needed. Optional music must remain quiet and never interfere with speech.

## 19. Ending
Find the strongest natural concluding sentence. After the final spoken sentence, show an appropriate end-card for approximately 1–3 seconds. Do not end before the speech finishes.

## 20. Automatic runtime handling
Final duration = **edited audio duration + intentional end-card duration**.
Never let the visual timeline become shorter than the audio. Never truncate speech to fit visuals.

## 21. Output quality
Final master:
- **1920×1080**
- **30 fps** unless source requires otherwise
- H.264
- yuv420p
- AAC 192 kbps+
- faststart enabled
- CRF 15–17 when practical
- medium/slow quality-focused preset when environment permits

## 22. Render-failure fallback
If a complete render cannot finish in one pass, **do not repeatedly retry the same failing command**.

Automatically switch to:
A. render source-footage sections separately
B. render image sections separately
C. concatenate the visual timeline
D. burn subtitles in manageable sections
E. join sections without unnecessary recompression
F. mux final audio

Handle rendering problems automatically.

## 23. Mandatory final QA
Before delivery inspect the actual rendered MP4.

### File
- file exists
- file downloads
- correct resolution
- correct runtime

### Audio
- no missing words
- no mid-sentence cuts
- no abrupt transitions
- no early ending

### Subtitles
Check sync at 10, 30, 45, 60, 90, 120 seconds and the final 10 seconds. Ensure there is **no progressive drift**.

### Images
For every insert:
- starts after matching dialogue begins
- not early
- not late
- disappears appropriately

### Quality
Check faces, text sharpness, image resolution, cropping, logo placement and ending.

## 24. Create a project package
Save:
```text
VIDEO_PROJECT/
├── 01_SOURCE/
├── 02_TRANSCRIPT/
├── 03_AUDIO/
├── 04_IMAGES/
├── 05_SUBTITLES/
├── 06_TIMELINE/
├── 07_RENDER/
└── PROJECT_MANIFEST.json
```

## 25. Project manifest
Save key decisions in machine-readable JSON including source, target duration, hook, audio segments, image inserts, subtitle style, logo, end card, resolution and fps.

## 26. Delivery behavior
Do not stop after analysis, images, audio, timeline or subtitles. The task is complete only after the final MP4 is produced and checked.

Do not repeatedly ask:
- “Should I continue?”
- “Shall I render?”
- “Do you approve?”
- “Want me to use this?”

If sufficient information is available, proceed to completion.

---

## SHORT REUSABLE VERSION

Edit the uploaded source into a finished 1920×1080 YouTube/news explainer MP4. Use the final audio as the master timeline. Preserve complete sentences and continuous audio. Align subtitles directly against the edited audio, not original timestamps. Use white subtitles, yellow/gold keywords, red strongest phrases, with a dark translucent backing. Context images must appear only when their exact topic starts being spoken—never early. Preserve source attribution. Crop and mildly enhance source footage without making faces artificial. Replace the specified logo box using the supplied artwork with aspect-preserving cover fit and no black margins. Keep source footage between inserts. Use subtle transitions only. Render with high-quality H.264 (1080p, 30 fps, CRF 15–17). If a one-pass render fails, automatically render in segments and join them. Before delivery verify exact runtime, audio/video durations, subtitle sync at multiple checkpoints, image-topic alignment, logo placement, and final end-card timing. Do not ask for routine confirmation; complete the final MP4 and give a verified working download link.
