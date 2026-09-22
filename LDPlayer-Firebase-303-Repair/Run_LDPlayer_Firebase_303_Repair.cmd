@echo off
setlocal
cd /d "%~dp0"
title LDPlayer Firebase #303 Repair

echo ============================================================
echo  LDPlayer Internet / Firebase #303 Repair
echo ============================================================
echo.
echo This launcher starts the annotated PowerShell repair script.
echo Windows may ask for Administrator permission.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix_LDPlayer_Firebase_303.ps1"
echo.
pause
