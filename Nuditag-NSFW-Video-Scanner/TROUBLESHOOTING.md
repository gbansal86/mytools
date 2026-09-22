# Troubleshooting

This page assumes the default installation path is E:\Nuditag.

## Setup looks stuck while installing Python

The Python installer is launched quietly, so the command window can appear unchanged for a few minutes.

Wait several minutes before stopping it.

In a second PowerShell window you can check for active installer processes:

~~~powershell
Get-Process | Where-Object {
    $_.ProcessName -match "python|burn|msiexec"
} | Select-Object ProcessName, Id, CPU, StartTime
~~~

If CPU time is changing, the installer is still doing work.

## pip looks stuck near huggingface-hub

A first install can spend several minutes finishing dependencies, especially while antivirus scans newly written Python files.

If it has been unchanged for a long time, open another PowerShell window and run:

~~~powershell
Get-Process python,pip -ErrorAction SilentlyContinue |
    Select-Object ProcessName, Id, CPU, StartTime
~~~

Do not delete E:\Nuditag just because one install attempt was interrupted. Re-running 01_Setup_Nuditag_On_E.bat reuses completed setup steps.

## E: drive not found

The default package is intentionally configured for E:\Nuditag.

Connect/mount the intended E: drive first.

If your machine has no E: drive and you want another location, change the ROOT setting consistently in the BAT files and path examples.

## Access is denied while scanning C:\

Close the scanner, then right-click 02_Run_Custom_Scan.bat and choose Run as administrator.

Some protected Windows folders may still be unavailable. The helper skips unreadable folders rather than ending the whole scan.

System locations are excluded by default in ExcludePaths.txt because they normally do not contain a personal video library.

## Scan is taking too long

Start smaller.

Instead of:

~~~text
E:\
C:\
D:\
~~~

try:

~~~text
E:\Movies
~~~

You can also lower FRAMES=32 to FRAMES=8, but that changes how much of each video is sampled. If you already have a report made with a different frame count and want consistent scoring, rename/delete the old reports and rescan.

## I changed the threshold

Changing THRESHOLD does not require rescoring. Existing numeric scores are re-labelled against the new threshold on the next run.

Example:

~~~text
old threshold 0.40, score 0.45 -> NSFW
new threshold 0.60, score 0.45 -> SFW
~~~

## I changed the number of frames

The old numeric scores were calculated using the earlier sampling setting.

For a clean comparison, rename or delete:

~~~text
E:\Nuditag\Reports\ALL_FULL_REPORT.csv
E:\Nuditag\Reports\ALL_NSFW_VIDEOS.csv
~~~

then run the scan again.

## I pressed Ctrl+C

Completed rows are flushed to ALL_FULL_REPORT.csv.

Run the scanner again. Valid rows whose paths are still in scope are reused.

## ALL_NSFW_VIDEOS.csv is empty

Possible explanations:

- no scanned video reached the threshold;
- your threshold is high;
- SearchPaths.txt did not contain supported video files;
- the relevant directory is excluded;
- files were unreadable by the video decoder.

Check ALL_FULL_REPORT.csv and the console summary.

## A folder I wanted was skipped

Check whether it is underneath anything in ExcludePaths.txt.

Exclusions always win.

Example:

~~~text
SearchPaths:   E:\
ExcludePaths:  E:\Videos
~~~

means E:\Videos is not scanned even though E:\ is a search root.

## The model cannot download

The first scoring run needs internet access to obtain the model used by Nuditag.

This wrapper sets the Hugging Face cache under:

~~~text
E:\Nuditag\ModelCache
~~~

Check firewall/proxy restrictions and available disk space, then run the scanner again.

## A video says SKIPPED

Nuditag could not get a usable score from that file. Common reasons include damaged media, unsupported codec/container details, decoder failure, or a file that disappeared during scanning.

A skipped video is not silently marked SFW; it simply has no completed score row.

## Mover says MISSING

The NSFW report contains the path as it existed when the report was created.

If you manually moved or renamed the video afterward, the old source path no longer exists. The mover logs it as MISSING and does nothing.

## Mover creates _1, _2, etc.

That is collision protection.

If E:\Movies\NSFW\clip.mp4 already exists and another clip.mp4 must be moved there, the script uses clip_1.mp4 rather than overwrite a file.

## I want to test without touching files

The scanner is read-only with respect to videos.

The mover always performs a dry run first and requires the exact confirmation word MOVE before changing any path.
