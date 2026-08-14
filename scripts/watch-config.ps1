# watch-config.ps1 - auto-snapshot profile config whenever it changes (audit trail)
# Polls the profile config files; on change (debounced), copies the standard set
# into <dsh>/backups/auto-<stamp>/ and appends a line to <dsh>/logs/config-watch.log.
# Run it persistently: at logon (scheduled task) or in a terminal. Ctrl+C to stop.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File watch-config.ps1 [-Profile web] [-DebounceSec 3]
param(
    [string]$Profile = 'web',
    [int]$DebounceSec = 3
)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
$watchDir = Join-Path $dsh "profiles\$Profile"
$logsDir = Join-Path $dsh 'logs'
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Force -Path $logsDir | Out-Null }
$audit = Join-Path $logsDir 'config-watch.log'

$targets = @(
    @{ Name = 'cordis.yml';         Path = Join-Path $watchDir 'cordis.yml' },
    @{ Name = 'cordis.patch.yml';   Path = Join-Path $watchDir 'cordis.patch.yml' },
    @{ Name = 'package.json';       Path = Join-Path $watchDir 'package.json' },
    @{ Name = 'pnpm-workspace.yaml'; Path = Join-Path $watchDir 'pnpm-workspace.yaml' },
    @{ Name = 'settings.yaml';      Path = Join-Path $dsh 'settings.yaml' }
)

$state = @{}
foreach ($t in $targets) {
    if (Test-Path $t.Path) { $state[$t.Name] = (Get-Item $t.Path).LastWriteTimeUtc.Ticks }
}

Write-Host "watch-config: watching $watchDir and settings.yaml (debounce ${DebounceSec}s)"
Add-Content -Path $audit -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watch-config] started (profile=$Profile)"

while ($true) {
    Start-Sleep -Seconds 1
    $changed = @()
    foreach ($t in $targets) {
        if (-not (Test-Path $t.Path)) { continue }
        $m = (Get-Item $t.Path).LastWriteTimeUtc.Ticks
        if ($state.ContainsKey($t.Name)) {
            if ($m -ne $state[$t.Name]) { $changed += $t.Name; $state[$t.Name] = $m }
        } else {
            $state[$t.Name] = $m
        }
    }
    if ($changed.Count -eq 0) { continue }

    # debounce: let a burst of edits settle into one snapshot
    Start-Sleep -Seconds $DebounceSec
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest = Join-Path $dsh "backups\auto-$stamp"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($t in $targets) {
        if (Test-Path $t.Path) { Copy-Item $t.Path $dest -Force }
    }
    $msg = "change(s): $($changed -join ', ') -> auto-$stamp"
    Add-Content -Path $audit -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watch-config] $msg"
    Write-Host "snapshot $msg"
}
