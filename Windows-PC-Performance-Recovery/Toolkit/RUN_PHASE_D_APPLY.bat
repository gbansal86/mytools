@echo off
setlocal EnableExtensions DisableDelayedExpansion
echo Starting Windows Performance Recovery Toolkit...
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" goto missingPS
if not exist "%~dp0Launch.ps1" goto missingFiles
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch.ps1" -Action Apply
set "RC=%errorlevel%"
if "%RC%"=="0" exit /b 0
echo.
echo STARTUP OR TOOLKIT ERROR. Exit code: %RC%
echo Read the error above. Extract the entire ZIP before running.
echo If organizational policy blocks PowerShell, contact your administrator.
echo Startup logs are saved under your TEMP folder as PC_Recovery_Startup_*.log.
pause
exit /b %RC%
:missingPS
echo ERROR: Windows PowerShell was not found.
pause
exit /b 2
:missingFiles
echo ERROR: Required launcher is missing. Extract the entire ZIP first.
pause
exit /b 2
