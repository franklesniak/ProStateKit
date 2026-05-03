[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $MarkerPath = 'C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptPath = Join-Path -Path $repositoryRoot -ChildPath 'src/tools/New-DemoDrift.ps1'
& $scriptPath @PSBoundParameters
exit 0
