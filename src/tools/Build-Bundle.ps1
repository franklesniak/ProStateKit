[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),

    [string] $OutputPath = (Join-Path -Path (Get-Location).Path -ChildPath 'dist'),

    [string] $Version = '0.1.0'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath 'ProStateKit.Common.psm1') -Force

$repositoryRootFull = [System.IO.Path]::GetFullPath($RepositoryRoot)
$outputPathFull = [System.IO.Path]::GetFullPath($OutputPath)
$bundleName = 'ProStateKit-{0}' -f $Version
$stagingRoot = Join-Path -Path $outputPathFull -ChildPath $bundleName
$zipPath = Join-Path -Path $outputPathFull -ChildPath ('{0}.zip' -f $bundleName)
$checksumPath = '{0}.sha256' -f $zipPath
$releaseManifestPath = Join-Path -Path $outputPathFull -ChildPath 'bundle.manifest.json'

Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $checksumPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $releaseManifestPath -Force -ErrorAction SilentlyContinue

$dscExeName = 'dsc'
if (Test-ProStateKitWindows) {
    $dscExeName = 'dsc.exe'
}
$runtimeSourceRoot = Join-Path -Path $repositoryRootFull -ChildPath 'runtime/dsc'
$runtimePath = Join-Path -Path $runtimeSourceRoot -ChildPath $dscExeName
if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('TODO: place the reviewed pinned DSC runtime under runtime/dsc before building a release bundle.', $runtimePath)
}

$dscVersion = 'TBD'
$versionOutput = & $runtimePath --version 2>&1 |
    Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($versionOutput)) {
    $dscVersion = ([string] $versionOutput).Trim()
}

[void] (New-Item -Path $stagingRoot -ItemType Directory -Force)

$relativePaths = @(
    '.github/linting/PSScriptAnalyzerSettings.psd1',
    '.github/scripts/lint-markdown-links.js',
    '.github/scripts/lint-nested-markdown.js',
    '.markdownlint.jsonc',
    '.pre-commit-config.yaml',
    '.yamllint.yml',
    'README.md',
    'LICENSE',
    'SECURITY.md',
    'bundle.manifest.template.json',
    'configs/baseline.dsc.yaml',
    'configs/generated/baseline.dsc.json',
    'evidence/sample/compliant-detect/dsc.raw.json',
    'evidence/sample/compliant-detect/summary.txt',
    'evidence/sample/compliant-detect/wrapper.result.json',
    'evidence/sample/noncompliant-detect/dsc.raw.json',
    'evidence/sample/noncompliant-detect/summary.txt',
    'evidence/sample/noncompliant-detect/wrapper.result.json',
    'evidence/sample/parse-failure/dsc.raw.txt',
    'evidence/sample/parse-failure/summary.txt',
    'evidence/sample/parse-failure/wrapper.result.json',
    'evidence/sample/partial-failure/dsc.raw.json',
    'evidence/sample/partial-failure/summary.txt',
    'evidence/sample/partial-failure/wrapper.result.json',
    'evidence/sample/successful-remediate/dsc.raw.json',
    'evidence/sample/successful-remediate/summary.txt',
    'evidence/sample/successful-remediate/wrapper.result.json',
    'docs/architecture.md',
    'docs/completion-audit.md',
    'docs/configmgr.md',
    'docs/contract.md',
    'docs/evidence-schema.md',
    'docs/execution-contract.md',
    'docs/exit-codes.md',
    'docs/intune.md',
    'docs/packaging.md',
    'docs/reboots.md',
    'docs/resource-gaps.md',
    'docs/runbooks/demo-runbook.md',
    'docs/runbooks/reset-lab.md',
    'docs/runtime-distribution.md',
    'docs/secrets.md',
    'docs/troubleshooting.md',
    'planes/configmgr/Discover-ProStateKit.ps1',
    'planes/configmgr/Remediate-ProStateKit.ps1',
    'planes/intune/Detect-ProStateKit.ps1',
    'planes/intune/Remediate-ProStateKit.ps1',
    'planes/local/Invoke-LocalPreflight.ps1',
    'package-lock.json',
    'package.json',
    'resources/README.md',
    'runtime/dsc/README.md',
    'schemas/bundle-manifest.schema.json',
    'schemas/examples/bundle-manifest.invalid.json',
    'schemas/examples/bundle-manifest.invalid.md',
    'schemas/examples/bundle-manifest.valid.json',
    'schemas/examples/release-readiness.invalid.json',
    'schemas/examples/release-readiness.invalid.md',
    'schemas/examples/release-readiness.valid.json',
    'schemas/examples/wrapper-result.invalid.json',
    'schemas/examples/wrapper-result.invalid.md',
    'schemas/examples/wrapper-result.valid.json',
    'schemas/release-readiness.schema.json',
    'schemas/wrapper-result.schema.json',
    'src/Invoke-ProStateKit.ps1',
    'src/ProStateKit.Common.psm1',
    'src/ProStateKit.Dsc.psm1',
    'src/ProStateKit.Evidence.psm1',
    'src/ProStateKit.Redaction.psm1',
    'src/ProStateKit.Runtime.psm1',
    'src/runner/Runner.ps1',
    'src/runner/Intune/Detect.ps1',
    'src/runner/Intune/Remediate.ps1',
    'src/runner/ConfigMgr/Runner.ps1',
    'src/tools/Build-Bundle.ps1',
    'src/tools/Convert-ConfigYamlToJson.ps1',
    'src/tools/Invoke-PSScriptAnalyzer.ps1',
    'src/tools/Invoke-PreReqChecks.ps1',
    'src/tools/Invoke-SchemaLint.ps1',
    'src/tools/New-DemoDrift.ps1',
    'src/tools/New-Package.ps1',
    'src/tools/Reset-DemoDrift.ps1',
    'src/tools/SecretHelper.ps1',
    'src/tools/Test-Bundle.ps1',
    'src/tools/Test-ReleaseReadiness.ps1',
    'tests/PowerShell/ProStateKit.Tests.ps1',
    'tests/fixtures/dsc-3.2.0/config-set.result-wrapper.json',
    'tests/fixtures/dsc-3.2.0/config-set.success.json',
    'tests/fixtures/dsc-3.2.0/config-test.actual-state.json',
    'tests/fixtures/dsc-3.2.0/config-test.compliant.json',
    'tests/fixtures/dsc-3.2.0/config-test.noncompliant.json',
    'tests/fixtures/dsc-3.2.0/config-test.results-wrapper.json',
    'tests/fixtures/dsc-3.2.0/config-test.single-resource.json',
    'tools/Build-Bundle.ps1',
    'tools/Convert-ConfigYamlToJson.ps1',
    'tools/New-DemoDrift.ps1',
    'tools/New-Package.ps1',
    'tools/Reset-DemoDrift.ps1',
    'tools/Test-Bundle.ps1',
    'tools/Test-ReleaseReadiness.ps1',
    'tools/Invoke-Validation.ps1'
)

foreach ($relativePath in $relativePaths) {
    $sourcePath = Join-Path -Path $repositoryRootFull -ChildPath $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(('Required bundle file was not found: {0}' -f $sourcePath), $sourcePath)
    }

    $destinationPath = Join-Path -Path $stagingRoot -ChildPath $relativePath
    [void] (New-Item -Path (Split-Path -Path $destinationPath -Parent) -ItemType Directory -Force)
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

$runtimeDestinationRoot = Join-Path -Path $stagingRoot -ChildPath 'runtime/dsc'
[void] (New-Item -Path $runtimeDestinationRoot -ItemType Directory -Force)
foreach ($runtimeFile in Get-ChildItem -LiteralPath $runtimeSourceRoot -File -Recurse -Force) {
    $relativeRuntimePath = [System.IO.Path]::GetRelativePath($runtimeSourceRoot, $runtimeFile.FullName)
    $runtimeDestinationPath = Join-Path -Path $runtimeDestinationRoot -ChildPath $relativeRuntimePath
    [void] (New-Item -Path (Split-Path -Path $runtimeDestinationPath -Parent) -ItemType Directory -Force)
    Copy-Item -LiteralPath $runtimeFile.FullName -Destination $runtimeDestinationPath -Force
}
$runtimeDestination = Join-Path -Path $runtimeDestinationRoot -ChildPath $dscExeName

$manifestFiles = foreach ($file in Get-ChildItem -LiteralPath $stagingRoot -File -Recurse -Force) {
    $relativePath = [System.IO.Path]::GetRelativePath($stagingRoot, $file.FullName).Replace('\', '/')
    [pscustomobject]@{
        path = $relativePath
        sha256 = Get-ProStateKitSha256 -Path $file.FullName
    }
}

$sourceCommit = 'unknown'
$gitCommit = & git -C $repositoryRootFull rev-parse HEAD 2>$null
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitCommit)) {
    $sourceCommit = ([string] $gitCommit).Trim()
}

$manifest = [pscustomobject]@{
    name = 'ProStateKit'
    version = $Version
    schemaVersion = '1.0.0'
    dscVersion = $dscVersion
    builtAt = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
    sourceCommit = $sourceCommit
    wrapperHash = Get-ProStateKitSha256 -Path (Join-Path -Path $stagingRoot -ChildPath 'src/runner/Runner.ps1')
    configHash = Get-ProStateKitSha256 -Path (Join-Path -Path $stagingRoot -ChildPath 'configs/baseline.dsc.yaml')
    runtime = [pscustomobject]@{
        path = 'runtime/dsc/{0}' -f $dscExeName
        expectedHash = Get-ProStateKitSha256 -Path $runtimeDestination
    }
    files = @($manifestFiles)
    validationStatus = 'built'
    supportedPlanes = @('Local', 'Intune', 'ConfigMgr', 'CI')
}

$manifestPath = Join-Path -Path $stagingRoot -ChildPath 'bundle.manifest.json'
Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 20) -Encoding utf8
Copy-Item -LiteralPath $manifestPath -Destination $releaseManifestPath -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipArchive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $stagingRoot -File -Recurse -Force) {
        $entryName = [System.IO.Path]::GetRelativePath($stagingRoot, $file.FullName).Replace('\', '/')
        $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zipArchive,
            $file.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        )
    }
} finally {
    $zipArchive.Dispose()
}
Set-Content -LiteralPath $checksumPath -Value (Get-ProStateKitSha256 -Path $zipPath) -Encoding utf8

Write-Output $zipPath
