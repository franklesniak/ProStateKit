[CmdletBinding()]
param(
    [string] $BundleRoot = (Split-Path -Path $PSScriptRoot -Parent),

    [string] $ManifestPath = (Join-Path -Path $BundleRoot -ChildPath 'bundle.manifest.json')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptPath = Join-Path -Path $BundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
& $scriptPath @PSBoundParameters
exit 0
