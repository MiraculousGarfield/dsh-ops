# fix-service.ps1 - smart one-click recovery: restore config snapshots from
# newest to oldest, restarting and health-checking each one, until a green
# state is found. This preserves as much recent work as possible: it only
# falls back further when a newer snapshot fails the health check.
# Order: auto-* (newest first) -> known-good-auto -> known-good-20260816.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File fix-service.ps1 [-Profile web] [-Port 3080]
param(
    [string]$Profile = 'web',
    [int]$Port = 3080
)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
$backups = Join-Path $dsh 'backups'
$url = "http://127.0.0.1:$Port"

Write-Host '== dsh fix-service: step-by-step config rollback =='

# 0. safety: snapshot the CURRENT (possibly broken) state first
$preStamp = 'pre-fix-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$preDir = Join-Path $backups $preStamp
New-Item -ItemType Directory -Force -Path $preDir | Out-Null
foreach ($rel in @("profiles\$Profile\cordis.yml", "profiles\$Profile\cordis.patch.yml", "profiles\$Profile\package.json", "profiles\$Profile\pnpm-workspace.yaml", 'settings.yaml')) {
    $src = Join-Path $dsh $rel
    if (Test-Path $src) { Copy-Item $src $preDir -Force }
}
Write-Host "[0] current state saved to $preStamp"

# 1. build candidate list: auto-* newest first, then known-good-auto, then dated known-good
$candidates = @()
Get-ChildItem $backups -Directory -Filter 'auto-*' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    ForEach-Object { $candidates += @{ Name = $_.Name; Path = $_.FullName } }
foreach ($n in @('known-good-auto', 'known-good-20260816', 'known-good-20260815')) {
    $p = Join-Path $backups $n
    if ((Test-Path (Join-Path $p 'package.json')) -and (Test-Path (Join-Path $p 'cordis.patch.yml'))) {
        $candidates += @{ Name = $n; Path = $p }
    }
}
if ($candidates.Count -eq 0) {
    Write-Host '[FAIL] no snapshots found to restore from'
    exit 1
}
Write-Host "[1] $($candidates.Count) candidate snapshot(s), newest first"

function Restore-Snapshot($dir) {
    Copy-Item (Join-Path $dir 'cordis.yml') (Join-Path $dsh "profiles\$Profile\cordis.yml") -Force
    Copy-Item (Join-Path $dir 'cordis.patch.yml') (Join-Path $dsh "profiles\$Profile\cordis.patch.yml") -Force
    Copy-Item (Join-Path $dir 'package.json') (Join-Path $dsh "profiles\$Profile\package.json") -Force
    if (Test-Path (Join-Path $dir 'pnpm-workspace.yaml')) {
        Copy-Item (Join-Path $dir 'pnpm-workspace.yaml') (Join-Path $dsh "profiles\$Profile\pnpm-workspace.yaml") -Force
    }
    if (Test-Path (Join-Path $dir 'settings.yaml')) {
        Copy-Item (Join-Path $dir 'settings.yaml') (Join-Path $dsh 'settings.yaml') -Force
    }
}

function Restart-Service {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) { Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    $bin = Find-DshBin
    $node = Get-NodeExe
    if (-not $bin -or -not $node) { return $false }
    $env:DSH_HOME = $dsh
    Start-Process -FilePath $node -ArgumentList @('"' + $bin + '"', '--profile', $Profile, '--port', "$Port") -WindowStyle Hidden | Out-Null
    # wait for HTTP 200
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (Get-BootRoster $url) { return $true }
    }
    return $false
}

# 2. roll back step by step
$tried = 0
foreach ($cand in $candidates) {
    $tried++
    Write-Host ''
    Write-Host "[2.$tried] trying snapshot: $($cand.Name)"
    Restore-Snapshot $cand.Path
    if (-not (Restart-Service)) {
        Write-Host "      service did not come up - trying older snapshot"
        continue
    }
    $check = Join-Path $PSScriptRoot 'check-health.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $check -Profile $Profile -Port $Port | Out-Null
    $green = ($LASTEXITCODE -eq 0)
    if ($green) {
        Write-Host "[OK]   recovered with snapshot $($cand.Name) (health check ALL GREEN)"
        exit 0
    }
    Write-Host "      health check still red - trying older snapshot"
}

Write-Host ''
Write-Host '[FAIL] no snapshot passed the health check. All $tried candidate(s) tried.'
Write-Host '       Fall back to manual diagnosis: health-check.cmd + ops-manual,'
Write-Host '       or hand the manual to an external tool. Current broken state'
Write-Host "       was preserved in $preStamp"
exit 1
