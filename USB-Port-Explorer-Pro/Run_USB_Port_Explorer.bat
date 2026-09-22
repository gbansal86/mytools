@echo off
rem USB Port Explorer Pro launcher.
rem This changes only PowerShell execution policy for THIS ONE PROCESS; it does
rem not modify your permanent Windows execution-policy setting.
rem -STA is required by the Windows Forms GUI.
cd /d "%~dp0"
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo Windows PowerShell was not found.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0USB_Port_Explorer.ps1"
if errorlevel 1 (
    echo.
    echo USB Port Explorer stopped with an error.
    pause
)
