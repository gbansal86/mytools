# Troubleshooting

## First checks

1. Confirm the Activity box begins with `Course Library Manager v1.5.0 ready`.
2. Confirm the selected root exists and contains course subfolders.
3. If a build fails, copy the final Activity lines before closing the app.
4. Inspect `<course root>\_CourseLibrary\build-report.json` after a successful build.

## FFmpeg appears stuck

The installer displays percentage, downloaded size, speed, and ETA, and has connection/read timeouts plus a fallback source. If it cannot download, check firewall/proxy access, retry **Install / Check Components**, install `ffmpeg.exe`/`ffprobe.exe` yourself on `PATH` or under `tools\ffmpeg\bin`, or disable thumbnails/durations.

## `Argument types do not match`

Version 1.5 includes the PowerShell `List[object]` compatibility fix and a pre-build self-test. Make sure the Activity panel says `v1.5.0`; replace older copies completely.

## No thumbnails

Verify **Generate video thumbnails** is enabled, FFmpeg is detected, the video is decodable, and `_CourseLibrary/assets/thumbs` is writable.

## No durations

Duration metadata needs `ffprobe` and **Read video durations with ffprobe** enabled.

## No subtitles

The generator looks in the same folder for a matching base name and prefers `_en`:

```text
001 Welcome.mp4
001 Welcome_en.srt
```

or `001 Welcome.srt`. Generated browser tracks are written under `_CourseLibrary/assets/vtt`.

## Video does not play in the browser

The catalog does not transcode original videos. Browser codec support applies. Use **Open File** to use the operating system's media player.

## Course image is missing

Put a suitable root-level file such as `cover.jpg`, `course-cover.png`, `poster.webp`, or `thumbnail.jpg` in the course folder.

## Folder rename was skipped

Open the preview/apply CSV and read `Status`/`Reason`. The app skips destination conflicts and sibling-name collisions.

## Need the PowerShell console for debugging

Run manually without `-NoConsole`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\Course_Library_Manager.ps1
```
