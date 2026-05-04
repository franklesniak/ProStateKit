# Preview implementation. It invokes DSC only after local bundle and path checks pass.
# Missing runtime, parser failures, and incomplete proof return non-zero and write evidence.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Detect', 'Remediate')]
    [string] $Mode,

    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [Parameter(Mandatory)]
    [string] $BundleRoot,

    [ValidateSet('Local', 'Intune', 'ConfigMgr', 'CI')]
    [string] $Plane = 'Local',

    [ValidateSet('PinnedBundle', 'InstalledPath', 'LabLatest')]
    [string] $RuntimeMode = 'PinnedBundle',

    [string] $RuntimePath,

    [string] $RuntimeExpectedHash,

    [string] $RuntimeExpectedVersion,

    [string] $LogRoot = 'C:\ProgramData\ProStateKit\Baseline',

    [string] $RunId,

    [switch] $AllowLabLatest,

    [bool] $Strict = $true
)

$ErrorActionPreference = 'Stop'
if ($Strict) {
    Set-StrictMode -Version Latest
}

# Exit-code contract:
# Detect:
#   0 = compliant
#   1 = non-compliant
#   2 = runtime failure
#   3 = parse failure / proof missing
#
# Remediate:
#   0 = success after verification
#   1 = partial or failed convergence
#   2 = runtime failure
#   3 = parse failure / proof missing

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

function Test-ProStateKitIsWindows {
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
    if (-not (Test-ProStateKitIsWindows)) {
        $comparison = [System.StringComparison]::Ordinal
    }

    $rootWithSeparator = $RootPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar

    $startsInRoot = $CandidatePath.StartsWith($rootWithSeparator, $comparison)
    $isRoot = $CandidatePath.Equals($RootPath, $comparison)

    return $startsInRoot -or $isRoot
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
        [AllowNull()]
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 'TBD'
    }

    return 'sha256:{0}' -f (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ProStateKitRuntime {
    param(
        [Parameter(Mandatory)]
        [string] $CurrentRuntimeMode,

        [Parameter(Mandatory)]
        [string] $CurrentPlane,

        [Parameter(Mandatory)]
        [string] $CurrentBundleRoot,

        [string] $CurrentRuntimePath,

        [bool] $IsLabLatestAllowed = $false
    )

    $source = 'BundleRoot'
    $candidatePath = $CurrentRuntimePath

    if ($CurrentRuntimeMode -eq 'PinnedBundle') {
        $dscExeName = 'dsc'
        if (Test-ProStateKitIsWindows) {
            $dscExeName = 'dsc.exe'
        }
        $candidatePath = Join-Path -Path $CurrentBundleRoot -ChildPath (Join-Path -Path 'runtime/dsc' -ChildPath $dscExeName)
        if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
            $candidatePath = Join-Path -Path $CurrentBundleRoot -ChildPath (Join-Path -Path 'Runtime/dsc' -ChildPath $dscExeName)
        }
    } elseif ($CurrentRuntimeMode -eq 'InstalledPath') {
        $source = 'InstalledPath'
        if ([string]::IsNullOrWhiteSpace($candidatePath)) {
            $command = Get-Command -Name 'dsc' -CommandType Application -ErrorAction SilentlyContinue
            if ($null -ne $command) {
                $candidatePath = $command.Source
                $source = 'PATH'
            }
        }
    } elseif ($CurrentRuntimeMode -eq 'LabLatest') {
        if ($CurrentPlane -in @('Intune', 'ConfigMgr')) {
            throw [System.InvalidOperationException]::new('LabLatest runtime mode is blocked for Intune and ConfigMgr planes.')
        }
        if (-not $IsLabLatestAllowed) {
            throw [System.InvalidOperationException]::new('LabLatest runtime mode requires -AllowLabLatest.')
        }
        $source = 'PATH'
        $command = Get-Command -Name 'dsc' -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            $candidatePath = $command.Source
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($candidatePath)) {
        $candidatePath = Get-ProStateKitFullPath -PathValue $candidatePath -BasePath (Get-Location).Path
    }

    return [pscustomobject]@{
        mode = $CurrentRuntimeMode
        path = $candidatePath
        version = 'TBD'
        source = $source
        expectedHash = 'TBD'
        observedHash = Get-ProStateKitSha256 -Path $candidatePath
    }
}

function Test-ProStateKitManifest {
    param(
        [Parameter(Mandatory)]
        [string] $CurrentBundleRoot
    )

    $manifestPath = Join-Path -Path $CurrentBundleRoot -ChildPath 'bundle.manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return [pscustomobject]@{
            hash = 'missing'
            manifest = $null
        }
    }

    $schemaPath = Join-Path -Path $CurrentBundleRoot -ChildPath 'schemas/bundle-manifest.schema.json'
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new('Bundle manifest schema was not found.', $schemaPath)
    }

    $manifestHash = Get-ProStateKitSha256 -Path $manifestPath
    $manifestJson = Get-Content -LiteralPath $manifestPath -Raw
    $schemaJson = Get-Content -LiteralPath $schemaPath -Raw
    if (-not (Test-Json -Json $manifestJson -Schema $schemaJson -ErrorAction SilentlyContinue)) {
        throw [System.FormatException]::new('Bundle manifest failed schema validation.')
    }

    $manifest = $manifestJson | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $manifest.files -or @($manifest.files).Count -eq 0) {
        throw [System.FormatException]::new('Bundle manifest must include file hash entries.')
    }

    $manifestFilePaths = @($manifest.files | ForEach-Object -Process { $_.path })
    $duplicateManifestFilePaths = @(
        $manifestFilePaths |
            Group-Object |
            Where-Object -FilterScript { $_.Count -gt 1 } |
            ForEach-Object -Process { $_.Name }
    )
    if ($duplicateManifestFilePaths.Count -gt 0) {
        throw [System.Security.SecurityException]::new('Bundle manifest contains duplicate file paths: {0}' -f ($duplicateManifestFilePaths -join ', '))
    }

    foreach ($fileEntry in @($manifest.files)) {
        $filePath = Get-ProStateKitFullPath -PathValue (Join-Path -Path $CurrentBundleRoot -ChildPath $fileEntry.path) -BasePath $CurrentBundleRoot
        if (-not (Test-ProStateKitPathInRoot -CandidatePath $filePath -RootPath $CurrentBundleRoot)) {
            throw [System.UnauthorizedAccessException]::new('Manifest file path escaped BundleRoot.')
        }
        if (Test-ProStateKitPathHasLink -CandidatePath $filePath -RootPath $CurrentBundleRoot) {
            throw [System.UnauthorizedAccessException]::new('Manifest file path must not contain symlink or reparse-point components.')
        }
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]::new('Manifest file entry was not found.', $filePath)
        }
        if ([string]::IsNullOrWhiteSpace($fileEntry.sha256) -or $fileEntry.sha256 -eq 'TBD') {
            throw [System.Security.SecurityException]::new('Manifest hash entry is not pinned for {0}.' -f $fileEntry.path)
        }

        $observedHash = Get-ProStateKitSha256 -Path $filePath
        if ($observedHash -ne $fileEntry.sha256) {
            throw [System.Security.SecurityException]::new('Manifest hash mismatch for {0}.' -f $fileEntry.path)
        }
    }

    return [pscustomobject]@{
        hash = $manifestHash
        manifest = $manifest
    }
}

function Get-ProStateKitObjectPropertyValue {
    param(
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-ProStateKitManifestRuntime {
    param(
        [AllowNull()]
        [object] $Manifest,

        [Parameter(Mandatory)]
        [string] $CurrentRuntimeMode,

        [Parameter(Mandatory)]
        [object] $RuntimeInfo,

        [Parameter(Mandatory)]
        [string] $CurrentDscVersion,

        [Parameter(Mandatory)]
        [string] $CurrentBundleRoot
    )

    if ($null -eq $Manifest -and $CurrentRuntimeMode -eq 'PinnedBundle') {
        throw [System.Security.SecurityException]::new('PinnedBundle runtime mode requires bundle.manifest.json.')
    }

    if ($null -eq $Manifest) {
        return
    }

    $manifestRuntime = Get-ProStateKitObjectPropertyValue -InputObject $Manifest -Name 'runtime'
    if ($null -eq $manifestRuntime) {
        throw [System.FormatException]::new('Bundle manifest must include runtime metadata.')
    }

    $manifestRuntimePath = [string] (Get-ProStateKitObjectPropertyValue -InputObject $manifestRuntime -Name 'path')
    if ([string]::IsNullOrWhiteSpace($manifestRuntimePath)) {
        throw [System.FormatException]::new('Bundle manifest must include runtime.path.')
    }

    $manifestRuntimePathFull = Get-ProStateKitFullPath -PathValue $manifestRuntimePath -BasePath $CurrentBundleRoot
    if (-not (Test-ProStateKitPathInRoot -CandidatePath $manifestRuntimePathFull -RootPath $CurrentBundleRoot)) {
        throw [System.UnauthorizedAccessException]::new('Manifest runtime path escaped BundleRoot.')
    }
    if (Test-ProStateKitPathHasLink -CandidatePath $manifestRuntimePathFull -RootPath $CurrentBundleRoot) {
        throw [System.UnauthorizedAccessException]::new('Manifest runtime path must not contain symlink or reparse-point components.')
    }

    if ($CurrentRuntimeMode -eq 'PinnedBundle') {
        $comparison = [System.StringComparison]::Ordinal
        if (Test-ProStateKitIsWindows) {
            $comparison = [System.StringComparison]::OrdinalIgnoreCase
        }
        if (-not ([string] $RuntimeInfo.path).Equals($manifestRuntimePathFull, $comparison)) {
            throw [System.Security.SecurityException]::new('Pinned runtime path did not match bundle manifest runtime.path.')
        }
    }

    $expectedHash = [string] (Get-ProStateKitObjectPropertyValue -InputObject $manifestRuntime -Name 'expectedHash')
    if ([string]::IsNullOrWhiteSpace($expectedHash) -or $expectedHash -eq 'TBD') {
        throw [System.Security.SecurityException]::new('Manifest runtime expected hash is not pinned.')
    }

    $RuntimeInfo.expectedHash = $expectedHash
    $observedHash = Get-ProStateKitSha256 -Path $RuntimeInfo.path
    $RuntimeInfo.observedHash = $observedHash
    if ($observedHash -ne $expectedHash) {
        throw [System.Security.SecurityException]::new('Runtime hash mismatch.')
    }

    $manifestDscVersion = [string] (Get-ProStateKitObjectPropertyValue -InputObject $Manifest -Name 'dscVersion')
    if ([string]::IsNullOrWhiteSpace($manifestDscVersion) -or $manifestDscVersion -eq 'TBD') {
        throw [System.Security.SecurityException]::new('Manifest DSC version is not pinned.')
    }
    if ($manifestDscVersion -ne $CurrentDscVersion) {
        throw [System.InvalidOperationException]::new('Runtime version mismatch.')
    }
}

function Test-ProStateKitManifestConfig {
    param(
        [AllowNull()]
        [object] $Manifest,

        [Parameter(Mandatory)]
        [string] $CurrentConfigPath,

        [Parameter(Mandatory)]
        [string] $CurrentBundleRoot
    )

    if ($null -eq $Manifest) {
        return
    }

    $relativeConfigPath = [System.IO.Path]::GetRelativePath($CurrentBundleRoot, $CurrentConfigPath).Replace('\', '/')
    if ($relativeConfigPath.StartsWith('..') -or [System.IO.Path]::IsPathRooted($relativeConfigPath)) {
        throw [System.UnauthorizedAccessException]::new('ConfigPath must resolve inside BundleRoot.')
    }

    $comparison = [System.StringComparison]::Ordinal
    if (Test-ProStateKitIsWindows) {
        $comparison = [System.StringComparison]::OrdinalIgnoreCase
    }

    $coveredByManifest = $false
    foreach ($manifestPath in @($Manifest.files | ForEach-Object -Process { ([string] $_.path).Replace('\', '/') })) {
        if ($relativeConfigPath.Equals($manifestPath, $comparison)) {
            $coveredByManifest = $true
            break
        }
    }

    if (-not $coveredByManifest) {
        throw [System.Security.SecurityException]::new('ConfigPath is not covered by manifest hashes: {0}' -f $relativeConfigPath)
    }

    $manifestConfigHash = [string] (Get-ProStateKitObjectPropertyValue -InputObject $Manifest -Name 'configHash')
    if (-not [string]::IsNullOrWhiteSpace($manifestConfigHash) -and $manifestConfigHash -ne 'TBD') {
        $observedConfigHash = Get-ProStateKitSha256 -Path $CurrentConfigPath
        if ($observedConfigHash -ne $manifestConfigHash) {
            throw [System.Security.SecurityException]::new('Config hash mismatch.')
        }
    }
}

function Get-ProStateKitResourceResult {
    param(
        [string] $Name = 'ProStateKit wrapper',

        [string] $Type = 'ProStateKit/Internal',

        [bool] $Succeeded = $false,

        [bool] $Changed = $false,

        [AllowNull()]
        [string] $ErrorMessage = $null,

        [bool] $RebootRequired = $false
    )

    return [pscustomobject]@{
        name = $Name
        type = $Type
        succeeded = $Succeeded
        changed = $Changed
        error = $ErrorMessage
        rebootRequired = $RebootRequired
    }
}

function Get-ProStateKitResult {
    param(
        [Parameter(Mandatory)]
        [string] $CurrentMode,

        [Parameter(Mandatory)]
        [string] $CurrentRunId,

        [Parameter(Mandatory)]
        [datetime] $StartedUtc,

        [string] $CurrentPlane = $Plane,

        [string] $DscVersion = 'TBD',

        [bool] $Succeeded = $false,

        [bool] $Compliant = $false,

        [bool] $RebootRequired = $false,

        [Parameter(Mandatory)]
        [object[]] $Resources,

        [AllowNull()]
        [string] $ResolvedConfigPath = $configPathFull,

        [AllowNull()]
        [object] $RuntimeInfo = $runtimeInfo,

        [AllowNull()]
        [string] $EvidencePath = $runRoot,

        [string] $CurrentManifestHash = $manifestHash,

        [int] $ExitCode = 1,

        [string] $ExitReason = 'Unknown',

        [string[]] $Errors = @(),

        [string[]] $Warnings = @()
    )

    $endedUtc = [datetime]::UtcNow
    $configHash = Get-ProStateKitSha256 -Path $ResolvedConfigPath
    $runtimeVersion = $DscVersion
    $runtimeModeValue = $RuntimeMode
    $runtimePathValue = $null
    $runtimeExpectedHash = 'TBD'
    $runtimeObservedHash = 'TBD'
    if ($null -ne $RuntimeInfo) {
        $runtimeModeValue = $RuntimeInfo.mode
        $runtimePathValue = $RuntimeInfo.path
        $runtimeExpectedHash = $RuntimeInfo.expectedHash
        $runtimeObservedHash = $RuntimeInfo.observedHash
        if (-not [string]::IsNullOrWhiteSpace($RuntimeInfo.version)) {
            $runtimeVersion = $RuntimeInfo.version
        }
    }

    $classification = 'Failed'
    if ($Succeeded -and $Compliant) {
        $classification = 'Compliant'
    } elseif ($Succeeded -and -not $Compliant) {
        $classification = 'NonCompliant'
    }

    return [pscustomobject]@{
        schemaVersion = '1.0.0'
        operationId = $CurrentRunId
        runId = $CurrentRunId
        mode = $CurrentMode
        plane = $CurrentPlane
        bundle = [pscustomobject]@{
            name = 'ProStateKit'
            version = '0.1.0'
            sourceCommit = 'unknown'
            manifestHash = $CurrentManifestHash
        }
        runtime = [pscustomobject]@{
            mode = $runtimeModeValue
            path = $runtimePathValue
            version = $runtimeVersion
            expectedHash = $runtimeExpectedHash
            observedHash = $runtimeObservedHash
        }
        config = [pscustomobject]@{
            path = $ResolvedConfigPath
            hash = $configHash
        }
        startedAt = $StartedUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        endedAt = $endedUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        durationMs = [int] [Math]::Round(($endedUtc - $StartedUtc).TotalMilliseconds)
        startedUtc = $StartedUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        endedUtc = $endedUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        dscVersion = $DscVersion
        compliant = $Compliant
        classification = $classification
        overall = [pscustomobject]@{
            succeeded = $Succeeded
            compliant = $Compliant
            rebootRequired = $RebootRequired
        }
        resources = @($Resources)
        reboot = [pscustomobject]@{
            required = $RebootRequired
            signals = @()
        }
        exitDecision = [pscustomobject]@{
            exitCode = $ExitCode
            reason = $ExitReason
        }
        evidencePath = $EvidencePath
        errors = @($Errors)
        warnings = @($Warnings)
    }
}

function Write-ProStateKitEvidence {
    param(
        [Parameter(Mandatory)]
        [string] $RunRoot,

        [Parameter(Mandatory)]
        [object] $Result,

        [Parameter(Mandatory)]
        [string] $Summary,

        [string] $RawContent,

        [string] $RawFileName = 'dsc.raw.json',

        [hashtable] $ExtraRawFiles = @{},

        [string] $StdErrContent = '',

        [string] $BundleRoot,

        [string] $RuntimePath,

        [object] $RuntimeInfo,

        [string] $DscVersion = 'TBD',

        [int] $DscExitCode = -1
    )

    [void] [System.IO.Directory]::CreateDirectory($RunRoot)

    if ($null -ne $RawContent) {
        Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath $RawFileName) -Value $RawContent -Encoding utf8
        if ($RawFileName -ne 'dsc.raw.json') {
            Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'dsc.raw.json') -Value $RawContent -Encoding utf8
        }
    }

    foreach ($fileName in $ExtraRawFiles.Keys) {
        Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath $fileName) -Value $ExtraRawFiles[$fileName] -Encoding utf8
    }

    Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'dsc.stderr.log') -Value $StdErrContent -Encoding utf8
    Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'dsc.exitcode.txt') -Value ([string] $DscExitCode) -Encoding utf8
    Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'wrapper.log') -Value $Summary -Encoding utf8
    $transcriptLines = @(
        'ProStateKit wrapper transcript'
        ('operationId={0}' -f $Result.operationId)
        ('mode={0}' -f $Result.mode)
        ('plane={0}' -f $Result.plane)
        ('classification={0}' -f $Result.classification)
        ('exitCode={0}' -f $Result.exitDecision.exitCode)
        ('exitReason={0}' -f $Result.exitDecision.reason)
        ('dscExitCode={0}' -f $DscExitCode)
        ('startedAt={0}' -f $Result.startedAt)
        ('endedAt={0}' -f $Result.endedAt)
        ('evidencePath={0}' -f $Result.evidencePath)
    )
    Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'transcript.log') -Value $transcriptLines -Encoding utf8
    $runtimeEvidence = [pscustomobject]@{
        mode = $RuntimeMode
        path = $RuntimePath
        version = $DscVersion
        source = 'BundleRoot'
        expectedHash = 'TBD'
        observedHash = Get-ProStateKitSha256 -Path $RuntimePath
    }
    if ($null -ne $RuntimeInfo) {
        $runtimeEvidence = [pscustomobject]@{
            mode = $RuntimeInfo.mode
            path = $RuntimeInfo.path
            version = $DscVersion
            source = $RuntimeInfo.source
            expectedHash = $RuntimeInfo.expectedHash
            observedHash = $RuntimeInfo.observedHash
        }
    }
    Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'runtime.json') -Value (
        $runtimeEvidence | ConvertTo-Json -Depth 5
    ) -Encoding utf8

    $manifestSnapshotPath = Join-Path -Path $RunRoot -ChildPath 'manifest.snapshot.json'
    if (-not [string]::IsNullOrWhiteSpace($BundleRoot)) {
        $manifestPath = Join-Path -Path $BundleRoot -ChildPath 'bundle.manifest.json'
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            Copy-Item -LiteralPath $manifestPath -Destination $manifestSnapshotPath -Force
        } else {
            Set-Content -LiteralPath $manifestSnapshotPath -Value (
                [pscustomobject]@{
                    status = 'missing'
                    path = $manifestPath
                } | ConvertTo-Json -Depth 5
            ) -Encoding utf8
        }
    }

    Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'wrapper.result.json') -Value (
        $Result | ConvertTo-Json -Depth 20
    ) -Encoding utf8
    Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'summary.txt') -Value $Summary -Encoding utf8

    $evidenceRoot = Split-Path -Path (Split-Path -Path $RunRoot -Parent) -Parent
    $currentRoot = Join-Path -Path $evidenceRoot -ChildPath 'Current'
    [void] [System.IO.Directory]::CreateDirectory($currentRoot)

    $currentRebootMarkerPath = Join-Path -Path $currentRoot -ChildPath 'reboot.marker.json'
    if ($Result.overall.rebootRequired) {
        $rebootMarkerJson = [pscustomobject]@{
            operationId = $Result.operationId
            createdAt = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
            reason = 'Normalized DSC proof reported rebootRequired.'
            evidencePath = $Result.evidencePath
        } | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath (Join-Path -Path $RunRoot -ChildPath 'reboot.marker.json') -Value $rebootMarkerJson -Encoding utf8
        Set-Content -LiteralPath $currentRebootMarkerPath -Value $rebootMarkerJson -Encoding utf8
    } elseif ($Result.overall.succeeded -and $Result.overall.compliant) {
        Remove-Item -LiteralPath $currentRebootMarkerPath -Force -ErrorAction SilentlyContinue
    }

    $lastResultPath = Join-Path -Path $currentRoot -ChildPath 'last-result.json'
    $lastResultTempPath = '{0}.tmp' -f $lastResultPath
    Set-Content -LiteralPath $lastResultTempPath -Value ($Result | ConvertTo-Json -Depth 20) -Encoding utf8
    Move-Item -LiteralPath $lastResultTempPath -Destination $lastResultPath -Force
}

function ConvertFrom-ProStateKitDscOutput {
    param(
        [Parameter(Mandatory)]
        [string] $JsonText,

        [Parameter(Mandatory)]
        [string] $CurrentMode
    )

    $parsed = $JsonText | ConvertFrom-Json -ErrorAction Stop
    $candidateCollections = foreach ($propertyName in @('resources', 'results', 'result', 'actualState')) {
        $property = $parsed.PSObject.Properties[$propertyName]
        if ($null -ne $property) {
            $property.Value
        }
    }
    $items = @()

    foreach ($collection in $candidateCollections) {
        if ($null -eq $collection) {
            continue
        }

        if ($collection -is [array]) {
            $items = @($collection)
        } else {
            $items = @($collection)
        }

        if ($items.Count -gt 0) {
            break
        }
    }

    if ($items.Count -eq 0) {
        $rootProperties = @($parsed.PSObject.Properties.Name)
        if ($rootProperties -contains 'name' -or
            $rootProperties -contains 'resourceName' -or
            $rootProperties -contains 'type' -or
            $rootProperties -contains 'resourceType') {
            $items = @($parsed)
        } else {
            throw [System.FormatException]::new('DSC output did not contain resource proof.')
        }
    }

    $resources = foreach ($item in $items) {
        $properties = $item.PSObject.Properties
        $nameProperty = @(
            $properties['name']
            $properties['resourceName']
            $properties['instanceName']
        ) | Where-Object -FilterScript { $null -ne $_ } | Select-Object -First 1
        $typeProperty = @(
            $properties['type']
            $properties['resourceType']
            $properties['fullyQualifiedTypeName']
        ) | Where-Object -FilterScript { $null -ne $_ } | Select-Object -First 1
        $resultProperty = $properties['result']
        $resultValue = $null
        $nestedResultProperties = $null
        if ($null -ne $resultProperty) {
            $resultValue = $resultProperty.Value
            if ($null -ne $resultValue -and
                $resultValue -isnot [string] -and
                $resultValue -isnot [ValueType]) {
                $nestedResultProperties = $resultValue.PSObject.Properties
            }
        }

        $errorPropertyCandidates = @(
            $properties['error']
            $properties['errorMessage']
            $properties['message']
        )
        if ($null -ne $nestedResultProperties) {
            $errorPropertyCandidates += @(
                $nestedResultProperties['error']
                $nestedResultProperties['errorMessage']
                $nestedResultProperties['message']
            )
        }
        $errorProperty = $errorPropertyCandidates | Where-Object -FilterScript { $null -ne $_ } | Select-Object -First 1
        $name = $null
        $type = $null
        $errorValue = $null
        if ($null -ne $nameProperty) {
            $name = $nameProperty.Value
        }
        if ($null -ne $typeProperty) {
            $type = $typeProperty.Value
        }
        if ($null -ne $errorProperty) {
            $errorValue = $errorProperty.Value
        }

        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = 'Unnamed DSC resource'
        }
        if ([string]::IsNullOrWhiteSpace($type)) {
            $type = 'Unknown'
        }

        $succeeded = $false
        $succeededWasResolved = $false
        foreach ($propertyName in @('succeeded', 'success', 'inDesiredState', 'compliant')) {
            if ($null -ne $properties[$propertyName]) {
                $succeeded = [bool] $properties[$propertyName].Value
                $succeededWasResolved = $true
                break
            }
        }

        if (-not $succeededWasResolved -and $null -ne $nestedResultProperties) {
            foreach ($propertyName in @('succeeded', 'success', 'inDesiredState', 'compliant')) {
                if ($null -ne $nestedResultProperties[$propertyName]) {
                    $succeeded = [bool] $nestedResultProperties[$propertyName].Value
                    $succeededWasResolved = $true
                    break
                }
            }
        }

        if ($null -ne $resultProperty -and $resultValue -is [string]) {
            $resultText = [string] $resultValue
            if ($resultText -match '^(Success|Succeeded|Compliant|InDesiredState)$') {
                $succeeded = $true
            } elseif ($resultText -match '(Fail|Error|NonCompliant|NotInDesiredState)') {
                $succeeded = $false
            }
        }

        $changed = $false
        $changedWasResolved = $false
        foreach ($propertyName in @('changed', 'wasChanged', 'rebootRequired')) {
            if ($null -ne $properties[$propertyName]) {
                $changed = [bool] $properties[$propertyName].Value
                $changedWasResolved = $true
                break
            }
        }
        if (-not $changedWasResolved -and $null -ne $nestedResultProperties) {
            foreach ($propertyName in @('changed', 'wasChanged', 'rebootRequired')) {
                if ($null -ne $nestedResultProperties[$propertyName]) {
                    $changed = [bool] $nestedResultProperties[$propertyName].Value
                    break
                }
            }
        }
        if ($CurrentMode -eq 'Detect') {
            $changed = $false
        }

        $rebootRequired = $false
        if ($null -ne $properties['rebootRequired']) {
            $rebootRequired = [bool] $properties['rebootRequired'].Value
        } elseif ($null -ne $nestedResultProperties -and $null -ne $nestedResultProperties['rebootRequired']) {
            $rebootRequired = [bool] $nestedResultProperties['rebootRequired'].Value
        }

        Get-ProStateKitResourceResult `
            -Name $name `
            -Type $type `
            -Succeeded $succeeded `
            -Changed $changed `
            -ErrorMessage $errorValue `
            -RebootRequired $rebootRequired
    }

    if (@($resources).Count -eq 0) {
        throw [System.FormatException]::new('DSC output did not normalize to any resource results.')
    }

    return @($resources)
}

$startedUtc = [datetime]::UtcNow
$bundleRootFull = $null
$configPathFull = $null
$dscPath = $null
$dscVersion = 'TBD'
$manifestHash = 'missing'
$bundleManifest = $null
$runtimeInfo = [pscustomobject]@{
    mode = $RuntimeMode
    path = $RuntimePath
    version = 'TBD'
    source = $RuntimeMode
    expectedHash = 'TBD'
    observedHash = 'TBD'
}
if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = '{0}-{1}' -f $startedUtc.ToString('yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
}

$runRoot = Join-Path -Path $LogRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath $RunId)

try {
    $bundleRootFull = Get-ProStateKitFullPath -PathValue $BundleRoot -BasePath (Get-Location).Path
    $configPathFull = Get-ProStateKitFullPath -PathValue $ConfigPath -BasePath (Get-Location).Path

    if (-not (Test-Path -LiteralPath $configPathFull -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new('Configuration document was not found.', $configPathFull)
    }

    if (-not (Test-ProStateKitPathInRoot -CandidatePath $configPathFull -RootPath $bundleRootFull)) {
        throw [System.UnauthorizedAccessException]::new('ConfigPath must resolve inside BundleRoot.')
    }

    if (Test-ProStateKitPathHasLink -CandidatePath $configPathFull -RootPath $bundleRootFull) {
        throw [System.UnauthorizedAccessException]::new('ConfigPath must not contain symlink or reparse-point components.')
    }

    $manifestInfo = Test-ProStateKitManifest -CurrentBundleRoot $bundleRootFull
    $manifestHash = $manifestInfo.hash
    $bundleManifest = $manifestInfo.manifest
    Test-ProStateKitManifestConfig `
        -Manifest $bundleManifest `
        -CurrentConfigPath $configPathFull `
        -CurrentBundleRoot $bundleRootFull

    $runtimeInfo = Get-ProStateKitRuntime `
        -CurrentRuntimeMode $RuntimeMode `
        -CurrentPlane $Plane `
        -CurrentBundleRoot $bundleRootFull `
        -CurrentRuntimePath $RuntimePath `
        -IsLabLatestAllowed $AllowLabLatest.IsPresent
    $dscPath = $runtimeInfo.path
    if ([string]::IsNullOrWhiteSpace($dscPath) -or -not (Test-Path -LiteralPath $dscPath -PathType Leaf)) {
        $resource = Get-ProStateKitResourceResult `
            -Name 'DSC runtime' `
            -Type 'ProStateKit/Runtime' `
            -ErrorMessage ('DSC runtime not found at {0}.' -f $dscPath)
        $result = Get-ProStateKitResult `
            -CurrentMode $Mode `
            -CurrentRunId $RunId `
            -StartedUtc $startedUtc `
            -Succeeded $false `
            -Compliant $false `
            -Resources @($resource) `
            -ExitCode 2 `
            -ExitReason 'RuntimeMissing' `
            -Errors @($resource.error)
        Write-ProStateKitEvidence `
            -RunRoot $runRoot `
            -Result $result `
            -Summary 'Runtime failure: DSC runtime was not found.' `
            -StdErrContent '' `
            -BundleRoot $bundleRootFull `
            -RuntimePath $dscPath `
            -RuntimeInfo $runtimeInfo `
            -DscVersion $dscVersion `
            -DscExitCode -1
        exit 2
    }

    if ($RuntimeMode -eq 'PinnedBundle' -and (Test-ProStateKitPathHasLink -CandidatePath $dscPath -RootPath $bundleRootFull)) {
        throw [System.UnauthorizedAccessException]::new('Pinned runtime path must not contain symlink or reparse-point components.')
    }

    if ($RuntimeMode -eq 'InstalledPath' -and $Plane -in @('Intune', 'ConfigMgr') -and
        ([string]::IsNullOrWhiteSpace($RuntimeExpectedHash) -or [string]::IsNullOrWhiteSpace($RuntimeExpectedVersion))) {
        throw [System.InvalidOperationException]::new('InstalledPath runtime mode requires expected runtime hash and version for production planes.')
    }

    $versionOutput = & $dscPath --version 2>&1 |
        Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($versionOutput)) {
        $dscVersion = ([string] $versionOutput).Trim()
        $runtimeInfo.version = $dscVersion
    }

    if ($RuntimeMode -eq 'InstalledPath') {
        if (-not [string]::IsNullOrWhiteSpace($RuntimeExpectedHash)) {
            $runtimeInfo.expectedHash = $RuntimeExpectedHash
            $runtimeInfo.observedHash = Get-ProStateKitSha256 -Path $dscPath
            if ($runtimeInfo.observedHash -ne $RuntimeExpectedHash) {
                throw [System.Security.SecurityException]::new('InstalledPath runtime hash mismatch.')
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($RuntimeExpectedVersion) -and $dscVersion -ne $RuntimeExpectedVersion) {
            throw [System.InvalidOperationException]::new('InstalledPath runtime version mismatch.')
        }
    }

    Test-ProStateKitManifestRuntime `
        -Manifest $bundleManifest `
        -CurrentRuntimeMode $RuntimeMode `
        -RuntimeInfo $runtimeInfo `
        -CurrentDscVersion $dscVersion `
        -CurrentBundleRoot $bundleRootFull

    $commands = @()
    if ($Mode -eq 'Detect') {
        $commands += , @('config', 'test', '--file', $configPathFull, '--output-format', 'json')
    } else {
        $commands += , @('config', 'set', '--file', $configPathFull, '--output-format', 'json')
        $commands += , @('config', 'test', '--file', $configPathFull, '--output-format', 'json')
    }

    $lastStdOut = ''
    $allStdErr = [System.Collections.Generic.List[string]]::new()
    $rawOutputByCommand = @{}
    $dscExitCode = 0

    foreach ($arguments in $commands) {
        $stdErrPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('prostatekit-dsc-{0}.err' -f ([guid]::NewGuid().ToString('N')))
        try {
            $lastStdOut = & $dscPath @arguments 2>$stdErrPath
            $dscExitCode = $LASTEXITCODE
            $rawOutputByCommand[$arguments[1]] = [string] $lastStdOut
            if (Test-Path -LiteralPath $stdErrPath -PathType Leaf) {
                [void] $allStdErr.Add((Get-Content -LiteralPath $stdErrPath -Raw))
            }
        } finally {
            if (Test-Path -LiteralPath $stdErrPath -PathType Leaf) {
                Remove-Item -LiteralPath $stdErrPath -Force
            }
        }

        if ($dscExitCode -ne 0) {
            break
        }
    }

    if ($dscExitCode -ne 0) {
        $resource = Get-ProStateKitResourceResult `
            -Name 'DSC invocation' `
            -Type 'ProStateKit/Runtime' `
            -ErrorMessage ('dsc exited with code {0}.' -f $dscExitCode)
        $result = Get-ProStateKitResult `
            -CurrentMode $Mode `
            -CurrentRunId $RunId `
            -StartedUtc $startedUtc `
            -DscVersion $dscVersion `
            -Succeeded $false `
            -Compliant $false `
            -Resources @($resource) `
            -ExitCode 2 `
            -ExitReason 'DscExitedNonZero' `
            -Errors @($resource.error)
        Write-ProStateKitEvidence `
            -RunRoot $runRoot `
            -Result $result `
            -Summary ('Runtime failure: dsc exited with code {0}.' -f $dscExitCode) `
            -RawContent ([string] $lastStdOut) `
            -RawFileName 'dsc.test.stdout.raw.json' `
            -StdErrContent ($allStdErr -join [Environment]::NewLine) `
            -BundleRoot $bundleRootFull `
            -RuntimePath $dscPath `
            -RuntimeInfo $runtimeInfo `
            -DscVersion $dscVersion `
            -DscExitCode $dscExitCode
        exit 2
    }

    try {
        $resources = ConvertFrom-ProStateKitDscOutput -JsonText ([string] $lastStdOut) -CurrentMode $Mode
    } catch {
        $resource = Get-ProStateKitResourceResult `
            -Name 'DSC output parser' `
            -Type 'ProStateKit/Internal' `
            -ErrorMessage $_.Exception.Message
        $result = Get-ProStateKitResult `
            -CurrentMode $Mode `
            -CurrentRunId $RunId `
            -StartedUtc $startedUtc `
            -DscVersion $dscVersion `
            -Succeeded $false `
            -Compliant $false `
            -Resources @($resource) `
            -ExitCode 3 `
            -ExitReason 'ParseFailure' `
            -Errors @($resource.error)
        Write-ProStateKitEvidence `
            -RunRoot $runRoot `
            -Result $result `
            -Summary 'Parse failure: DSC output could not prove state.' `
            -RawContent ([string] $lastStdOut) `
            -RawFileName 'dsc.raw.txt' `
            -StdErrContent ($allStdErr -join [Environment]::NewLine) `
            -BundleRoot $bundleRootFull `
            -RuntimePath $dscPath `
            -RuntimeInfo $runtimeInfo `
            -DscVersion $dscVersion `
            -DscExitCode $dscExitCode
        exit 3
    }

    $resourceArray = @($resources)
    $failedResources = @($resourceArray | Where-Object -FilterScript { -not $_.succeeded })
    $rebootResources = @($resourceArray | Where-Object -FilterScript { $_.rebootRequired })
    $allSucceeded = $failedResources.Count -eq 0
    $rebootRequired = $rebootResources.Count -gt 0
    $result = Get-ProStateKitResult `
        -CurrentMode $Mode `
        -CurrentRunId $RunId `
        -StartedUtc $startedUtc `
        -DscVersion $dscVersion `
        -Succeeded $allSucceeded `
        -Compliant $allSucceeded `
        -RebootRequired $rebootRequired `
        -Resources $resourceArray `
        -ExitCode ([int] (-not $allSucceeded)) `
        -ExitReason $(if ($allSucceeded) { 'VerifiedCompliant' } else { 'ProofNonCompliant' })

    $extraRawFiles = @{}
    if ($rawOutputByCommand.ContainsKey('set')) {
        $extraRawFiles['dsc.set.stdout.raw.json'] = $rawOutputByCommand['set']
    }

    if ($allSucceeded) {
        Write-ProStateKitEvidence `
            -RunRoot $runRoot `
            -Result $result `
            -Summary ('{0} verified compliant.' -f $Mode) `
            -RawContent ([string] $lastStdOut) `
            -RawFileName 'dsc.test.stdout.raw.json' `
            -ExtraRawFiles $extraRawFiles `
            -StdErrContent ($allStdErr -join [Environment]::NewLine) `
            -BundleRoot $bundleRootFull `
            -RuntimePath $dscPath `
            -RuntimeInfo $runtimeInfo `
            -DscVersion $dscVersion `
            -DscExitCode $dscExitCode
        exit 0
    }

    Write-ProStateKitEvidence `
        -RunRoot $runRoot `
        -Result $result `
        -Summary ('{0} did not prove compliance.' -f $Mode) `
        -RawContent ([string] $lastStdOut) `
        -RawFileName 'dsc.test.stdout.raw.json' `
        -ExtraRawFiles $extraRawFiles `
        -StdErrContent ($allStdErr -join [Environment]::NewLine) `
        -BundleRoot $bundleRootFull `
        -RuntimePath $dscPath `
        -RuntimeInfo $runtimeInfo `
        -DscVersion $dscVersion `
        -DscExitCode $dscExitCode
    exit 1
} catch {
    $resource = Get-ProStateKitResourceResult `
        -Name 'ProStateKit wrapper' `
        -Type 'ProStateKit/Internal' `
        -ErrorMessage $_.Exception.Message
    $result = Get-ProStateKitResult `
        -CurrentMode $Mode `
        -CurrentRunId $RunId `
        -StartedUtc $startedUtc `
        -Succeeded $false `
        -Compliant $false `
        -Resources @($resource) `
        -ExitCode 2 `
        -ExitReason 'WrapperException' `
        -Errors @($resource.error)
    Write-ProStateKitEvidence `
        -RunRoot $runRoot `
        -Result $result `
        -Summary ('Runtime failure: {0}' -f $_.Exception.Message) `
        -StdErrContent $_.ScriptStackTrace `
        -BundleRoot $bundleRootFull `
        -RuntimePath $dscPath `
        -RuntimeInfo $runtimeInfo `
        -DscVersion $dscVersion `
        -DscExitCode -1
    exit 2
}
