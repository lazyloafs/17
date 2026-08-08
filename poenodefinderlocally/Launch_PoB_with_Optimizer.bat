@echo off
rem Standalone launcher: patches PoB with the deep optimizer, then starts Path of Building.
rem Use this instead of the plain PoB shortcut so updates never remove the Optimize button.

powershell -ExecutionPolicy Bypass -File "%~dp0install-button.ps1"

set "POB_DIR=%POB_PATH%"
if "%POB_DIR%"=="" set "POB_DIR=E:\Path of Building Community"

if exist "%POB_DIR%\Path of Building.exe" (
    start "" "%POB_DIR%\Path of Building.exe"
) else (
    echo Could not find "Path of Building.exe" in "%POB_DIR%".
    echo Set the POB_PATH environment variable to your PoB folder and try again.
    pause
)
