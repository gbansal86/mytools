@echo off
setlocal EnableExtensions
title Nuditag - Move Flagged Videos Into NSFW Subfolders

REM ============================================================================
REM 03_Move_NSFW_From_Report.bat
REM
REM This is OPTIONAL and intentionally separate from scanning.
REM
REM It reads:
REM   E:\Nuditag\Reports\ALL_NSFW_VIDEOS.csv
REM
REM For each path in that report:
REM   E:\Movies\clip.mp4
REM becomes:
REM   E:\Movies\NSFW\clip.mp4
REM
REM SAFETY:
REM   1. A DRY RUN happens first.
REM   2. Nothing is moved until the user types exactly: MOVE
REM   3. Existing destination files are never overwritten.
REM   4. Every action is logged to CSV.
REM ============================================================================

set "ROOT=E:\Nuditag"
set "REPORT=%ROOT%\Reports\ALL_NSFW_VIDEOS.csv"
set "LOGDIR=%ROOT%\Reports"
set "PS1=%ROOT%\Move_NSFW_From_Report.ps1"

if not exist "%REPORT%" (
    echo.
    echo ERROR: NSFW report not found:
    echo   %REPORT%
    echo.
    echo Run 02_Run_Custom_Scan.bat first.
    echo.
    pause
    exit /b 1
)

if not exist "%PS1%" (
    echo.
    echo ERROR: Helper script not found:
    echo   %PS1%
    echo.
    echo Run setup again to copy the helper files.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo OPTIONAL NSFW FILE MOVER
echo ============================================================================
echo.
echo Source report:
echo   %REPORT%
echo.
echo The script creates an NSFW subfolder beside each flagged file.
echo.
echo Example:
echo   E:\Movies\clip.mp4
echo becomes:
echo   E:\Movies\NSFW\clip.mp4
echo.
echo First pass = DRY RUN. Nothing moves.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
    -File "%PS1%" ^
    -Report "%REPORT%" ^
    -LogDir "%LOGDIR%" ^
    -DryRun

if errorlevel 1 (
    echo.
    echo Dry run failed. Nothing was moved.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo DRY RUN FINISHED
echo ============================================================================
echo.
echo Review the lines above.
echo.
set /p "CONFIRM=Type MOVE and press Enter to actually move the listed files: "

if /I not "%CONFIRM%"=="MOVE" (
    echo.
    echo Cancelled. Nothing was moved.
    echo.
    pause
    exit /b 0
)

echo.
echo Moving files...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
    -File "%PS1%" ^
    -Report "%REPORT%" ^
    -LogDir "%LOGDIR%"

set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo ============================================================================
    echo MOVE COMPLETE
    echo ============================================================================
) else (
    echo ============================================================================
    echo MOVE FINISHED WITH ONE OR MORE ERRORS
    echo ============================================================================
)

echo.
echo Review the newest log here:
echo   %LOGDIR%\NSFW_Move_Log_*.csv
echo.
echo NOTE:
echo The current Nuditag report contains the paths that existed at scan time.
echo On a later scan, moved files are discovered at their new paths.
echo.
pause
exit /b %RC%
