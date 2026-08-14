@echo off
title dsh-ops Diff Snapshots
setlocal
echo Compares config between two snapshots in <dsh>\backups\<name>.
set /p BASE=Base snapshot name: 
if "%BASE%"=="" (echo Aborted. & pause & exit /b 1)
set /p CMP=Compare snapshot name: 
if "%CMP%"=="" (echo Aborted. & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\diff-snapshot.ps1" -Base "%BASE%" -Compare "%CMP%" %*
echo.
pause
