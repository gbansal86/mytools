# Testing

The parent `mytools` repository validation parses PowerShell source and requires each top-level tool folder to contain a README and LICENSE.

## Internal pre-build self-test

Version 1.5 checks generic `List[object]`/`.ToArray()`, duration formatting, `PSCustomObject` construction, JSON serialization, library-array serialization, HTML template generation/placeholder replacement, sample course data presence, and Windows PowerShell 5.1-compatible ETA formatting.

## Release review performed for 1.5

The source was reviewed for the earlier `New-Object List[object]`/`@($list)` binder pattern, unsupported `[double]::IsFinite()` usage, empty/single-array JSON behavior, HTML generation, FFmpeg download progress, one-window launch behavior, and package integrity.

## Manual Windows checks recommended

1. launch with BAT and VBS;
2. preview/apply/undo a small folder test;
3. build a catalog with FFmpeg disabled;
4. install/check FFmpeg and rebuild with thumbnails/durations;
5. verify subtitle conversion;
6. open the catalog in Edge or Firefox;
7. test seek/speed/resume/watched state;
8. rebuild and confirm cached thumbnails are reused.

Full end-to-end Windows GUI automation is not currently claimed.
