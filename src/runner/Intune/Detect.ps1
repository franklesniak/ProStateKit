# Preview scaffold for the legacy Intune detection path.
# Production behavior requires the final pinned bundle and Intune lab validation.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$strRunnerRoot = Split-Path -Path $PSScriptRoot -Parent
$strSourceRoot = Split-Path -Path $strRunnerRoot -Parent
$strRunnerPath = Join-Path -Path $strRunnerRoot -ChildPath 'Runner.ps1'
$strConfigPath = Join-Path -Path $strSourceRoot -ChildPath 'configs/baseline.windows.yaml'
$strBundleRoot = Split-Path -Path $strSourceRoot -Parent

& $strRunnerPath `
    -Mode 'Detect' `
    -ConfigPath $strConfigPath `
    -BundleRoot $strBundleRoot `
    -Plane 'Intune'

if ($LASTEXITCODE -eq 0) {
    Write-Output 'Compliant'
    exit 0
}

Write-Output 'NonCompliant'
exit 1
