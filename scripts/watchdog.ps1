# watchdog.ps1 - system-level watchdog for scheduled tasks (runs silently, logs only)
# If the service is down, restarts it and appends a line to <dsh>/backups/watchdog.log
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File watchdog.ps1 [-Profile web] [-Port 3080]
param(
    [string]$Profile = 'web',
    [int]$Port = 3080,
    [string]$LogFile = ''
)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
if (-not $LogFile) { $LogFile = Join-Path $dsh 'backups\watchdog.log' }
$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

if (Test-PortListening $Port) { exit 0 }

$bin = Find-DshBin
if (-not $bin) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] dsh launcher not found"
    exit 1
}

$node = Get-NodeExe
$env:DSH_HOME = $dsh
$args = @('"' + $bin + '"', '--profile', $Profile, '--port', "$Port")
Start-Process -FilePath $node -ArgumentList $args -WindowStyle Hidden
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] service was down, restarted"
exit 0
