@echo off
setlocal
set "TOOLS_ROOT=%~dp0.."
set "DOTNET_ROOT=%TOOLS_ROOT%\dotnet"
set "DOTNET_CLI_HOME=%TOOLS_ROOT%\dotnet-home"
set "NUGET_PACKAGES=%TOOLS_ROOT%\nuget-cache"
set "TEMP=%TOOLS_ROOT%\temp"
set "TMP=%TOOLS_ROOT%\temp"
set "DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1"
set "DOTNET_CLI_TELEMETRY_OPTOUT=1"
set "DOTNET_MULTILEVEL_LOOKUP=0"
if not exist "%DOTNET_CLI_HOME%" mkdir "%DOTNET_CLI_HOME%"
if not exist "%NUGET_PACKAGES%" mkdir "%NUGET_PACKAGES%"
if not exist "%TEMP%" mkdir "%TEMP%"
"%DOTNET_ROOT%\dotnet.exe" %*
exit /b %ERRORLEVEL%
