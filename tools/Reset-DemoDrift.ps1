[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient',

    [string] $ValueName = 'EnableMulticast',

    [int] $CompliantValue = 0,

    [string] $MarkerPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptPath = Join-Path -Path $repositoryRoot -ChildPath 'src/tools/Reset-DemoDrift.ps1'
& $scriptPath @PSBoundParameters
exit 0
