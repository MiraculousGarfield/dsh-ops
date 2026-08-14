# install.ps1 - register watch-config to auto-start at logon (zero-window via VBS)
# Uses the per-user Startup folder (no admin rights, no console flash, easy to remove).
# Deliberately does NOT install the system-level watchdog: most deployments do not
# need the dsh service running 24/7 (the desktop wrapper / restart-service.ps1 covers it).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 [-InstallDir <dir>] [-Profile web]
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall
param(
    [string]$InstallDir = '',
    [string]$Profile = 'web',
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startupDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$linkName = 'dsh-ops-watch-config.vbs'
$linkPath = Join-Path $startupDir $linkName

if ($Uninstall) {
    if (Test-Path $linkPath) {
        Remove-Item $linkPath -Force
        Write-Host "removed startup entry '$linkName'"
    } else {
        Write-Host 'no startup entry found'
    }
    exit 0
}

# install.ps1 lives at the repo root, so scripts/ is directly under it
$target = ''
if ($InstallDir) {
    $target = Join-Path $InstallDir 'dsh-ops'
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Copy-Item -Path (Join-Path $scriptDir '*') -Destination $target -Recurse -Force -Exclude '.git'
} else {
    $target = $scriptDir
}
$psPath = Join-Path $target 'scripts\watch-config.ps1'
if (-not (Test-Path $psPath)) {
    Write-Host "watch-config.ps1 not found at $psPath"
    exit 2
}

# zero-window VBS wrapper (window style 0)
$vbsPath = Join-Path $target 'scripts\watch-config.vbs'
$vbs = "Set s = CreateObject(""WScript.Shell"")" + "`r`n" +
    "s.Run ""powershell.exe -NoProfile -ExecutionPolicy Bypass -File """"$psPath"""" -Profile $Profile"", 0, False"
Set-Content -Path $vbsPath -Value $vbs -Encoding ASCII

# register via the per-user Startup folder (no admin needed, no flash)
Copy-Item $vbsPath $linkPath -Force
Write-Host "auto-start registered (Startup folder): $linkPath"

# start it right away, hidden
$wsh = New-Object -ComObject WScript.Shell
$wsh.Run('"' + $vbsPath + '"', 0, $false)

Write-Host "watch-config target : $psPath"
Write-Host "config audit log    : <dsh>\logs\config-watch.log"
Write-Host "uninstall           : powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall"
