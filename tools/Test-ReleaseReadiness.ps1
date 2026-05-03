[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent),

    [string] $ReleaseOutputPath,

    [string] $LabEvidenceRoot,

    [string] $IntuneEvidencePath,

    [string] $ConfigMgrEvidencePath,

    [ValidateSet('Text', 'Json')]
    [string] $OutputFormat = 'Text'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptPath = Join-Path -Path $RepositoryRoot -ChildPath 'src/tools/Test-ReleaseReadiness.ps1'
& $scriptPath @PSBoundParameters
exit $LASTEXITCODE
