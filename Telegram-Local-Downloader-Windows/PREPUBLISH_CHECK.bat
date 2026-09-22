@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>&1
if %errorlevel%==0 (
    py prepublish_check.py
) else (
    python prepublish_check.py
)

set "RC=%errorlevel%"
echo.
if not "%RC%"=="0" echo Fix the reported items before pushing this repository publicly.
pause
exit /b %RC%
