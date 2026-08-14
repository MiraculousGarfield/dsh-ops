# backup-config.ps1 - snapshot current dsh profile config before changes
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File backup-config.ps1 [-Profile web] [-Name <snapshot>]
param(
    [string]$Profile = 'web',
    [string]$Name = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dsh = Get-DshHome
$stamp = if ($Name) { $Name } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
$dest = Join-Path $dsh "backups\$stamp"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$files = @(
    "profiles\$Profile\cordis.yml",
    "profiles\$Profile\cordis.patch.yml",
    "profiles\$Profile\package.json",
    "profiles\$Profile\pnpm-workspace.yaml",
    'settings.yaml'
)
foreach ($rel in $files) {
    $src = Join-Path $dsh $rel
    if (Test-Path $src) {
        Copy-Item $src $dest -Force
        Write-Host "backed up: $rel"
    } else {
        Write-Host "skip (not found): $rel"
    }
}

$pkgs = Join-Path $dsh 'packages'
if (Test-Path $pkgs) {
    (Get-ChildItem $pkgs -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) |
        Set-Content (Join-Path $dest 'packages-list.txt')
}

Write-Host "snapshot saved to $dest"
