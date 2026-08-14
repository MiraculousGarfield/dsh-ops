@echo off
title dsh-ops Config Watcher
echo Watching profile config; every change is auto-snapshotted to <dsh>\backups\auto-*.
echo Close this window to stop. For silent background use, schedule it at logon:
echo   schtasks /Create /TN dshOpsWatchConfig /SC ONLOGON /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File %~dp0..\scripts\watch-config.ps1" /F
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\watch-config.ps1" %*
