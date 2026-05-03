function Get-ProStateKitFullPath {
    param(
        [Parameter(Mandatory)]
        [string] $PathValue,

        [Parameter(Mandatory)]
        [string] $BasePath
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $BasePath -ChildPath $PathValue))
}

function Test-ProStateKitWindows {
    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Test-ProStateKitPathInRoot {
    param(
        [Parameter(Mandatory)]
        [string] $CandidatePath,

        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not (Test-ProStateKitWindows)) {
        $comparison = [System.StringComparison]::Ordinal
    }

    $rootWithSeparator = $RootPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar

    return $CandidatePath.StartsWith($rootWithSeparator, $comparison) -or $CandidatePath.Equals($RootPath, $comparison)
}

function Test-ProStateKitFileSystemLink {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo] $Item
    )

    if (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        return $true
    }

    $linkTypeProperty = $Item.PSObject.Properties['LinkType']
    if ($null -ne $linkTypeProperty -and -not [string]::IsNullOrWhiteSpace([string] $linkTypeProperty.Value)) {
        return $true
    }

    return $false
}

function Test-ProStateKitPathHasLink {
    param(
        [Parameter(Mandatory)]
        [string] $CandidatePath,

        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $candidateFull = Get-ProStateKitFullPath -PathValue $CandidatePath -BasePath (Get-Location).Path
    $rootFull = Get-ProStateKitFullPath -PathValue $RootPath -BasePath (Get-Location).Path
    $segments = [System.Collections.Generic.List[string]]::new()
    $relativePath = [System.IO.Path]::GetRelativePath($rootFull, $candidateFull)

    if ($relativePath -ne '.') {
        foreach ($segment in $relativePath -split '[\\/]') {
            if (-not [string]::IsNullOrWhiteSpace($segment)) {
                [void] $segments.Add($segment)
            }
        }
    }

    $currentPath = $rootFull
    if (Test-Path -LiteralPath $currentPath) {
        $item = Get-Item -LiteralPath $currentPath -Force
        if (Test-ProStateKitFileSystemLink -Item $item) {
            return $true
        }
    }

    foreach ($segment in $segments) {
        $currentPath = Join-Path -Path $currentPath -ChildPath $segment
        if (-not (Test-Path -LiteralPath $currentPath)) {
            continue
        }

        $item = Get-Item -LiteralPath $currentPath -Force
        if (Test-ProStateKitFileSystemLink -Item $item) {
            return $true
        }
    }

    return $false
}

function Get-ProStateKitSha256 {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    return 'sha256:{0}' -f (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Export-ModuleMember -Function @(
    'Get-ProStateKitFullPath',
    'Test-ProStateKitWindows',
    'Test-ProStateKitPathInRoot',
    'Test-ProStateKitPathHasLink',
    'Get-ProStateKitSha256'
)
