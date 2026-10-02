@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%tools\dotnet\dotnet.exe" (
  echo Portable .NET is missing. Run Setup-Portable-Tools.cmd first.
  exit /b 1
)
call "%ROOT%tools\scripts\dotnet-local.cmd" build "%ROOT%src\VideoHoarderPrototype\VideoHoarderPrototype.csproj" -c Release --nologo --configfile "%ROOT%src\VideoHoarderPrototype\NuGet.Config"
if errorlevel 1 exit /b %errorlevel%
copy /Y "%ROOT%src\VideoHoarderPrototype\bin\Release\net10.0-windows\VideoHoarderPrototype.*" "%ROOT%app\" >nul
echo Build complete.
