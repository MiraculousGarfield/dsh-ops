# check-health.ps1 - one-click health check for a DeepSeek Harness deployment
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File check-health.ps1 [-Profile web] [-Port 3080] [-ExpectTheme <pkg>]
param(
    [string]$Profile = 'web',
    [int]$Port = 3080,
    [string]$ExpectTheme = ''
)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
$url = "http://127.0.0.1:$Port"
$fail = 0

function Ok($m) { Write-Host "[OK]   $m" }
function Bad($m) { Write-Host "[FAIL] $m"; $script:fail = 1 }

Write-Host "== dsh health check v$(Get-DshOpsVersion) (home=$dsh profile=$Profile port=$Port) =="

# 1. service port
if (Test-PortListening $Port) { Ok "service listening on $Port" } else { Bad "service NOT listening on $Port" }

# 2. HTTP / boot page
$roster = Get-BootRoster $url
if ($roster) { Ok 'HTTP 200 / boot page reachable' } else { Bad 'HTTP unreachable' }

# 3. expected package in boot roster (optional)
if ($ExpectTheme) {
    if ($roster -and $roster -match [regex]::Escape($ExpectTheme)) {
        Ok "expected package '$ExpectTheme' present in boot roster"
    } else {
        Bad "expected package '$ExpectTheme' MISSING from boot roster"
    }
}

# 4. duplicate row ids in the composed tree (needs the dsh launcher)
$bin = Find-DshBin
if ($bin) {
    Ok "dsh launcher found: $bin"
    $ids = Get-ComposedRowIds $bin $Profile
    $dups = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($dups) {
        $dups | ForEach-Object { Bad "duplicate row id: $($_.Name) x$($_.Count)" }
    } else {
        Ok 'no duplicate row ids in composed tree'
    }
} else {
    Bad 'dsh launcher not found (set DSH_BIN or install dsh)'
}

# 5. core package duplicates inside the profile's own node_modules (.pnpm)
$pnpm = Join-Path $dsh "profiles\$Profile\node_modules\.pnpm"
$dupCore = Get-ChildItem $pnpm -Directory -Filter '@deepseek-ai+dsh-*' -ErrorAction SilentlyContinue
if ($dupCore) {
    $dupCore | ForEach-Object { Bad "core package duplicate: $($_.Name)" }
} else {
    Ok 'no core package duplicates in profile node_modules'
}

# 6. backup discipline
$n = Get-SnapshotCount
if ($n -gt 0) { Ok "backup dir exists ($n snapshot(s))" } else { Bad 'no snapshots yet - run backup-config.ps1 before changes' }

Write-Host ''
if ($fail -eq 0) { Write-Host 'RESULT: ALL HEALTHY' } else { Write-Host 'RESULT: ISSUES FOUND - see runbook.md' }
exit $fail
