@echo off
setlocal
cd /d "%~dp0"
title Video Duplicate Finder - Setup

set "PYEXE="
python -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%A in ('where python 2^>nul') do (
    set "PYEXE=%%A"
    goto :run
  )
)
py -3 -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%A in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do (
    set "PYEXE=%%A"
    goto :run
  )
)

echo ERROR: Python 3.10 or newer is required.
echo Install Python from python.org, enable "Add Python to PATH", then run this file again.
pause
exit /b 1

:run
echo Using Python: %PYEXE%
"%PYEXE%" "%~dp0setup_prerequisites.py"
set "RC=%errorlevel%"
echo.
if not "%RC%"=="0" echo Setup failed. Open install_log.txt for details.
pause
exit /b %RC%
