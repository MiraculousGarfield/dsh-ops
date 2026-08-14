@echo off
rem Restart the local dsh service (port 3080): kill the port owner, then
rem start it directly via restart-service.ps1 (no watchdog dependency).
title dsh-ops Restart Service
echo Stopping service on port 3080...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /r /c:":3080 .*LISTENING"') do taskkill /PID %%p /F >nul 2>&1
timeout /t 2 /nobreak >nul
echo Starting service...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\restart-service.ps1" %*
echo.
pause
