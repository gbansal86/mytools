@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%tools\scripts" mkdir "%ROOT%tools\scripts"
if not exist "%ROOT%tools\dotnet" mkdir "%ROOT%tools\dotnet"
if not exist "%ROOT%tools\nuget-cache" mkdir "%ROOT%tools\nuget-cache"
if not exist "%ROOT%tools\dotnet-home" mkdir "%ROOT%tools\dotnet-home"
if not exist "%ROOT%tools\temp" mkdir "%ROOT%tools\temp"
if not exist "%ROOT%tools\scripts\dotnet-install.ps1" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1' -OutFile '%ROOT%tools\scripts\dotnet-install.ps1'"
)
if errorlevel 1 exit /b %errorlevel%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\scripts\dotnet-install.ps1" -Channel 10.0 -Quality GA -Architecture x64 -InstallDir "%ROOT%tools\dotnet" -NoPath
if errorlevel 1 exit /b %errorlevel%
echo.
echo Portable .NET installed under tools\dotnet.
pause
