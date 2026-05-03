[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $BundleRoot,

    [string] $ConfigPath = 'configs/baseline.dsc.yaml',

    [ValidateSet('PinnedBundle', 'InstalledPath', 'LabLatest')]
    [string] $RuntimeMode = 'PinnedBundle',

    [string] $RuntimePath,

    [string] $RuntimeExpectedHash,

    [string] $RuntimeExpectedVersion,

    [string] $LogRoot = 'C:\ProgramData\ProStateKit\Baseline',

    [switch] $AllowLabLatest,

    [switch] $AllowMissingRuntime
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath 'ProStateKit.Runtime.psm1') -Force
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath 'ProStateKit.Common.psm1') -Force

$bundleRootFull = Get-ProStateKitFullPath -PathValue $BundleRoot -BasePath (Get-Location).Path
$configPathFull = Get-ProStateKitFullPath -PathValue $ConfigPath -BasePath $bundleRootFull

if (-not (Test-Path -LiteralPath $bundleRootFull -PathType Container)) {
    throw [System.IO.DirectoryNotFoundException]::new('BundleRoot was not found: {0}' -f $bundleRootFull)
}

if (-not (Test-Path -LiteralPath $configPathFull -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('ConfigPath was not found.', $configPathFull)
}

if (-not (Test-ProStateKitPathInRoot -CandidatePath $configPathFull -RootPath $bundleRootFull)) {
    throw [System.UnauthorizedAccessException]::new('ConfigPath must resolve inside BundleRoot.')
}

if (Test-ProStateKitPathHasLink -CandidatePath $configPathFull -RootPath $bundleRootFull) {
    throw [System.UnauthorizedAccessException]::new('ConfigPath must not contain symlink or reparse-point components.')
}

$logRootFull = Get-ProStateKitFullPath -PathValue $LogRoot -BasePath (Get-Location).Path
[void] (New-Item -Path $logRootFull -ItemType Directory -Force)
$probePath = Join-Path -Path $logRootFull -ChildPath ('write-probe-{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
try {
    Set-Content -LiteralPath $probePath -Value 'ProStateKit write probe' -Encoding utf8
} finally {
    Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
}

try {
    $runtime = Resolve-ProStateKitRuntime `
        -RuntimeMode $RuntimeMode `
        -Plane 'Local' `
        -BundleRoot $bundleRootFull `
        -RuntimePath $RuntimePath `
        -AllowLabLatest:$AllowLabLatest.IsPresent
    if ($RuntimeMode -eq 'InstalledPath') {
        if (-not [string]::IsNullOrWhiteSpace($RuntimeExpectedHash) -and $runtime.observedHash -ne $RuntimeExpectedHash) {
            throw [System.Security.SecurityException]::new('InstalledPath runtime hash mismatch.')
        }

        if (-not [string]::IsNullOrWhiteSpace($RuntimeExpectedVersion) -and $runtime.version -ne $RuntimeExpectedVersion) {
            throw [System.InvalidOperationException]::new('InstalledPath runtime version mismatch.')
        }
    }

    $runtime | ConvertTo-Json -Depth 5
} catch {
    if (-not $AllowMissingRuntime.IsPresent) {
        throw
    }
    Write-Warning ('Runtime check skipped for source validation: {0}' -f $_.Exception.Message)
}
