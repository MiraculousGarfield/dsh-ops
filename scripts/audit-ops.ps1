# Full audit of the ops project: syntax, references, garbled-output risk, secrets, drift.
$ErrorActionPreference = 'SilentlyContinue'
$roots = @(
    'C:\Users\Guo Zifan\Desktop\Deepseek Harness\运维工具',
    'C:\Users\Guo Zifan\Desktop\Deepseek Harness\dsh-ops',
    'C:\Users\Guo Zifan\Desktop\Deepseek Harness\dsh-ops-health'
)
$issues = @()

# A. PS syntax
Write-Host '=== A. PowerShell syntax ==='
$allPs1 = foreach ($r in $roots) {
    Get-ChildItem $r -Recurse -File -Filter *.ps1 | Where-Object { $_.FullName -notmatch '\\.git\\' }
}
foreach ($f in $allPs1) {
    $tokens = $null; $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs) | Out-Null
    if ($errs.Count -gt 0) {
        $issues += "SYNTAX $($f.FullName): $($errs[0].Message)"
        Write-Host "[BAD] $($f.Name): $($errs[0].Message)"
    } else {
        Write-Host "[OK ] $($f.Name)"
    }
}

# B. cmd -> ps1 references exist
Write-Host ''
Write-Host '=== B. cmd references ==='
$allCmd = foreach ($r in $roots) {
    Get-ChildItem $r -Recurse -File -Filter *.cmd | Where-Object { $_.FullName -notmatch '\\.git\\' }
}
foreach ($c in $allCmd) {
    $text = Get-Content $c.FullName -Raw
    $refs = [regex]::Matches($text, '%~dp0([^"%\s]+\.ps1)')
    foreach ($m in $refs) {
        $p = Join-Path $c.DirectoryName $m.Groups[1].Value
        if (-not (Test-Path $p)) {
            $issues += "CMDREF $($c.FullName) -> missing $($m.Groups[1].Value)"
            Write-Host "[BAD] $($c.Name) -> $($m.Groups[1].Value) missing"
        } else {
            Write-Host "[OK ] $($c.Name) -> $($m.Groups[1].Value)"
        }
    }
    # also absolute-ish script refs via scripts\name.ps1
    $refs2 = [regex]::Matches($text, '"%~dp0scripts\\([^"]+\.ps1)"')
    foreach ($m in $refs2) {
        $p = Join-Path $c.DirectoryName "scripts\$($m.Groups[1].Value)"
        if (-not (Test-Path $p)) {
            $issues += "CMDREF $($c.FullName) -> missing scripts\$($m.Groups[1].Value)"
            Write-Host "[BAD] $($c.Name) -> scripts\$($m.Groups[1].Value) missing"
        } else {
            Write-Host "[OK ] $($c.Name) -> scripts\$($m.Groups[1].Value)"
        }
    }
}

# C. dot-sourced common lib
Write-Host ''
Write-Host '=== C. dsh-common references ==='
foreach ($f in $allPs1) {
    if ($f.Name -eq 'dsh-common.ps1') { continue }
    $text = Get-Content $f.FullName -Raw
    if ($text -match "\. \(Join-Path \$PSScriptRoot '\.\.\\lib\\dsh-common\.ps1'\)" -or $text -match "\. \(Join-Path \$PSScriptRoot '[^']*dsh-common\.ps1'\)") {
        # resolve: try ..\lib\dsh-common.ps1 relative to file
        $lib = Join-Path $f.DirectoryName '..\lib\dsh-common.ps1'
        $found = Test-Path $lib
        if (-not $found) {
            $alt = Join-Path $f.DirectoryName 'dsh-common.ps1'
            $found = Test-Path $alt
        }
        if (-not $found) {
            $issues += "LIBREF $($f.FullName): dsh-common.ps1 not found"
            Write-Host "[BAD] $($f.Name): dsh-common.ps1 missing"
        } else {
            Write-Host "[OK ] $($f.Name)"
        }
    }
}

# D. Chinese output in console scripts (GBK garble risk)
Write-Host ''
Write-Host '=== D. Chinese in Write-Host / echo ==='
foreach ($f in @($allPs1) + @($allCmd)) {
    $text = Get-Content $f.FullName -Raw
    $bad = [regex]::Matches($text, '(?m)^\s*(Write-Host\s+[^#]*[一-龥]|echo\s+[^#\r\n]*[一-龥])')
    foreach ($m in $bad) {
        $issues += "GARBLE $($f.FullName): $($m.Value.Trim().Substring(0, [Math]::Min(60, $m.Value.Trim().Length)))"
        Write-Host "[BAD] $($f.Name): $($m.Value.Trim().Substring(0, [Math]::Min(60, $m.Value.Trim().Length)))"
    }
}

# E. Secrets / absolute user paths
Write-Host ''
Write-Host '=== E. Sensitive content ==='
foreach ($f in @($allPs1) + @($allCmd)) {
    $text = Get-Content $f.FullName -Raw
    if ($text -match 'sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|api[_-]?key\s*[:=]\s*["'']?[A-Za-z0-9]{16,}') {
        $issues += "SECRET $($f.FullName)"
        Write-Host "[BAD] $($f.Name): possible secret"
    }
}

# F. check-health.ps1 copies drift
Write-Host ''
Write-Host '=== F. check-health.ps1 copies ==='
$hashes = @{}
$paths = @(
    'C:\Users\Guo Zifan\Desktop\Deepseek Harness\运维工具\scripts\check-health.ps1',
    'C:\Users\Guo Zifan\Desktop\Deepseek Harness\dsh-ops\scripts\check-health.ps1',
    'C:\Users\Guo Zifan\Desktop\Deepseek Harness\dsh-ops-health\scripts\check-health.ps1',
    "$env:USERPROFILE\.dsh\profiles\node_modules\dsh-ops-health\scripts\check-health.ps1"
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        $h = (Get-FileHash $p -Algorithm SHA256).Hash.Substring(0, 12)
        $hashes[$p] = $h
        Write-Host "$h  $p"
    } else {
        $issues += "DRIFT missing: $p"
        Write-Host "[MISSING] $p"
    }
}
$uniq = $hashes.Values | Sort-Object -Unique
if ($uniq.Count -gt 1) { $issues += "DRIFT: check-health.ps1 copies differ"; Write-Host "[BAD] copies differ" } else { Write-Host '[OK ] all copies identical' }

Write-Host ''
Write-Host "=== TOTAL ISSUES: $($issues.Count) ==="
$issues | ForEach-Object { Write-Host $_ }
