@echo off
rem ============================================================================
rem Book Duplicate Finder - beginner launcher
rem
rem What this file does:
rem   1. Changes to this tool's folder.
rem   2. Looks for Python 3 ("py -3" first, then "python").
rem   3. Runs bootstrap.py, which keeps dependencies inside this folder.
rem   4. Leaves the window open so you can read any error message.
rem ============================================================================
setlocal
cd /d "%~dp0"
title Book Content Duplicate Finder

echo ============================================================
echo BOOK CONTENT DUPLICATE FINDER
echo ============================================================
echo.

where py >nul 2>&1
if %errorlevel%==0 (
    set "PY=py -3"
) else (
    where python >nul 2>&1
    if %errorlevel%==0 (
        set "PY=python"
    ) else (
        echo ERROR: Python 3 was not found.
        echo Install Python 3 from https://www.python.org/downloads/
        echo During setup, tick "Add python.exe to PATH".
        echo.
        pause
        exit /b 2
    )
)

echo Using Python: %PY%
echo.
%PY% bootstrap.py
set RC=%errorlevel%

echo.
if not "%RC%"=="0" (
    echo Scan ended with error code %RC%.
) else (
    echo Scan finished.
)
echo.
pause
exit /b %RC%
