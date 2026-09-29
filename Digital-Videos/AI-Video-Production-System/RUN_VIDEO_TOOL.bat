@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  echo Usage:
  echo   RUN_VIDEO_TOOL.bat create "C:\path\video.mp4"
  echo   RUN_VIDEO_TOOL.bat analyze "VIDEO_PROJECTS\project-folder"
  echo   RUN_VIDEO_TOOL.bat transcribe "VIDEO_PROJECTS\project-folder"
  echo   RUN_VIDEO_TOOL.bat status "VIDEO_PROJECTS\project-folder"
  exit /b 2
)
if /I "%~1"=="create" (
  python workflow\video_project.py "%~2" VIDEO_PROJECTS
  exit /b %errorlevel%
)
if /I "%~1"=="analyze" (
  python workflow\pipeline.py "%~2" analyze
  exit /b %errorlevel%
)
if /I "%~1"=="transcribe" (
  python workflow\pipeline.py "%~2" transcribe
  exit /b %errorlevel%
)
if /I "%~1"=="status" (
  python workflow\pipeline.py "%~2" status
  exit /b %errorlevel%
)
echo Unknown command: %~1
exit /b 2
