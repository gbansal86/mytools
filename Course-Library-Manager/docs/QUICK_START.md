# Quick Start

## 1. Start the GUI

Double-click `RUN_COURSE_LIBRARY_MANAGER.bat`. The launcher starts PowerShell hidden, so the **Course Library Manager** WinForms window should be the only application window that remains visible.

If you want a launcher with no console flash at all, run `RUN_COURSE_LIBRARY_MANAGER_SILENT.vbs`.

## 2. Select the course root

Click **Browse** and select the parent folder that contains one subfolder per course.

```text
D:\Courses
├── Course One
├── Course Two
└── Course Three
```

## 3. Optional: clean folder names

Click **Preview Folder Renames** first. The application writes a CSV and changes nothing. If the proposals look correct, click **Apply Folder Renames**. Collisions are skipped and an undo JSON is written.

Use **Cleanup Phrases** to add source/channel/site names you want removed, one phrase per line.

## 4. Check optional media components

Click **Install / Check Components**. FFmpeg/ffprobe are optional and can be installed locally under:

```text
Course-Library-Manager\tools\ffmpeg\bin
```

No administrator rights are normally needed. The Activity area shows download percentage, MB, speed, ETA, extraction, installation, and verification.

## 5. Configure the catalog

**Catalog Settings** controls theme, Cards/Table default, thumbnails, duration probing, subtitle conversion, resources, thumbnail seek position, and default playback speed.

## 6. Build the catalog

Click **Create / Refresh HTML Catalog**. The generated catalog appears under:

```text
<your course root>\_CourseLibrary\index.html
```

## 7. Open and use the library

Click **Open Catalog**. Search courses, open a course, play lessons, seek, change speed, use subtitles, browse resources, and resume later. Playback progress is stored in browser local storage.

## 8. Refresh later

After adding new lessons or courses, run **Create / Refresh HTML Catalog** again. Existing cached thumbnails are reused when possible.
