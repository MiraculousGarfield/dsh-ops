@echo off
title dsh-ops Install (watch-config auto-start)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\install.ps1" %*
echo.
pause
