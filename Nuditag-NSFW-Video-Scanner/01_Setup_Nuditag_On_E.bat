@echo off
setlocal EnableExtensions
title Nuditag NSFW Video Scanner - Setup on E Drive

REM ============================================================================
REM 01_Setup_Nuditag_On_E.bat
REM
REM PURPOSE
REM   Installs a private Python + Nuditag environment under E:\Nuditag.
REM   Git is NOT required.
REM
REM WHAT IT CREATES
REM   E:\Nuditag\Python       - private Python installation
REM   E:\Nuditag\venv         - Nuditag and Python dependencies
REM   E:\Nuditag\ModelCache   - downloaded AI model
REM   E:\Nuditag\Cache        - runtime cache
REM   E:\Nuditag\Reports      - scan reports and mover logs
REM   E:\Nuditag\Temp         - temporary setup/runtime files
REM
REM SAFETY
REM   This setup script does NOT scan, move, rename, or delete your videos.
REM ============================================================================

set "ROOT=E:\Nuditag"
set "SCRIPT_DIR=%~dp0"
set "PYTHON_DIR=%ROOT%\Python"
set "VENV=%ROOT%\venv"
set "TEMP_DIR=%ROOT%\Temp"
set "CACHE_DIR=%ROOT%\Cache"
set "MODEL_DIR=%ROOT%\ModelCache"
set "REPORTS=%ROOT%\Reports"

set "PYTHON_EXE=%PYTHON_DIR%\python.exe"
set "VENV_PYTHON=%VENV%\Scripts\python.exe"
set "NUDITAG=%VENV%\Scripts\nuditag.exe"

REM Python 3.12.10 official 64-bit Windows installer.
set "PYTHON_VERSION=3.12.10"
set "PYTHON_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-amd64.exe"
set "PYTHON_INSTALLER=%TEMP_DIR%\python-%PYTHON_VERSION%-amd64.exe"

REM Pin Nuditag to the version this wrapper was checked against.
REM This avoids a future upstream code change unexpectedly breaking the helper script.
set "NUDITAG_COMMIT=f34134341b62cb320ac299e60335d432f19d6ebf"
set "NUDITAG_URL=https://github.com/ICIJ/nuditag/archive/%NUDITAG_COMMIT%.zip"

if not exist E:\ (
    echo.
    echo ============================================================================
    echo ERROR: E: DRIVE WAS NOT FOUND
    echo ============================================================================
    echo.
    echo Connect or create the E: drive, then run this file again.
    echo.
    pause
    exit /b 1
)

mkdir "%ROOT%" 2>nul
mkdir "%PYTHON_DIR%" 2>nul
mkdir "%TEMP_DIR%" 2>nul
mkdir "%CACHE_DIR%" 2>nul
mkdir "%MODEL_DIR%" 2>nul
mkdir "%REPORTS%" 2>nul

REM Keep our temporary files and model/cache data on E: during setup.
set "TEMP=%TEMP_DIR%"
set "TMP=%TEMP_DIR%"
set "HF_HOME=%MODEL_DIR%"
set "HF_HUB_CACHE=%MODEL_DIR%\hub"
set "XDG_CACHE_HOME=%CACHE_DIR%"
set "PIP_CACHE_DIR=%CACHE_DIR%\pip"
set "PIP_NO_CACHE_DIR=1"
set "PIP_DISABLE_PIP_VERSION_CHECK=1"
set "PYTHONNOUSERSITE=1"

echo.
echo ============================================================================
echo NUDITAG NSFW VIDEO SCANNER - SETUP
echo ============================================================================
echo.
echo Install location : %ROOT%
echo Python           : %PYTHON_VERSION%
echo Git required     : NO
echo.
echo NOTE: Some installation steps can look idle for several minutes.
echo       Leave the window open unless an ERROR is displayed.
echo.

if exist "%PYTHON_EXE%" (
    echo [OK] Python already exists at:
    echo      %PYTHON_EXE%
) else (
    echo [1/5] Downloading Python %PYTHON_VERSION%...
    call :DOWNLOAD "%PYTHON_URL%" "%PYTHON_INSTALLER%"
    if errorlevel 1 (
        echo.
        echo ERROR: Could not download Python.
        goto FATAL
    )

    echo.
    echo [2/5] Installing Python under E:\Nuditag\Python...
    echo       This can take a few minutes and may appear to pause.
    echo.

    start /wait "" "%PYTHON_INSTALLER%" /quiet ^
        InstallAllUsers=0 ^
        TargetDir="%PYTHON_DIR%" ^
        Include_exe=1 ^
        Include_lib=1 ^
        Include_pip=1 ^
        Include_dev=1 ^
        Include_launcher=0 ^
        Include_test=0 ^
        Include_doc=0 ^
        Include_tcltk=0 ^
        Include_tools=1 ^
        Include_symbols=0 ^
        Include_debug=0 ^
        AssociateFiles=0 ^
        Shortcuts=0 ^
        PrependPath=0

    if errorlevel 1 (
        echo.
        echo ERROR: Python installer returned an error.
        goto FATAL
    )

    if not exist "%PYTHON_EXE%" (
        echo.
        echo ERROR: Python installer finished, but python.exe was not found:
        echo        %PYTHON_EXE%
        goto FATAL
    )
)

"%PYTHON_EXE%" --version
if errorlevel 1 goto FATAL

if exist "%VENV_PYTHON%" (
    echo.
    echo [OK] Existing Nuditag Python environment found.
) else (
    echo.
    echo [3/5] Creating isolated Python environment...
    "%PYTHON_EXE%" -m venv "%VENV%"
    if errorlevel 1 (
        echo ERROR: Could not create %VENV%
        goto FATAL
    )
)

echo.
echo [4/5] Preparing pip...
"%VENV_PYTHON%" -m pip install --upgrade pip setuptools wheel
if errorlevel 1 goto FATAL

if exist "%NUDITAG%" (
    echo.
    echo [OK] Nuditag is already installed:
    echo      %NUDITAG%
) else (
    echo.
    echo [5/5] Installing Nuditag and dependencies...
    echo       Git is not used. The source ZIP comes directly from GitHub.
    echo       The last few Python packages can take several minutes.
    echo.

    "%VENV_PYTHON%" -m pip install "%NUDITAG_URL%"
    if errorlevel 1 (
        echo.
        echo ERROR: Nuditag installation failed.
        goto FATAL
    )
)

if not exist "%NUDITAG%" (
    echo.
    echo ERROR: Nuditag executable was not created:
    echo        %NUDITAG%
    goto FATAL
)

"%NUDITAG%" --help >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Nuditag exists but could not start.
    goto FATAL
)

echo.
echo Copying scanner helper files into %ROOT% ...

call :COPY_REQUIRED "%SCRIPT_DIR%nuditag_custom_scan.py" "%ROOT%\nuditag_custom_scan.py"
if errorlevel 1 goto FATAL

call :COPY_REQUIRED "%SCRIPT_DIR%02_Run_Custom_Scan.bat" "%ROOT%\02_Run_Custom_Scan.bat"
if errorlevel 1 goto FATAL

call :COPY_REQUIRED "%SCRIPT_DIR%03_Move_NSFW_From_Report.bat" "%ROOT%\03_Move_NSFW_From_Report.bat"
if errorlevel 1 goto FATAL

call :COPY_REQUIRED "%SCRIPT_DIR%Move_NSFW_From_Report.ps1" "%ROOT%\Move_NSFW_From_Report.ps1"
if errorlevel 1 goto FATAL

if not exist "%ROOT%\SearchPaths.txt" (
    call :COPY_REQUIRED "%SCRIPT_DIR%SearchPaths.txt" "%ROOT%\SearchPaths.txt"
    if errorlevel 1 goto FATAL
)

if not exist "%ROOT%\ExcludePaths.txt" (
    call :COPY_REQUIRED "%SCRIPT_DIR%ExcludePaths.txt" "%ROOT%\ExcludePaths.txt"
    if errorlevel 1 goto FATAL
)

(
    echo @echo off
    echo set "HF_HOME=%MODEL_DIR%"
    echo set "HF_HUB_CACHE=%MODEL_DIR%\hub"
    echo set "XDG_CACHE_HOME=%CACHE_DIR%"
    echo set "TEMP=%TEMP_DIR%"
    echo set "TMP=%TEMP_DIR%"
    echo "%NUDITAG%" %%*
) > "%ROOT%\nuditag.bat"

echo.
echo Cleaning temporary setup files...

if exist "%PYTHON_INSTALLER%" del /f /q "%PYTHON_INSTALLER%" >nul 2>&1
if exist "%CACHE_DIR%\pip" rmdir /s /q "%CACHE_DIR%\pip" >nul 2>&1

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1
mkdir "%TEMP_DIR%" >nul 2>&1

echo.
echo ============================================================================
echo SETUP COMPLETE
echo ============================================================================
echo.
echo Nuditag is installed under:
echo   %ROOT%
echo.
echo Next:
echo   1. Open %ROOT%\SearchPaths.txt
echo   2. Open %ROOT%\ExcludePaths.txt
echo   3. Run %ROOT%\02_Run_Custom_Scan.bat
echo.
echo The AI model downloads automatically the first time a scan needs it.
echo It will be cached under:
echo   %MODEL_DIR%
echo.
pause
exit /b 0

:DOWNLOAD
set "DL_URL=%~1"
set "DL_FILE=%~2"

if exist "%DL_FILE%" del /f /q "%DL_FILE%" >nul 2>&1

where curl.exe >nul 2>&1
if not errorlevel 1 (
    curl.exe -L --fail --retry 3 --retry-delay 3 --connect-timeout 30 ^
        -o "%DL_FILE%" "%DL_URL%"
    if exist "%DL_FILE%" exit /b 0
)

echo curl download failed or was unavailable.
echo Trying Windows PowerShell...

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
    -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '%DL_URL%' -OutFile '%DL_FILE%'"

if exist "%DL_FILE%" exit /b 0
exit /b 1

:COPY_REQUIRED
if not exist "%~1" (
    echo.
    echo ERROR: Required package file is missing:
    echo        %~1
    exit /b 1
)
copy /y "%~1" "%~2" >nul
if errorlevel 1 exit /b 1
exit /b 0

:FATAL
echo.
echo ============================================================================
echo SETUP FAILED
echo ============================================================================
echo.
echo Existing files under E:\Nuditag were left in place for troubleshooting.
echo Re-running setup is safe; completed installation steps are reused.
echo.
pause
exit /b 1
