# Preview scaffold for local preflight and demo rehearsal.
# Production behavior requires the final pinned bundle and lab validation.
[CmdletBinding()]
param(
    [string] $BundleRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),

    [string] $ConfigPath = 'configs/baseline.dsc.yaml',

    [ValidateSet('PinnedBundle', 'InstalledPath', 'LabLatest')]
    [string] $RuntimeMode = 'PinnedBundle',

    [string] $EvidenceRoot = 'C:\ProgramData\ProStateKit\Evidence',

    [string] $OperationId,

    [string] $DemoMarkerPath = 'C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt',

    [switch] $AllowLabLatest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$entryPoint = Join-Path -Path $BundleRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
& $entryPoint `
    -Mode 'Preflight' `
    -Plane 'Local' `
    -ConfigPath $ConfigPath `
    -RuntimeMode $RuntimeMode `
    -EvidenceRoot $EvidenceRoot `
    -OperationId $OperationId `
    -DemoMarkerPath $DemoMarkerPath `
    -BundleRoot $BundleRoot `
    -AllowLabLatest:$AllowLabLatest.IsPresent
exit $LASTEXITCODE
