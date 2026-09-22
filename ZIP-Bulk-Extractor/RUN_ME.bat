@echo off
setlocal
cd /d "%~dp0"

title ZIP Bulk Extractor

:MENU
cls
echo ============================================================
echo                    ZIP BULK EXTRACTOR
echo ============================================================
echo.
echo Put this tool in the SAME folder as the ZIP files.
echo.
echo   [1] Extract each ZIP into its OWN folder  ^(recommended^)
echo       Example: Course.zip  -^>  Course\
echo.
echo   [2] Extract every ZIP directly into THIS folder
echo       WARNING: files from different ZIPs can mix/overwrite.
echo.
echo   [3] Exit
echo.
choice /C 123 /N /M "Choose 1, 2, or 3: "

if errorlevel 3 exit /b 0
if errorlevel 2 call "%~dp0Extract_ZIPs_Here.bat"
if errorlevel 1 call "%~dp0Extract_ZIPs_Separate_Folders.bat"

goto MENU
