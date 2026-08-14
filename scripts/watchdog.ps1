# watchdog.ps1 - system-level watchdog for scheduled tasks (runs silently, logs only)
# If the service is down, restarts it and verifies real health (port + HTTP 200).
# Two consecutive failed restarts stop the retry loop and tell the operator to
# restore a snapshot - a broken config cannot be fixed by restarting.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File watchdog.ps1 [-Profile web] [-Port 3080]
param(
    [string]$Profile = 'web',
    [int]$Port = 3080,
    [string]$LogFile = ''
)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
if (-not $LogFile) { $LogFile = Join-Path $dsh 'logs\watchdog.log' }
$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stateFile = Join-Path $logDir 'watchdog-failcount.txt'
$url = "http://127.0.0.1:$Port"

# healthy -> reset the failure counter
if (Test-PortListening $Port) {
    Remove-Item $stateFile -ErrorAction SilentlyContinue
    exit 0
}

$bin = Find-DshBin
if (-not $bin) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] dsh launcher not found"
    exit 1
}

$node = Get-NodeExe
$env:DSH_HOME = $dsh
$args = @('"' + $bin + '"', '--profile', $Profile, '--port', "$Port")
Start-Process -FilePath $node -ArgumentList $args -WindowStyle Hidden

# readiness: port up AND HTTP 200 within 15s (a listening port alone is not health)
$deadline = (Get-Date).AddSeconds(15)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    if (Test-PortListening $Port) {
        if (Get-BootRoster $url) { $ready = $true; break }
    }
}

if ($ready) {
    Remove-Item $stateFile -ErrorAction SilentlyContinue
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] service restarted and healthy"
    exit 0
}

$n = 0
if (Test-Path $stateFile) { $n = [int](Get-Content $stateFile -ErrorAction SilentlyContinue) }
$n += 1
Set-Content -Path $stateFile -Value "$n"
if ($n -ge 2) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] restart failed $n times; config likely broken - run restore-snapshot.ps1"
} else {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] restart attempt $n failed readiness check"
}
exit 1
