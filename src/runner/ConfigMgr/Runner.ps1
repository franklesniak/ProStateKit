# Preview scaffold for the legacy ConfigMgr runner path.
# Production behavior requires the final pinned bundle and ConfigMgr lab validation.
[CmdletBinding()]
param(
    [ValidateSet('Detect', 'Remediate')]
    [string] $Mode = 'Detect'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$strRunnerRoot = Split-Path -Path $PSScriptRoot -Parent
$strSourceRoot = Split-Path -Path $strRunnerRoot -Parent
$strRunnerPath = Join-Path -Path $strRunnerRoot -ChildPath 'Runner.ps1'
$strConfigPath = Join-Path -Path $strSourceRoot -ChildPath 'configs/baseline.windows.yaml'
$strBundleRoot = Split-Path -Path $strSourceRoot -Parent

& $strRunnerPath `
    -Mode $Mode `
    -ConfigPath $strConfigPath `
    -BundleRoot $strBundleRoot `
    -Plane 'ConfigMgr'

if ($LASTEXITCODE -eq 0) {
    Write-Output 'Compliant'
    exit 0
}

Write-Output 'NonCompliant'
exit 1
