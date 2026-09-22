# How the ZIP Bulk Extractor works

This page explains the scripts in plain English so a beginner can understand what happens before running them.

## The three scripts

| File | Purpose | Best use |
|---|---|---|
| `RUN_ME.bat` | Shows a simple numbered menu and launches one of the two extraction modes. | Recommended starting point. |
| `Extract_ZIPs_Separate_Folders.bat` | Creates one destination folder per ZIP and extracts into it. | Safest for many unrelated archives. |
| `Extract_ZIPs_Here.bat` | Extracts every ZIP directly into the folder containing the scripts. | When the ZIPs are meant to merge into one directory. |

## What Windows commands are used?

The BAT files use tools already included with normal Windows installations:

- **Command Prompt / BAT** controls the loop, menu, and messages.
- **Windows PowerShell** runs `Expand-Archive`, Microsoft's built-in ZIP extraction command.
- **No Python, 7-Zip, WinRAR, Java, or admin rights are required** for ordinary ZIP files.

## What each important line means

### `pushd "%~dp0"`

`%~dp0` means "the folder where this BAT file is stored."

The script changes to that folder before searching. This is useful because you can double-click the BAT file from File Explorer without first opening Command Prompt.

### `for %%F in (*.zip) do (...)`

This means:

> For every file ending in `.zip` in this folder, perform the commands inside the brackets.

It is **not recursive**. Subfolders are not scanned.

### Environment variables

For each ZIP, the script puts the full source and destination paths into:

- `ZIP_SOURCE`
- `ZIP_DEST`

PowerShell reads those values through `$env:ZIP_SOURCE` and `$env:ZIP_DEST`. This keeps paths containing spaces much easier to handle safely.

### `Expand-Archive ... -Force`

`Expand-Archive` performs the ZIP extraction.

`-Force` means an existing destination file with the same name can be overwritten.

That is why the separate-folder mode is recommended when your ZIPs contain unrelated files.

## Files the scripts do NOT delete

The scripts do not delete:

- the original ZIP archives;
- unrelated files in the folder;
- directories not used as extraction destinations.

## Limitations

This deliberately small tool handles ordinary `.zip` archives only.

It does not provide:

- recursive nested-archive extraction;
- RAR/7Z/TAR/ZST support;
- password entry for encrypted ZIP files;
- a graphical desktop interface;
- duplicate-file conflict review;
- persistent extraction logs.

For those more advanced archive scenarios, see the repository's **Nested Archive Extractor**.

## Security / privacy

The scripts work locally on your PC. They do not upload archive names, archive contents, or extracted files anywhere.

As with any archive, extract only files you trust. Extraction does **not** make the extracted files safe to open.

## Troubleshooting

### "No ZIP files were found"

Make sure the BAT files are in the same folder as the `.zip` files. This utility does not search other folders automatically.

### PowerShell says the archive is invalid

The file may be damaged, incomplete, encrypted, mislabeled as ZIP, or use a ZIP feature unsupported by `Expand-Archive`.

### A file disappeared/reverted after extraction

If an extracted file had the same name and path as an existing file, `-Force` may have overwritten it. Use **separate-folder mode** when you want to avoid files from different archives mixing.

### Windows SmartScreen or antivirus shows a warning

These are plain-text BAT files that call built-in Windows PowerShell. You can open every BAT file in Notepad and inspect the full source before running it. Do not bypass a warning unless you have reviewed the file and trust its source.
