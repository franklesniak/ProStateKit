[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri] $AssetUrl,

    [Parameter(Mandatory)]
    [string] $ExpectedSourceSha256,

    [string] $ExpectedRuntimeSha256 = '',

    [string] $RuntimeFileName = 'dsc.exe',

    [string] $WorkingRoot = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'prostatekit-dsc-runtime-candidate'),

    [switch] $Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function ConvertTo-NormalizedSha256 {
    param(
        [Parameter(Mandatory)]
        [string] $Hash
    )

    $normalizedHash = $Hash.Trim().ToLowerInvariant()
    if ($normalizedHash.StartsWith('sha256:')) {
        $normalizedHash = $normalizedHash.Substring('sha256:'.Length)
    }

    if ($normalizedHash -notmatch '^[a-f0-9]{64}$') {
        throw [System.ArgumentException]::new('Expected SHA-256 values must be 64 hex characters, optionally prefixed with sha256:.')
    }

    return $normalizedHash
}

function Get-PrefixedSha256 {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    return 'sha256:{0}' -f (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-DisposableWorkingRoot {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootPath = [System.IO.Path]::GetPathRoot($fullPath)
    $trimChars = [char[]] @([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ($fullPath.TrimEnd($trimChars) -eq $rootPath.TrimEnd($trimChars)) {
        throw [System.ArgumentException]::new('WorkingRoot must not be a filesystem root.')
    }

    $comparison = [System.StringComparison]::Ordinal
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        $comparison = [System.StringComparison]::OrdinalIgnoreCase
    }

    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $tempRootPrefix = $tempRoot.TrimEnd($trimChars) + [System.IO.Path]::DirectorySeparatorChar
    $fullPathPrefix = $fullPath.TrimEnd($trimChars) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPathPrefix.StartsWith($tempRootPrefix, $comparison)) {
        throw [System.ArgumentException]::new('WorkingRoot must resolve under the current user temp directory.')
    }

    $leafName = [System.IO.Path]::GetFileName(
        $fullPath.TrimEnd($trimChars)
    )
    if ($leafName -notmatch '^prostatekit-dsc-runtime-candidate($|[-_])') {
        throw [System.ArgumentException]::new('WorkingRoot must be a disposable ProStateKit candidate directory.')
    }

    return $fullPath
}

if ($AssetUrl.Scheme -ne 'https') {
    throw [System.ArgumentException]::new('AssetUrl must use HTTPS.')
}
if ($AssetUrl.Host.ToLowerInvariant() -ne 'github.com' -or
    $AssetUrl.AbsolutePath -notmatch '^/PowerShell/DSC/releases/download/') {
    throw [System.ArgumentException]::new('AssetUrl must point to a PowerShell/DSC GitHub release asset.')
}

$workingRootFull = Get-DisposableWorkingRoot -Path $WorkingRoot

$expectedSourceHash = ConvertTo-NormalizedSha256 -Hash $ExpectedSourceSha256
$expectedRuntimeHash = $null
if (-not [string]::IsNullOrWhiteSpace($ExpectedRuntimeSha256)) {
    $expectedRuntimeHash = ConvertTo-NormalizedSha256 -Hash $ExpectedRuntimeSha256
}

$fileName = [System.IO.Path]::GetFileName($AssetUrl.LocalPath)
if ([string]::IsNullOrWhiteSpace($fileName)) {
    throw [System.ArgumentException]::new('AssetUrl must end with a file name.')
}

$assetPath = Join-Path -Path $workingRootFull -ChildPath $fileName
$extractRoot = Join-Path -Path $workingRootFull -ChildPath 'extract'

if ((Test-Path -LiteralPath $workingRootFull) -and -not $Force.IsPresent) {
    throw [System.IO.IOException]::new('WorkingRoot already exists. Use -Force or choose a disposable empty path.')
}

Remove-Item -LiteralPath $workingRootFull -Recurse -Force -ErrorAction SilentlyContinue
[void] (New-Item -Path $workingRootFull -ItemType Directory -Force)

Invoke-WebRequest -Uri $AssetUrl -OutFile $assetPath

$actualSourceHash = Get-PrefixedSha256 -Path $assetPath
if ($actualSourceHash -ne ('sha256:{0}' -f $expectedSourceHash)) {
    throw [System.Security.SecurityException]::new('Downloaded DSC runtime asset hash did not match ExpectedSourceSha256.')
}

Expand-Archive -LiteralPath $assetPath -DestinationPath $extractRoot -Force

$runtimeMatches = @(Get-ChildItem -LiteralPath $extractRoot -Filter $RuntimeFileName -File -Recurse)
if ($runtimeMatches.Count -eq 0) {
    throw [System.IO.FileNotFoundException]::new('Runtime executable was not found in extracted candidate archive.', $RuntimeFileName)
}
if ($runtimeMatches.Count -gt 1) {
    throw [System.InvalidOperationException]::new('More than one runtime executable matched RuntimeFileName in extracted candidate archive.')
}

$actualRuntimeHash = Get-PrefixedSha256 -Path $runtimeMatches[0].FullName
if ($null -ne $expectedRuntimeHash -and $actualRuntimeHash -ne ('sha256:{0}' -f $expectedRuntimeHash)) {
    throw [System.Security.SecurityException]::new('Extracted runtime executable hash did not match ExpectedRuntimeSha256.')
}

[pscustomobject]@{
    assetUrl = $AssetUrl.AbsoluteUri
    assetPath = $assetPath
    assetSha256 = $actualSourceHash
    extractRoot = $extractRoot
    runtimePath = $runtimeMatches[0].FullName
    runtimeSha256 = $actualRuntimeHash
    extractedFileCount = @(Get-ChildItem -LiteralPath $extractRoot -File -Recurse).Count
    nextStep = 'Review the extracted files, then copy the full reviewed archive payload into runtime/dsc/ only after reviewer sign-off.'
}
