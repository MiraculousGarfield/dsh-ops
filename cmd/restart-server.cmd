@echo off
title dsh-ops Restart Service
echo Restarting dsh service if it is down...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\restart-service.ps1" %*
echo.
pause
