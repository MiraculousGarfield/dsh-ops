# restore-snapshot.ps1 - restore profile config from a snapshot (backup first!)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File restore-snapshot.ps1 -Snapshot <name> [-Profile web] [-Force]
param(
    [string]$Profile = 'web',
    [Parameter(Mandatory = $true)][string]$Snapshot,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
$src = Join-Path $dsh "backups\$Snapshot"
if (-not (Test-Path $src)) {
    Write-Host "snapshot not found: $src"
    exit 2
}

if (-not $Force) {
    $ans = Read-Host "Overwrite current config from '$Snapshot'? (type YES to confirm)"
    if ($ans -ne 'YES') { Write-Host 'Aborted'; exit 1 }
}

$files = @('cordis.yml', 'cordis.patch.yml', 'package.json', 'pnpm-workspace.yaml', 'settings.yaml')
foreach ($f in $files) {
    $s = Join-Path $src $f
    if (Test-Path $s) {
        $target = if ($f -eq 'settings.yaml') { Join-Path $dsh $f } else { Join-Path $dsh "profiles\$Profile\$f" }
        Copy-Item $s $target -Force
        Write-Host "restored: $f"
    }
}
Write-Host ''
Write-Host 'Restored. Restart the service afterwards (restart-service.ps1 or reopen the app).'
