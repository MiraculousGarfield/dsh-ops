# list-snapshots.ps1 - list config snapshots under <dsh>/backups/
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File list-snapshots.ps1
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

$dir = Join-Path (Get-DshHome) 'backups'
if (-not (Test-Path $dir)) { Write-Host 'no backups dir yet'; exit 0 }
$snaps = Get-ChildItem $dir -Directory | Sort-Object Name
if (-not $snaps) { Write-Host 'no snapshots yet'; exit 0 }
Write-Host ("{0,-24} {1,-9} {2}" -f 'NAME', 'FILES', 'CREATED')
Write-Host ('-' * 50)
foreach ($s in $snaps) {
    $n = (Get-ChildItem $s.FullName -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host ("{0,-24} {1,-9} {2}" -f $s.Name, $n, $s.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
}
