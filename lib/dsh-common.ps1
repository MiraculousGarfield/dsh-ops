# dsh-common.ps1 - shared helpers for dsh-ops (Windows PowerShell 5.1 compatible, ASCII only)

function Get-DshOpsVersion { return '1.1.3' }

function Get-DshHome {
    if ($env:DSH_HOME) { return $env:DSH_HOME }
    return Join-Path $env:USERPROFILE '.dsh'
}

function Find-DshBin {
    if ($env:DSH_BIN -and (Test-Path $env:DSH_BIN)) { return $env:DSH_BIN }
    $npx = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'
    if (Test-Path $npx) {
        foreach ($d in (Get-ChildItem $npx -Directory -ErrorAction SilentlyContinue)) {
            $c = Join-Path $d.FullName 'node_modules\@deepseek-ai\dsh\lib\bin.js'
            if (Test-Path $c) { return $c }
        }
    }
    $alt = Join-Path (Get-DshHome) 'profiles\node_modules\@deepseek-ai\dsh\lib\bin.js'
    if (Test-Path $alt) { return $alt }
    return $null
}

function Get-NodeExe {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($c in @('C:\Program Files\nodejs\node.exe', 'C:\Program Files (x86)\nodejs\node.exe')) {
        if (Test-Path $c) { return $c }
    }
    return 'node'
}

function Test-PortListening([int]$Port) {
    return [bool](netstat -ano | Select-String ":$Port\s+.*LISTENING")
}

function Get-BootRoster([string]$Url) {
    try { return (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5).Content } catch { return '' }
}

function Get-ComposedRowIds([string]$Bin, [string]$Profile) {
    $prev = $env:DSH_HOME
    $env:DSH_HOME = Get-DshHome
    try {
        $dump = & node $Bin --profile $Profile --dump-config 2>&1
        $text = $dump -join "`n"
        return @([regex]::Matches($text, '(?m)^- id: (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
    } finally {
        $env:DSH_HOME = $prev
    }
}

function Get-SnapshotCount {
    $dir = Join-Path (Get-DshHome) 'backups'
    if (Test-Path $dir) {
        return (Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
    }
    return 0
}
