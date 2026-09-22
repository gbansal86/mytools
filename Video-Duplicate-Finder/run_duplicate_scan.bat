@echo off
setlocal
cd /d "%~dp0"
title Video Duplicate Finder

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

echo ERROR: Python 3.10 or newer was not found.
echo Run INSTALL_FIRST.bat after installing Python.
pause
exit /b 1

:run
"%PYEXE%" "%~dp0find_duplicate_videos.py"
set "RC=%errorlevel%"
echo.
if "%RC%"=="0" (
  echo Scan complete. Review duplicate_groups.txt and duplicate_report.csv.
) else (
  echo Scan ended with error code %RC%.
)
pause
exit /b %RC%
