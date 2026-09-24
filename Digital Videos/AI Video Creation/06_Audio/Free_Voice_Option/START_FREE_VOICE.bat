@echo off
setlocal
cd /d "%~dp0"
echo AI SHORT - FREE VOICE SAMPLE - No paid credits required
where py >nul 2>&1
if errorlevel 1 (
  echo Python launcher missing. Install Python 3.11+ from https://www.python.org/downloads/windows/
  pause
  exit /b 1
)
py -m pip install -U edge-tts
if errorlevel 1 (
  echo Installation failed. Check internet access.
  pause
  exit /b 2
)
py "%~dp0generate_voice.py" --voice andrew
if errorlevel 1 (
  echo Generation failed. Check the message above.
  pause
  exit /b 3
)
echo Listen to the MP3 inside output. Try: py generate_voice.py --voice brian
pause
