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
$failItems = New-Object System.Collections.Generic.List[string]

function Ok($m) { Write-Host "[OK]   $m" }
function Bad($m) { Write-Host "[FAIL] $m"; $script:fail = 1; [void]$script:failItems.Add($m) }

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

# 7. static lint: user packages whose server entry references browser globals
#    (the malformed-theme class: "main" pointing at a browser script -> window is not defined)
$scanRoots = @()
$pkgsDir = Join-Path $dsh 'packages'
if (Test-Path $pkgsDir) {
    $scanRoots += (Get-ChildItem $pkgsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
}
$nm = Join-Path $dsh "profiles\$Profile\node_modules"
if (Test-Path $nm) {
    foreach ($d in (Get-ChildItem $nm -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -like '@*') {
            foreach ($s in (Get-ChildItem $d.FullName -Directory -ErrorAction SilentlyContinue)) {
                if ($s.Name -ne '@deepseek-ai') { $scanRoots += $s.FullName }
            }
        } elseif ($d.Name -notin @('.pnpm', '.bin')) {
            $scanRoots += $d.FullName
        }
    }
}
$lintBads = @()
foreach ($root in $scanRoots) {
    $pj = Join-Path $root 'package.json'
    if (-not (Test-Path $pj)) { continue }
    try { $pkg = Get-Content $pj -Raw | ConvertFrom-Json } catch { continue }
    if (-not $pkg.main) { continue }
    $mainPath = Join-Path $root ($pkg.main -replace '\\', '/')
    if (-not (Test-Path $mainPath)) { continue }
    try {
        $text = [System.IO.File]::ReadAllText($mainPath, [System.Text.Encoding]::UTF8)
        $head = $text.Substring(0, [Math]::Min(3000, $text.Length))
        if ($head -match 'window\.|document\.') { $lintBads += (Split-Path $root -Leaf) }
    } catch { }
}
if ($lintBads.Count) {
    $lintBads | ForEach-Object { Bad "package '$_' has main referencing browser globals (window/document)" }
} else {
    Ok 'no user package main references browser globals'
}

# history log: every run is recorded with timestamp so incidents get a timeline
$logsDir = Join-Path $dsh 'logs'
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Force -Path $logsDir | Out-Null }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$status = if ($fail -eq 0) { 'PASS' } else { 'FAIL' }
$detail = if ($failItems.Count) { ($failItems -join '; ') } else { '-' }
Add-Content -Path (Join-Path $logsDir 'health-history.log') -Value "$stamp | $status | $detail"

# auto-refresh the known-good snapshot whenever everything is green:
# a green run is by definition a verified state, so this keeps the restore
# baseline always current without any manual step. Written to a fixed
# known-good-auto/ dir; manual dated snapshots (known-good-<date>) stay.
if ($fail -eq 0) {
    $auto = Join-Path $dsh 'backups\known-good-auto'
    try {
        New-Item -ItemType Directory -Force -Path $auto | Out-Null
        foreach ($rel in @(
            "profiles\$Profile\cordis.yml",
            "profiles\$Profile\cordis.patch.yml",
            "profiles\$Profile\package.json",
            "profiles\$Profile\pnpm-workspace.yaml",
            'settings.yaml'
        )) {
            $src = Join-Path $dsh $rel
            if (Test-Path $src) { Copy-Item $src $auto -Force }
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $auto 'updated-at.txt'),
            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "[auto] known-good snapshot refreshed (all green)"
    } catch {
        Write-Host "[auto] known-good refresh failed: $($_.Exception.Message)"
    }
}

Write-Host ''
if ($fail -eq 0) { Write-Host 'RESULT: ALL HEALTHY' } else { Write-Host 'RESULT: ISSUES FOUND - see runbook.md' }
exit $fail
