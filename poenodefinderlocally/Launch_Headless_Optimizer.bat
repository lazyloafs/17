@echo off
rem Run the deep optimizer headless (no PoB GUI). Writes optimized build to your local save.
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\run-headless.ps1" %*
