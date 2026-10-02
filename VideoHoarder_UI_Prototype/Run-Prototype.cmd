@echo off
setlocal
set "ROOT=%~dp0"
set "DOTNET_ROOT=%ROOT%tools\dotnet"
set "DOTNET_CLI_HOME=%ROOT%tools\dotnet-home"
set "NUGET_PACKAGES=%ROOT%tools\nuget-cache"
set "TEMP=%ROOT%tools\temp"
set "TMP=%ROOT%tools\temp"
set "DOTNET_MULTILEVEL_LOOKUP=0"
set "DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1"
if not exist "%DOTNET_ROOT%\dotnet.exe" (
  echo Portable .NET is missing. Run Setup-Portable-Tools.cmd first.
  pause
  exit /b 1
)
if not exist "%ROOT%app\VideoHoarderPrototype.dll" (
  echo Prototype build is missing. Run Build-Prototype.cmd first.
  pause
  exit /b 1
)
start "" "%DOTNET_ROOT%\dotnet.exe" "%ROOT%app\VideoHoarderPrototype.dll"
exit /b 0
