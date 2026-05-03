[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),

    [string] $OutputPath = (Join-Path -Path (Get-Location).Path -ChildPath 'dist'),

    [string] $Version = '0.1.0'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$buildBundlePath = Join-Path -Path $PSScriptRoot -ChildPath 'Build-Bundle.ps1'
if (-not (Test-Path -LiteralPath $buildBundlePath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('Build-Bundle.ps1 was not found.', $buildBundlePath)
}

$testBundlePath = Join-Path -Path $PSScriptRoot -ChildPath 'Test-Bundle.ps1'
if (-not (Test-Path -LiteralPath $testBundlePath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('Test-Bundle.ps1 was not found.', $testBundlePath)
}

$buildOutput = @(& $buildBundlePath -RepositoryRoot $RepositoryRoot -OutputPath $OutputPath -Version $Version)
if ($buildOutput.Count -eq 0) {
    throw [System.InvalidOperationException]::new('Build-Bundle.ps1 did not return a bundle ZIP path.')
}

$outputPathFull = [System.IO.Path]::GetFullPath($OutputPath)
$bundleRoot = Join-Path -Path $outputPathFull -ChildPath ('ProStateKit-{0}' -f $Version)
& $testBundlePath -BundleRoot $bundleRoot | Out-Null

Write-Output $buildOutput[-1]
