# restart-service.ps1 - start the dsh service if it is not already running
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File restart-service.ps1 [-Profile web] [-Port 3080]
param(
    [string]$Profile = 'web',
    [int]$Port = 3080,
    [int]$TimeoutSec = 90
)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '..\lib\dsh-common.ps1')

if (Test-PortListening $Port) {
    Write-Host "service already listening on $Port"
    exit 0
}

$bin = Find-DshBin
if (-not $bin) {
    Write-Host 'dsh launcher not found (set DSH_BIN or install dsh)'
    exit 2
}

$node = Get-NodeExe
$env:DSH_HOME = Get-DshHome
$args = @('"' + $bin + '"', '--profile', $Profile, '--port', "$Port")
$p = Start-Process -FilePath $node -ArgumentList $args -WindowStyle Hidden -PassThru
Write-Host "started dsh (pid $($p.Id)); waiting up to ${TimeoutSec}s..."

$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    if (Test-PortListening $Port) {
        Write-Host 'service is up'
        exit 0
    }
}
Write-Host 'service did not become ready in time'
exit 1
