@echo off
title DeepSeek Harness Smart Fix (step-by-step rollback)
echo ============================================
echo DeepSeek Harness SMART FIX
echo Restores config snapshots from newest to oldest,
echo restarting and health-checking each one, until
echo a green state is found (keeps your latest work).
echo ============================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\fix-service.ps1"
echo.
pause
