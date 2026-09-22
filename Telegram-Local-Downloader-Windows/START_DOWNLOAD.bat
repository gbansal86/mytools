@echo off
setlocal
cd /d "%~dp0"
title Telegram Local Downloader

echo ============================================================
echo TELEGRAM TO PC - NO UPLOADS
echo ============================================================

where py >nul 2>&1
if %errorlevel%==0 (
    set "PY=py"
) else (
    where python >nul 2>&1
    if %errorlevel% neq 0 (
        echo ERROR: Python not found. Install Python 3.10+ from python.org.
        goto :finish
    )
    set "PY=python"
)

if not exist ".venv\Scripts\python.exe" (
    echo Creating local Python environment...
    %PY% -m venv ".venv"
    if errorlevel 1 (
        echo ERROR: Could not create Python environment.
        goto :finish
    )
)

".venv\Scripts\python.exe" -c "import telethon" >nul 2>&1
if errorlevel 1 (
    echo Installing required Telegram library in this folder...
    ".venv\Scripts\python.exe" -m pip install "telethon>=1.36,<2"
    if errorlevel 1 (
        echo ERROR: Installation failed. Check your internet connection.
        goto :finish
    )
)

if not exist ".venv\cryptg_install_checked.flag" (
    echo Checking optional fast crypto library...
    ".venv\Scripts\python.exe" -m pip install --only-binary=:all: cryptg
    if errorlevel 1 echo Optional cryptg wheel not available; continuing with standard download engine.
    echo checked> ".venv\cryptg_install_checked.flag"
)

echo.
echo Parallel file count is configured in download_options.json (default 3, max 4).
echo.
echo Reading channels from channels.txt...
".venv\Scripts\python.exe" telegram_download.py
if errorlevel 1 echo Downloader exited with an error.

:finish
echo.
pause
endlocal
