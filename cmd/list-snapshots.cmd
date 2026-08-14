@echo off
title dsh-ops Snapshots
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\list-snapshots.ps1" %*
echo.
pause
