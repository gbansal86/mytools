@echo off
setlocal EnableExtensions
title Nuditag - Custom Path Video Scan

REM ============================================================================
REM 02_Run_Custom_Scan.bat
REM
REM Reads:
REM   E:\Nuditag\SearchPaths.txt
REM   E:\Nuditag\ExcludePaths.txt
REM
REM Writes:
REM   E:\Nuditag\Reports\ALL_FULL_REPORT.csv
REM   E:\Nuditag\Reports\ALL_NSFW_VIDEOS.csv
REM
REM This file DOES NOT install software and DOES NOT move/delete videos.
REM ============================================================================

set "ROOT=E:\Nuditag"
set "PYTHON=%ROOT%\venv\Scripts\python.exe"
set "SCANNER=%ROOT%\nuditag_custom_scan.py"
set "SEARCH_FILE=%ROOT%\SearchPaths.txt"
set "EXCLUDE_FILE=%ROOT%\ExcludePaths.txt"
set "REPORTS=%ROOT%\Reports"

set "TEMP_DIR=%ROOT%\Temp"
set "CACHE_DIR=%ROOT%\Cache"
set "MODEL_DIR=%ROOT%\ModelCache"

REM USER-TUNABLE SETTINGS
REM FRAMES=32     More frames = slower but broader video coverage.
REM THRESHOLD=.40 Score >= threshold is labelled NSFW.
REM WORKERS=0     Use Nuditag's automatic worker count.
set "FRAMES=32"
set "THRESHOLD=0.40"
set "WORKERS=0"

set "TEMP=%TEMP_DIR%"
set "TMP=%TEMP_DIR%"
set "HF_HOME=%MODEL_DIR%"
set "HF_HUB_CACHE=%MODEL_DIR%\hub"
set "XDG_CACHE_HOME=%CACHE_DIR%"
set "PIP_CACHE_DIR=%CACHE_DIR%\pip"
set "PYTHONNOUSERSITE=1"
set "PIP_DISABLE_PIP_VERSION_CHECK=1"

if not exist "%PYTHON%" (
    echo.
    echo ERROR: Nuditag environment was not found:
    echo   %PYTHON%
    echo.
    echo Run 01_Setup_Nuditag_On_E.bat first.
    echo.
    pause
    exit /b 1
)

if not exist "%SCANNER%" (
    echo.
    echo ERROR: Scanner helper was not found:
    echo   %SCANNER%
    echo.
    echo Run setup again to copy the helper files.
    echo.
    pause
    exit /b 1
)

if not exist "%SEARCH_FILE%" (
    echo ERROR: Missing %SEARCH_FILE%
    pause
    exit /b 1
)

if not exist "%EXCLUDE_FILE%" (
    echo ERROR: Missing %EXCLUDE_FILE%
    pause
    exit /b 1
)

mkdir "%REPORTS%" 2>nul
mkdir "%TEMP_DIR%" 2>nul
mkdir "%CACHE_DIR%" 2>nul
mkdir "%MODEL_DIR%" 2>nul

echo.
echo ============================================================================
echo NUDITAG CUSTOM VIDEO SCAN
echo ============================================================================
echo.
echo Search paths : %SEARCH_FILE%
echo Exclusions   : %EXCLUDE_FILE%
echo Frames/video : %FRAMES%
echo Threshold    : %THRESHOLD%
if "%WORKERS%"=="0" (
    echo Workers      : automatic
) else (
    echo Workers      : %WORKERS%
)
echo.
echo Full report:
echo   %REPORTS%\ALL_FULL_REPORT.csv
echo.
echo NSFW-only report:
echo   %REPORTS%\ALL_NSFW_VIDEOS.csv
echo.
echo IMPORTANT:
echo   - Only supported VIDEO files are scored.
echo   - Excluded folders are pruned before scoring.
echo   - Existing completed rows are reused when the path is still in scope.
echo   - No video is deleted, moved, renamed, or modified.
echo.
echo Press Ctrl+C now if you need to edit the path files first.
echo Starting in 5 seconds...
timeout /t 5 /nobreak >nul

"%PYTHON%" "%SCANNER%" ^
    --root "%ROOT%" ^
    --search-file "%SEARCH_FILE%" ^
    --exclude-file "%EXCLUDE_FILE%" ^
    --full-report "%REPORTS%\ALL_FULL_REPORT.csv" ^
    --nsfw-report "%REPORTS%\ALL_NSFW_VIDEOS.csv" ^
    --frames %FRAMES% ^
    --threshold %THRESHOLD% ^
    --workers %WORKERS%

set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo ============================================================================
    echo SCAN FINISHED
    echo ============================================================================
    echo.
    echo Open:
    echo   %REPORTS%\ALL_NSFW_VIDEOS.csv
    echo.
    echo Review the results BEFORE using the optional mover.
) else if "%RC%"=="130" (
    echo ============================================================================
    echo SCAN STOPPED BY USER
    echo ============================================================================
    echo.
    echo Completed rows were preserved.
    echo Run this BAT again later to continue.
) else (
    echo ============================================================================
    echo SCAN ENDED WITH ERROR %RC%
    echo ============================================================================
    echo.
    echo Completed rows were preserved where possible.
    echo See TROUBLESHOOTING.md in the GitHub package.
)

echo.
pause
exit /b %RC%
