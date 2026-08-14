# diff-snapshot.ps1 - compare config between two snapshots (audit what changed)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File diff-snapshot.ps1 -Base <name> -Compare <name> [-NoGit]
param(
    [Parameter(Mandatory = $true)][string]$Base,
    [Parameter(Mandatory = $true)][string]$Compare,
    [switch]$NoGit
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
$a = Join-Path $dsh "backups\$Base"
$b = Join-Path $dsh "backups\$Compare"
if (-not (Test-Path $a)) { Write-Host "snapshot not found: $a"; exit 2 }
if (-not (Test-Path $b)) { Write-Host "snapshot not found: $b"; exit 2 }

$files = @('cordis.yml', 'cordis.patch.yml', 'package.json', 'pnpm-workspace.yaml', 'settings.yaml')
$useGit = (-not $NoGit) -and (Get-Command git -ErrorAction SilentlyContinue)
$any = $false

foreach ($f in $files) {
    $pa = Join-Path $a $f
    $pb = Join-Path $b $f
    if (-not (Test-Path $pa) -and -not (Test-Path $pb)) { continue }

    if ($useGit) {
        $out = @(& git -c core.autocrlf=false diff --no-index -- "$pa" "$pb" 2>&1 | Select-Object -Skip 1)
        if ($out.Count -gt 0) {
            Write-Host "=== $f ==="
            $out
            $any = $true
        }
    } else {
        $la = if (Test-Path $pa) { [System.IO.File]::ReadAllLines($pa, [System.Text.Encoding]::UTF8) } else { @() }
        $lb = if (Test-Path $pb) { [System.IO.File]::ReadAllLines($pb, [System.Text.Encoding]::UTF8) } else { @() }
        $d = Compare-Object $la $lb
        if ($d) {
            Write-Host "=== $f ==="
            $d | ForEach-Object {
                if ($_.SideIndicator -eq '<=') { Write-Host "- $($_.InputObject)" }
                else { Write-Host "+ $($_.InputObject)" }
            }
            $any = $true
        }
    }
}

if (-not $any) { Write-Host 'no differences between the two snapshots' }
