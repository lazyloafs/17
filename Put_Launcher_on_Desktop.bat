@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  Puts a Desktop shortcut-launcher for the CORRECT localoptimizer bat.
rem  Run this once from the localoptimizer folder on your PC.
rem
rem  Your NSGA-II console ("Time budget: 600 seconds") is a DIFFERENT tool.
rem  Use the Desktop launcher created here — not that NSGA Opt DPS window.
rem ============================================================================

set "REPO_DIR=%~dp0"
set "REPO_DIR=%REPO_DIR:~0,-1%"
set "SRC=%REPO_DIR%\Launch_PoB_with_Optimizer.bat"
set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" set "DESKTOP=%USERPROFILE%\OneDrive\Desktop"
if not exist "%DESKTOP%" (
    echo Could not find Desktop folder.
    echo Expected: %USERPROFILE%\Desktop
    pause
    exit /b 1
)

if not exist "%SRC%" (
    echo Missing Launch_PoB_with_Optimizer.bat next to this script.
    echo Run Put_Launcher_on_Desktop.bat from your localoptimizer repo folder.
    pause
    exit /b 1
)

set "DEST=%DESKTOP%\Launch PoB with Optimizer.bat"

rem Write a Desktop stub that always calls the repo launcher (so updates apply)
(
echo @echo off
echo rem Desktop launcher for localoptimizer — NO 600s time budget
echo rem Real tool lives at: %REPO_DIR%
echo cd /d "%REPO_DIR%"
echo call "%SRC%" %%*
) > "%DEST%"

echo.
echo Placed on Desktop:
echo   %DEST%
echo.
echo This launches localoptimizer ^(Deep Optimize, no time limit^).
echo It is NOT the NSGA-II Opt DPS console that prints "Time budget: 600 seconds".
echo.
echo Double-click "Launch PoB with Optimizer" on your Desktop.
echo.
pause
endlocal
