@echo off
setlocal
cd /d "%~dp0"

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo.
    echo ERROR: Windows PowerShell was not found.
    echo This application requires Windows PowerShell 5.1 or later.
    echo.
    pause
    exit /b 2
)

rem Start PowerShell hidden and detached, then close this CMD window immediately.
start "" /b powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0Course_Library_Manager.ps1" -NoConsole
exit /b 0
