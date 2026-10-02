# UNIVERSAL MASTER PROMPT — RAW VIDEO TO FINISHED HIGH-QUALITY EXPLAINER VIDEO

I am uploading a raw source video.

Your job is to turn it into a finished, polished YouTube/news-explainer video, including:
- analyzing the source,
- selecting the strongest hook,
- editing speech/audio,
- removing repetition and weak sections,
- creating all necessary context images,
- creating title/thumbnail-style opening graphics,
- adding subtitles,
- highlighting important words,
- improving video quality,
- placing visual inserts at the correct spoken moments,
- creating an ending visual,
- rendering the final MP4,
- reviewing the final video before delivery.

Do not stop after giving me a plan.
Do not repeatedly ask for approval unless an essential asset or factual decision genuinely cannot be inferred.
The task is complete only when the final downloadable MP4 is produced and checked.

## 1. Analyze the raw video first
Inspect the complete source. Determine:
- duration,
- resolution,
- frame rate,
- audio quality,
- speakers,
- subject/topic,
- repeated sections,
- weak sections,
- strongest statements,
- natural sentence boundaries,
- important names,
- dates,
- places,
- statistics,
- claims,
- key visual concepts,
- strongest opening quote,
- strongest ending.

Create an internal transcript with timestamps.

## 2. Determine the best final length
Do not automatically keep the original duration.
Choose the most effective duration based on:
1. completeness,
2. viewer retention,
3. natural speech,
4. context,
5. removal of repetition.

Never cut in the middle of a sentence.

## 3. Create the master edited audio timeline first
Create the final speech/audio edit before building visuals.

Rules:
- preserve complete sentences,
- preserve natural pauses,
- remove repeated statements,
- remove dead space where appropriate,
- remove irrelevant sections,
- do not create abrupt jumps,
- do not cut after partial phrases,
- listen to every transition.

The resulting edited audio becomes the MASTER TIMELINE for:
- source footage,
- context images,
- subtitles,
- title cards,
- graphics,
- ending.

Never build the visual runtime separately from the audio runtime.

## 4. Automatically select the best opening hook
Find the strongest line in the source.
Do not assume the raw video's beginning is the best beginning.
If the strongest statement occurs later, move it to the opening.

## 5. Automatically create the required visual inserts
Analyze the final edited transcript and create visuals only where they improve understanding.

Possible insert types:
- people,
- locations/maps,
- timelines,
- infrastructure or physical-damage illustrations,
- statistics,
- organizations,
- explanatory diagrams,
- historical references,
- comparison graphics.

Do not create filler visuals merely to change the screen.

## 6. Strict image-topic synchronization
An image must not appear before the audio begins discussing that image's subject.

For every insert:
1. identify the exact spoken phrase,
2. identify its start time in the FINAL EDITED AUDIO,
3. start the visual at or immediately after that phrase begins,
4. keep it only while the topic remains relevant,
5. return to speaker/source footage when the topic changes.

Do not anticipate topics visually.

## 7. Original video remains the backbone
Do not turn the complete video into a slideshow.

Use source footage as the primary visual.
Use context images to explain important points and break monotony.

A useful rhythm is:
source footage → tighter crop → context visual → source footage → infographic → source footage.

Do not force visual changes when the source shot is already engaging.

## 8. Cropping and reframing
Improve source framing when necessary:
- crop unnecessary left/right space,
- center the speaker,
- preserve important signs/nameplates,
- preserve attribution text,
- avoid cutting heads/hands,
- avoid stretching.

Use restrained digital reframing only.

## 9. Source attribution
Preserve legitimate source attribution from the raw footage unless explicitly told otherwise.
Never fabricate or replace source attribution.

## 10. Optional branding / corner logo
If branding is supplied:
- place it in the specified area,
- preserve aspect ratio,
- use crop-to-fill when required,
- no black empty margin,
- no stretching,
- do not cover faces/text,
- do not obscure source attribution.

If no branding is supplied, do not invent permanent branding.

## 11. Subtitles must be generated from FINAL EDITED AUDIO
Never use raw-video transcript timestamps after the audio has been edited.

After the audio edit is final:
1. transcribe/align the final edited audio,
2. produce phrase-level or word-level timestamps,
3. generate subtitles from those timestamps.

This prevents gradual subtitle drift.

## 12. Subtitle visual style
Use a modern news/YouTube emphasis style.

Normal words:
WHITE

Important words:
YELLOW / GOLD

Strong/high-impact terms:
RED

Formatting:
- approximately 2–6 words per caption beat,
- large bold sans-serif font,
- lower-center safe region,
- semi-transparent dark background,
- subtle outline/shadow,
- never cover faces,
- avoid covering logos/nameplates,
- avoid giant paragraphs.

Use emphasis sparingly.

## 13. Automatic keyword emphasis
Select important words intelligently:
- names,
- dates,
- locations,
- numbers,
- major verbs,
- key nouns.

Do not highlight every second word.

## 14. Video quality enhancement
Improve source footage carefully.

Use only when beneficial:
- mild denoise,
- slight sharpening,
- subtle contrast recovery,
- subtle saturation correction,
- high-quality scaling.

Do not:
- oversharpen,
- hallucinate detail,
- reconstruct faces aggressively,
- create waxy skin,
- oversaturate.

The result should still look like genuine source footage.

## 15. Generated visual style
Use a consistent design language:
premium news explainer / documentary graphic.

Characteristics:
- 16:9,
- 1920×1080,
- cinematic but credible,
- clear typography,
- restrained colors,
- strong visual hierarchy,
- readable on mobile,
- no excessive clutter.

## 16. Factual integrity
Generated visuals must help explain a statement, not pretend to independently prove it.

Where appropriate label generated material:
- ILLUSTRATION,
- SPEECH REFERENCE,
- CLAIM MADE IN SPEECH.

## 17. Transitions
Preferred:
- clean cut,
- 0.15–0.3 sec dissolve,
- subtle push,
- restrained zoom.

Avoid:
- shaking,
- spinning,
- excessive wipes,
- flashy template effects,
- random particles.

## 18. Audio
Preserve the original speaker voice whenever possible.

Improve gently if needed:
- high-pass rumble,
- mild compression,
- normalization,
- subtle noise reduction.

Optional music must remain quiet and never interfere with speech.

## 19. Ending
Find the strongest natural concluding sentence.

After the final spoken sentence:
show an appropriate end-card for approximately 1–3 seconds.

Do not end before the speech finishes.

## 20. Automatic runtime handling
The final duration must equal:
edited audio duration + intentional end-card duration.

Never let the visual timeline become shorter than the audio.
Never truncate audio to match visuals.

## 21. Output quality
Final master:
- 1920×1080,
- 30 fps unless source requires otherwise,
- H.264,
- yuv420p,
- AAC 192 kbps or better,
- faststart enabled.

Preferred quality:
- CRF 15–17,
- medium/slow preset when the environment permits.

## 22. Render-failure fallback
If the complete video cannot render in a single pass because of memory/time limits:

Do not repeatedly retry the same failing command.

Automatically switch to:
A. render individual source segments,
B. render individual image segments,
C. concatenate the visual timeline,
D. burn subtitles in manageable sections,
E. join sections without unnecessary recompression,
F. mux final audio.

Continue automatically.
Do not ask me to solve technical render errors.

## 23. Mandatory final QA
Before delivery inspect the actual rendered MP4.

Check:

### File
- exists,
- downloadable,
- correct resolution,
- correct runtime.

### Audio
- no missing words,
- no mid-sentence cuts,
- no abrupt transitions,
- no early ending.

### Subtitles
Check synchronization around:
- 10 sec,
- 30 sec,
- 45 sec,
- 60 sec,
- 90 sec,
- 120 sec,
- last 10 sec.

Ensure there is no progressive drift.

### Images
Check every insert:
- starts after matching dialogue begins,
- not early,
- not late,
- disappears appropriately.

### Quality
Check:
- faces,
- text sharpness,
- image resolution,
- cropping,
- logos.

## 24. Create a project package
Save the project as:

VIDEO_PROJECT/
├── 01_SOURCE/
├── 02_TRANSCRIPT/
├── 03_AUDIO/
├── 04_IMAGES/
├── 05_SUBTITLES/
├── 06_TIMELINE/
├── 07_RENDER/
└── PROJECT_MANIFEST.json

## 25. Project manifest
Record:
- source video,
- target duration,
- hook,
- audio segments,
- image inserts,
- subtitle style,
- logo,
- end card,
- resolution,
- fps.

## 26. Delivery behavior
Do not stop after:
- analysis,
- images,
- audio,
- timeline,
- subtitles.

The task is complete only after the final MP4 is produced and checked.

Do not repeatedly ask:
- “Should I continue?”
- “Shall I render?”
- “Do you approve?”

If sufficient information is available, proceed to completion.

---

## SHORT REUSABLE VERSION

Edit the uploaded source into a finished 1920×1080 YouTube/news explainer MP4. Use the final audio as the master timeline. Preserve complete sentences and continuous audio. Align subtitles directly against the edited audio, not original timestamps. Use white subtitles, yellow/gold keywords, red strongest phrases, with a dark translucent backing. Context images must appear only when their exact topic starts being spoken—never early. Preserve source attribution. Crop and mildly enhance source footage without making faces artificial. Replace any specified logo box using the supplied artwork with aspect-preserving cover fit and no black margins. Keep source footage between inserts. Use subtle transitions only. Render with high-quality H.264. If a one-pass render fails, automatically render in segments and join them. Before delivery verify exact runtime, audio/video durations, subtitle sync at multiple checkpoints, image-topic alignment, logo placement, and final end-card timing. Do not ask for routine confirmation; complete the final MP4 and give a verified working download link.
