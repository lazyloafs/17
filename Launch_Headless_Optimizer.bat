@echo off
rem Queue dual-phase headless optimize (PoB must be patched; will start if needed).
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\run-headless.ps1" -DualPhase -OptimizeJewels %*
