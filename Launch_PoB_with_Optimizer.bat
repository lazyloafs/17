@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  Launch PoB with Optimizer — localoptimizer
rem  Patches PoB (~1s), optionally queues 60+60 dual-phase optimize, starts PoB.
rem
rem  Usage:
rem    Launch_PoB_with_Optimizer.bat              Normal launch (patch + PoB)
rem    Launch_PoB_with_Optimizer.bat optimize     Launch + queue 60 main + 60 opposite gens
rem    Launch_PoB_with_Optimizer.bat verify       Launch + load baseline build hint
rem
rem  Set POB_PATH if PoB is not at E:\Path of Building Community
rem ============================================================================

set "REPO_DIR=%~dp0"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=launch"

rem --- Patch PoB (idempotent) ---
powershell -ExecutionPolicy Bypass -File "%REPO_DIR%install-button.ps1"
if errorlevel 1 (
    echo Patch failed. Check POB_PATH and PowerShell execution policy.
    pause
    exit /b 1
)

rem --- Resolve PoB directory ---
set "POB_DIR=%POB_PATH%"
if "%POB_DIR%"=="" set "POB_DIR=E:\Path of Building Community"

if not exist "%POB_DIR%\Path of Building.exe" (
    echo Could not find "Path of Building.exe" in "%POB_DIR%".
    echo Set POB_PATH to your Path of Building Community folder and try again.
    pause
    exit /b 1
)

rem --- Queue dual-phase 60+60 optimize request when requested ---
if /I "%MODE%"=="optimize" (
    echo Queueing dual-phase optimizer: 60 main ^(DPS^) + 60 opposite ^(regen/eHP^)...
    powershell -ExecutionPolicy Bypass -File "%REPO_DIR%scripts\run-headless.ps1" ^
        -Archetype rf_arcane_devotion -Generations 60 -Population 60 -DualPhase
    echo.
    echo After PoB opens: load your RF build, go to Tree tab, click "Deep Optimize" or wait for auto-run.
    echo Baseline for comparison: %REPO_DIR%builds\baseline_rf_arcane_devotion.pob.txt
    echo.
)

if /I "%MODE%"=="verify" (
    echo.
    echo VERIFICATION BASELINE
    echo Import this PoB code before optimizing, then compare DPS + regen after 60+60:
    echo   %REPO_DIR%builds\baseline_rf_arcane_devotion.pob.txt
    echo.
    echo Target improvements vs baseline:
    echo   - Higher Total DPS ^(main phase 60 gens^)
    echo   - Net positive regen after RF burn ^(opposite phase 60 gens^)
    echo   - Split Personality jewels on farthest sockets / zigzag paths
    echo.
    start "" notepad "%REPO_DIR%builds\baseline_rf_arcane_devotion.pob.txt"
)

rem --- Copy baseline path to PoB settings for in-app reference ---
set "SETTINGS=%APPDATA%\Path of Building\Settings"
if not exist "%SETTINGS%" mkdir "%SETTINGS%"
echo %REPO_DIR%builds\baseline_rf_arcane_devotion.pob.txt> "%SETTINGS%\localoptimizer_baseline.txt"

rem --- Start Path of Building ---
start "" "%POB_DIR%\Path of Building.exe"

endlocal
