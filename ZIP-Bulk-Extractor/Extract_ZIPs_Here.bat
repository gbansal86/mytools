@echo off
setlocal

REM ================================================================
REM ZIP BULK EXTRACTOR - SAME FOLDER MODE
REM ------------------------------------------------
REM What this script does:
REM   1. Looks for every *.zip file beside this BAT file.
REM   2. Extracts the CONTENTS directly into that same folder.
REM   3. Keeps the original ZIP files.
REM
REM Important:
REM   - "-Force" allows existing files with the same name to be
REM     overwritten.
REM   - ZIP contents from different archives can mix together.
REM   - Windows PowerShell Expand-Archive is used; no extra software
REM     is required on normal Windows 10/11 systems.
REM ================================================================

pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not open the folder containing this script.
    pause
    exit /b 1
)

echo ============================================================
echo          EXTRACT ALL ZIP FILES INTO THIS FOLDER
echo ============================================================
echo Folder:
echo %CD%
echo.
echo WARNING:
echo Files with the same name may be overwritten.
echo Original ZIP files will NOT be deleted.
echo.
choice /C YN /N /M "Continue? [Y/N]: "
if errorlevel 2 (
    echo.
    echo Cancelled. Nothing was changed.
    popd
    pause
    exit /b 0
)

set "FOUND=0"
set "FAILED=0"

echo.
for %%F in (*.zip) do (
    if exist "%%~fF" (
        set "FOUND=1"
        set "ZIP_SOURCE=%%~fF"
        set "ZIP_DEST=%%~dpF"

        echo [EXTRACT] %%~nxF

        powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
          "try { Expand-Archive -LiteralPath $env:ZIP_SOURCE -DestinationPath $env:ZIP_DEST -Force -ErrorAction Stop; exit 0 } catch { Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"

        if errorlevel 1 (
            echo [FAILED ] %%~nxF
            set "FAILED=1"
        ) else (
            echo [OK     ] %%~nxF
        )
        echo.
    )
)

if "%FOUND%"=="0" (
    echo No ZIP files were found beside this script.
    echo Put the BAT file in the folder containing your ZIP files.
) else (
    if "%FAILED%"=="0" (
        echo ============================================================
        echo Finished successfully.
        echo ============================================================
    ) else (
        echo ============================================================
        echo Finished, but one or more ZIP files could not be extracted.
        echo Read the error shown above for the affected ZIP.
        echo ============================================================
    )
)

popd
echo.
pause
exit /b 0
