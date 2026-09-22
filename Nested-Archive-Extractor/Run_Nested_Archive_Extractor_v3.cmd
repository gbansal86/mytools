@echo off
setlocal
cd /d "%~dp0"

REM Launch PowerShell in STA mode because Windows Forms requires it.
REM ExecutionPolicy Bypass applies only to this one PowerShell process.
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Nested_Archive_Extractor_GUI_v3.ps1"

if errorlevel 1 (
  echo.
  echo The GUI could not start. Read the error shown above.
  pause
)

endlocal
