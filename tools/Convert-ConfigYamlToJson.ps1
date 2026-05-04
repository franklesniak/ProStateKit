[CmdletBinding()]
param(
    [string] $SourcePath = 'configs/baseline.dsc.yaml',

    [string] $DestinationPath = 'configs/generated/baseline.dsc.json',

    [string] $DependencyRoot = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($DependencyRoot)) {
    $DependencyRoot = $repositoryRoot
}
$PSBoundParameters['DependencyRoot'] = $DependencyRoot

$scriptPath = Join-Path -Path $repositoryRoot -ChildPath 'src/tools/Convert-ConfigYamlToJson.ps1'
& $scriptPath @PSBoundParameters
exit 0
