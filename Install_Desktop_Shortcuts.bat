@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  Copy Opt_DPS.bat, Opt_Tank.bat, and Launch_PoB_with_Optimizer.bat
rem  to your Windows Desktop for one-click access.
rem ============================================================================

set "REPO_DIR=%~dp0"
set "DESKTOP=%USERPROFILE%\Desktop"

if not exist "%DESKTOP%" (
    echo Desktop folder not found: %DESKTOP%
    pause
    exit /b 1
)

for %%F in (Opt_DPS.bat Opt_Tank.bat Launch_PoB_with_Optimizer.bat) do (
    if exist "%REPO_DIR%%%F" (
        copy /Y "%REPO_DIR%%%F" "%DESKTOP%\%%F" >nul
        echo Copied %%F to Desktop
    ) else (
        echo Missing: %REPO_DIR%%%F
    )
)

echo.
echo Done. Double-click Opt_DPS or Opt_Tank on your Desktop to deep optimize.
echo Set POB_PATH if PoB is not at E:\Path of Building Community
echo.
pause
endlocal
