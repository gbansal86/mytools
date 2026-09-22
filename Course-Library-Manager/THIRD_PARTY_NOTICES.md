# Third-Party Notices

Course Library Manager itself is licensed under MIT. Optional third-party software remains under its own license.

## FFmpeg

The application can use **FFmpeg** and **ffprobe** for duration inspection and thumbnail generation. FFmpeg is a separate open-source project and is not relicensed by this repository. Depending on the build configuration, distribution can involve LGPL and/or GPL obligations.

- Project: https://ffmpeg.org/
- License information: https://ffmpeg.org/legal.html

## Windows build providers

The built-in installer currently tries public Windows build locations from:

- Gyan.dev: https://www.gyan.dev/ffmpeg/builds/
- BtbN FFmpeg-Builds: https://github.com/BtbN/FFmpeg-Builds

Those providers and binaries are independent of this repository. Review their current build configuration, terms, licensing, availability, and security practices before redistribution.

## Redistribution note

This repository intentionally does **not** commit downloaded FFmpeg executables. The local `.gitignore` excludes `tools/`, where portable components are placed at runtime.
