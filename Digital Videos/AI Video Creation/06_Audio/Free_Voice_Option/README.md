# Free voice option — 10-second AI Short

**Status: ready-to-run Windows package; no MP3 generated in the chat environment.** Connected Runway had zero credits, so this route uses the community [edge-tts Python client](https://github.com/rany2/edge-tts) for Microsoft Edge's online voices. It needs Python, internet and service availability; there is no purchased credit or API key. Usage rights/commercial reuse are not guaranteed by the absence of fees: review applicable terms before monetizing.

## Steps
1. Run `START_FREE_VOICE.bat` on your Windows PC. It installs the Python dependency and saves an MP3 and JSON review report under `output/`.
2. Listen to `output/scene01_andrew_EXPERT_VOICE_SAMPLE.mp3`. If needed, try `py generate_voice.py --voice brian`.
3. Check `output/scene01_andrew_voice_review.json` for the measured duration (or null if ffprobe is unavailable).
4. Upload the MP3 to our chat so I can review it and align it with the video. If longer than 10 seconds, revise the text or video timing; do not unnaturally rush the voice.

**Script:** “AI answers in seconds because training happened earlier. The model learned patterns from examples. Your question uses what it has already learned.”

Performance: credible expert technical educator, warm, clear, confident and conversational. The MP3 remains a **voice audition**, not a finished or approved scene, until listened to and synchronized.
