@echo off
title dsh-ops Health Check
echo Running dsh health check (no AI needed)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\check-health.ps1" %*
echo.
pause
