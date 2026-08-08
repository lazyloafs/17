@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  Opt DPS — Deep optimize for maximum damage (single phase, 60 gens)
rem  Patches PoB, queues DPS optimize, launches Path of Building.
rem
rem  Usage: double-click from Desktop, or:
rem    Opt_DPS.bat
rem
rem  Set POB_PATH if PoB is not at E:\Path of Building Community
rem ============================================================================

set "REPO_DIR=%~dp0"

echo Patching PoB and queueing DPS optimize...
powershell -ExecutionPolicy Bypass -File "%REPO_DIR%scripts\run-headless.ps1" -Mode dps -Generations 60 -Population 60
if errorlevel 1 (
    echo Failed. Check POB_PATH and PowerShell execution policy.
    pause
    exit /b 1
)

set "POB_DIR=%POB_PATH%"
if "%POB_DIR%"=="" set "POB_DIR=E:\Path of Building Community"

if not exist "%POB_DIR%\Path of Building.exe" (
    echo Could not find "Path of Building.exe" in "%POB_DIR%".
    echo Set POB_PATH to your Path of Building Community folder and try again.
    pause
    exit /b 1
)

echo.
echo PoB will open (or is already running). Load your build, go to Tree tab.
echo Click "Opt DPS" or wait for auto-run when the build loads.
echo.

start "" "%POB_DIR%\Path of Building.exe"
endlocal
