@echo off
setlocal

REM ================================================================
REM ZIP BULK EXTRACTOR - SEPARATE FOLDER MODE (RECOMMENDED)
REM ------------------------------------------------
REM What this script does:
REM   1. Looks for every *.zip file beside this BAT file.
REM   2. Creates a folder using each ZIP file's name.
REM   3. Extracts that ZIP into its matching folder.
REM   4. Keeps the original ZIP files.
REM
REM Example:
REM   Photos.zip  ->  Photos\
REM   Books.zip   ->  Books\
REM
REM Windows PowerShell Expand-Archive is used, so no third-party
REM archive software is needed for ordinary ZIP files.
REM ================================================================

pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not open the folder containing this script.
    pause
    exit /b 1
)

echo ============================================================
echo           EXTRACT EACH ZIP INTO ITS OWN FOLDER
echo ============================================================
echo Folder:
echo %CD%
echo.
echo Original ZIP files will NOT be deleted.
echo.

set "FOUND=0"
set "FAILED=0"

for %%F in (*.zip) do (
    if exist "%%~fF" (
        set "FOUND=1"
        set "ZIP_SOURCE=%%~fF"
        set "ZIP_DEST=%%~dpnF"

        echo [EXTRACT] %%~nxF
        echo           -^> %%~nF\

        powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
          "try { New-Item -ItemType Directory -Path $env:ZIP_DEST -Force | Out-Null; Expand-Archive -LiteralPath $env:ZIP_SOURCE -DestinationPath $env:ZIP_DEST -Force -ErrorAction Stop; exit 0 } catch { Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"

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
