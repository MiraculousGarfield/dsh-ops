@echo off
title dsh-ops Restore Snapshot
setlocal
echo This restores profile config from a snapshot in <dsh>\backups\<name>.
set /p SNAP=Snapshot name: 
if "%SNAP%"=="" (echo Aborted. & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\restore-snapshot.ps1" -Snapshot "%SNAP%" %*
echo.
pause
