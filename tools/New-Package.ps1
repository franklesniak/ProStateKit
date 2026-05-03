[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent),

    [string] $OutputPath = (Join-Path -Path (Get-Location).Path -ChildPath 'dist'),

    [string] $Version = '0.1.0'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptPath = Join-Path -Path $RepositoryRoot -ChildPath 'src/tools/New-Package.ps1'
& $scriptPath @PSBoundParameters
exit 0
