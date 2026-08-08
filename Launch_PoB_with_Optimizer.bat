@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  Launch PoB with Optimizer — localoptimizer
rem  Patches PoB (~1s), optionally queues 60+60 dual-phase optimize, starts PoB.
rem
rem  THIS is the correct local launcher (NO 600-second time budget).
rem  If you see "Time budget: 600 seconds" / "NSGA-II Opt DPS", you started
rem  a different optimizer .bat — use this file (or the Desktop copy) instead.
rem
rem  Usage:
rem    Launch_PoB_with_Optimizer.bat              Patch + start PoB
rem    Launch_PoB_with_Optimizer.bat optimize     Patch + queue 60 main + 60 opposite gens + start
rem    Launch_PoB_with_Optimizer.bat verify       Patch + decode/validate baseline + open code
rem    Launch_PoB_with_Optimizer.bat status       Show last optimizer result / queued request
rem    Launch_PoB_with_Optimizer.bat desktop      Copy this launcher to your Desktop
rem
rem  Set POB_PATH if PoB is not at E:\Path of Building Community
rem ============================================================================

set "REPO_DIR=%~dp0"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=launch"

rem --- One-shot: install Desktop launcher stub ---
if /I "%MODE%"=="desktop" (
    call "%REPO_DIR%Put_Launcher_on_Desktop.bat"
    exit /b %ERRORLEVEL%
)

set "SETTINGS=%APPDATA%\Path of Building\Settings"
if not exist "%SETTINGS%" mkdir "%SETTINGS%"
set "LOG=%SETTINGS%\localoptimizer.log"

call :log "=== localoptimizer Launch_PoB_with_Optimizer mode=%MODE% ==="

rem --- Patch PoB (idempotent) ---
powershell -ExecutionPolicy Bypass -File "%REPO_DIR%install-button.ps1"
if errorlevel 1 (
    echo Patch failed. Check POB_PATH and PowerShell execution policy.
    call :log "ERROR patch failed"
    pause
    exit /b 1
)

rem --- Resolve PoB directory ---
set "POB_DIR=%POB_PATH%"
if "%POB_DIR%"=="" set "POB_DIR=E:\Path of Building Community"

if not exist "%POB_DIR%\Path of Building.exe" (
    echo Could not find "Path of Building.exe" in "%POB_DIR%".
    echo Set POB_PATH to your Path of Building Community folder and try again.
    call :log "ERROR PoB missing at %POB_DIR%"
    pause
    exit /b 1
)

set "BASELINE=%REPO_DIR%builds\baseline_rf_arcane_devotion.pob.txt"
if not exist "%BASELINE%" (
    echo WARNING: baseline build missing: %BASELINE%
    call :log "WARN baseline missing"
)

rem --- status: show queue + last result ---
if /I "%MODE%"=="status" (
    echo.
    echo === localoptimizer status ===
    if exist "%SETTINGS%\headless_optimizer_request.json" (
        echo Queued request:
        type "%SETTINGS%\headless_optimizer_request.json"
        echo.
    ) else (
        echo No queued headless request.
    )
    if exist "%SETTINGS%\localoptimizer_last_result.json" (
        echo Last result:
        type "%SETTINGS%\localoptimizer_last_result.json"
        echo.
    ) else (
        echo No last result yet. Run optimize then open a build in PoB.
    )
    if exist "%LOG%" (
        echo Recent log:
        powershell -NoProfile -Command "Get-Content -Path '%LOG%' -Tail 12"
    )
    echo.
    goto :eof
)

rem --- Queue dual-phase 60+60 optimize request when requested ---
if /I "%MODE%"=="optimize" (
    echo.
    echo Queueing dual-phase optimizer:
    echo   Phase 1: 60 gens x 60 pop  — main objective ^(max DPS / mana^)
    echo   Phase 2: 60 gens x 60 pop  — opposite ^(regen/eHP^), retain ^>=92%% phase-1 DPS
    echo   Tree:    connected mutation + skill-point budget + SP zigzag sockets
    echo   Time:    NO wall-clock limit ^(local — finishes all generations^)
    echo.
    powershell -ExecutionPolicy Bypass -File "%REPO_DIR%scripts\run-headless.ps1" ^
        -Archetype rf_arcane_devotion -Generations 60 -Population 60 -DualPhase -OptimizeJewels
    if errorlevel 1 (
        echo Failed to queue optimizer request.
        call :log "ERROR queue failed"
        pause
        exit /b 1
    )
    echo.
    echo After PoB opens: load your RF build ^(or import baseline^), Tree tab -^> Deep Optimize,
    echo or wait for the queued headless run to pick up the request.
    echo Baseline: %BASELINE%
    echo Result:   %SETTINGS%\localoptimizer_last_result.json
    echo.
    call :log "queued dual-phase 60+60 optimize"
)

if /I "%MODE%"=="verify" (
    echo.
    echo VERIFICATION — RF Arcane Devotion baseline
    echo -------------------------------------------
    if exist "%REPO_DIR%scripts\verify-baseline.py" (
        where python >nul 2>&1
        if not errorlevel 1 (
            python "%REPO_DIR%scripts\verify-baseline.py" "%BASELINE%"
        ) else (
            where py >nul 2>&1
            if not errorlevel 1 (
                py "%REPO_DIR%scripts\verify-baseline.py" "%BASELINE%"
            ) else (
                echo Python not found — skipping decode checks. Baseline file:
                echo   %BASELINE%
            )
        )
    )
    echo.
    echo Target improvements after 60+60:
    echo   - Higher Total DPS ^(main phase^)
    echo   - Net positive regen after RF burn ^(opposite phase, retain DPS^)
    echo   - Split Personality on farthest sockets / longer zigzag allocated paths
    echo.
    echo Import the baseline PoB code, note DPS+regen, run Deep Optimize, compare.
    start "" notepad "%BASELINE%"
    call :log "verify opened baseline"
)

rem --- Copy baseline path for in-app reference ---
echo %BASELINE%> "%SETTINGS%\localoptimizer_baseline.txt"

rem --- Start Path of Building (skip for status-only; status already exited) ---
if /I not "%MODE%"=="status" (
    echo Starting Path of Building...
    start "" "%POB_DIR%\Path of Building.exe"
    call :log "started PoB from %POB_DIR%"
)

endlocal
goto :eof

:log
echo %DATE% %TIME% %~1>> "%LOG%"
goto :eof
