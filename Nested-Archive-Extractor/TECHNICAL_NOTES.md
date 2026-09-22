# Technical Notes

This document explains the program flow without assuming PowerShell knowledge.

## High-level flow

```text
User selects files/folders
        |
        v
Program finds 7z.exe / 7zz.exe
        |
        v
Input files are checked
        |
        v
Each outer archive is extracted to a short temporary workspace
        |
        v
Every extracted item is inspected
        |
        +---- normal file ------> move to final output
        |
        +---- folder -----------> inspect its contents
        |
        +---- another archive --> recursively extract it
                                  until Max Depth is reached
```

## Why 7-Zip is used

PowerShell's built-in ZIP support does not cover the range required here. 7-Zip provides one command-line interface for many formats and can often identify an archive from its content even when the filename has no extension.

## Extensionless files

A file does not have to end in `.7z`, `.rar`, or `.zip` to actually contain an archive.

The program therefore uses two checks:

1. Known filename extensions/signatures where practical.
2. 7-Zip's ability to inspect/extract the file.

This is important for files produced by Zstandard wrappers where decompression can result in an inner file such as:

```text
course-name
```

with no extension at all.

## Temporary workspace

Nested extraction needs intermediate disk space. The script creates a short temporary folder such as:

```text
E:\NAE_a1b2c3d4e5
```

A short name helps avoid Windows path-length problems.

On full success the workspace is removed. If a nested step fails, the workspace may be retained and the report contains a `RECOVER` line.

## Recursion depth

Without a limit, a malformed or unusual archive structure could recurse indefinitely.

The GUI therefore has **Maximum archive nesting**. Default: 8.

## Background worker

Extraction can take minutes for large archives. Running it on the Windows Forms UI thread would make the window appear frozen.

The script runs extraction in a PowerShell background job and uses a timer to read new report lines into the GUI.

## Cancellation

The GUI writes a small flag file when cancellation is requested. The worker checks that flag between archive operations.

This is intentionally a safe cancellation model: it does not forcibly terminate 7-Zip in the middle of writing files.

## Original-file protection

The input archive path is only read. Extraction happens into a temporary stage and final destination. The original archive is never renamed, overwritten, or deleted by design.

## PARTIAL versus OK

An outer archive can decompress correctly while an archive inside it fails.

For that reason:

- `OK` means the complete nested chain succeeded.
- `PARTIAL` means the outer archive opened but one or more nested operations did not complete.

This prevents misleading success counts.

## Security boundary

This utility is an extractor, not a malware scanner. Archive contents should be treated according to their source and scanned before running unknown executables or scripts.
