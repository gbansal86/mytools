# Architecture

Course Library Manager is a single-script Windows utility with generated static HTML output. It does not require a database server or background service.

## Components

- **WinForms GUI** — root selection, settings, activity/progress, folder cleanup, catalog generation.
- **Folder-cleanup engine** — plans names, detects collisions, writes preview/apply CSVs, applies eligible renames deepest-first, records undo JSON.
- **Catalog scanner** — treats each immediate subfolder as a course and recursively discovers videos, subtitles, PDFs, images, and other resources.
- **Media helpers** — optional `ffprobe` durations and `ffmpeg` thumbnails, using system or portable local copies.
- **Subtitle conversion** — writes browser-friendly generated `.vtt` copies while keeping original `.srt` files intact.
- **HTML generator** — embeds JSON course metadata into a static HTML/JavaScript interface.
- **Browser state** — watched/resume position, theme, view preference, and speed live in browser `localStorage`.

## Data flow

```text
Course folders
    |
    +--> optional folder-name preview/apply/undo
    |
    +--> recursive catalog scan
            |
            +--> ffprobe duration (optional)
            +--> ffmpeg thumbnail (optional)
            +--> SRT -> generated VTT copy
            |
            +--> library-data.json
            +--> index.html
                    |
                    +--> local browser player
                    +--> localStorage progress
```

## Trust boundaries

Original course content is source data. Generated catalog artifacts are isolated under `_CourseLibrary`. Portable third-party FFmpeg binaries are isolated under the application folder's `tools` directory. The application does not expose a network listener or upload the course inventory.
