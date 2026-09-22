# Troubleshooting

## I double-click `00_START_HERE.bat` and nothing happens

The fixed launcher is designed to keep startup errors visible. Check these items:

1. Confirm you extracted the **entire ZIP**.
2. Do not run the BAT from inside File Explorer's ZIP preview.
3. Put the package in a writable local folder.
4. Approve the Windows UAC prompt.
5. Check `%TEMP%` for files named `PC_Recovery_Startup_*.log`.
6. If company policy blocks PowerShell, the visible BAT error should say so; contact the administrator.

## Windows says PowerShell scripts are blocked

The launcher uses `-ExecutionPolicy Bypass` only for the child process; it does not permanently change system policy. Organizational AppLocker/WDAC/PowerShell policies can still block execution.

## The menu opens, but a diagnostic command fails

Run option **11 — Self-test**. Some telemetry is optional and varies by Windows edition, hardware vendor and driver stack.

A missing optional command does not necessarily mean the PC is broken; it means that particular telemetry may be unavailable.

## `Get-StorageReliabilityCounter` returns little or nothing

Not every storage device/USB bridge/controller exposes the same reliability data to Windows. Missing values must not be interpreted as proof that the drive is healthy.

## I see WHEA events

Repeated WHEA events deserve attention, but one generic script cannot always identify the exact failed component. Save the report and correlate the event type with CPU, memory, PCIe, storage or GPU evidence.

## My PC has a failing drive. Should I run repair?

Protect important files first. Avoid unnecessary write-heavy work on a drive suspected of imminent failure.

## The BAT window shows an exit code

Read the error directly above it, then open the latest startup transcript under:

```text
%TEMP%\PC_Recovery_Startup_*.log
```

## Folder path contains spaces

The fixed launcher supports paths with spaces. It also improved handling of apostrophes in the package path by using an encoded elevation command. If a path still causes trouble, extract to a simple path such as:

```text
C:\PC-Tools\Windows-PC-Recovery
```
