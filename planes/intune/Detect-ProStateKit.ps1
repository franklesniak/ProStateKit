# Preview scaffold for Intune Remediations detection.
# Production behavior requires the final pinned bundle and Intune lab validation.
[CmdletBinding()]
param(
    [string] $BundleRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),

    [string] $ConfigPath = 'configs/baseline.dsc.yaml',

    [string] $EvidenceRoot = 'C:\ProgramData\ProStateKit\Evidence'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$entryPoint = Join-Path -Path $BundleRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
& $entryPoint `
    -Mode 'Detect' `
    -Plane 'Intune' `
    -ConfigPath $ConfigPath `
    -RuntimeMode 'PinnedBundle' `
    -EvidenceRoot $EvidenceRoot `
    -BundleRoot $BundleRoot
exit $LASTEXITCODE
