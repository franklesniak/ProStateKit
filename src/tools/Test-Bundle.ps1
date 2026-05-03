[CmdletBinding()]
param(
    [string] $BundleRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),

    [string] $ManifestPath = (Join-Path -Path $BundleRoot -ChildPath 'bundle.manifest.json')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath 'ProStateKit.Common.psm1') -Force

function Resolve-ProStateKitBundlePath {
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath,

        [Parameter(Mandatory)]
        [string] $CurrentBundleRoot
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw [System.UnauthorizedAccessException]::new('Bundle paths must be relative: {0}' -f $RelativePath)
    }

    $resolvedPath = Get-ProStateKitFullPath -PathValue $RelativePath -BasePath $CurrentBundleRoot
    if (-not (Test-ProStateKitPathInRoot -CandidatePath $resolvedPath -RootPath $CurrentBundleRoot)) {
        throw [System.UnauthorizedAccessException]::new('Bundle path escaped BundleRoot: {0}' -f $RelativePath)
    }

    if (Test-ProStateKitPathHasLink -CandidatePath $resolvedPath -RootPath $CurrentBundleRoot) {
        throw [System.UnauthorizedAccessException]::new('Bundle path must not contain symlink or reparse-point components: {0}' -f $RelativePath)
    }

    return $resolvedPath
}

function Test-ProStateKitJsonDocument {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $null = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
}

function Test-ProStateKitYamlDocument {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Get-Command -Name 'node' -CommandType Application -ErrorAction SilentlyContinue)) {
        throw [System.InvalidOperationException]::new('Node.js is required to parse YAML during bundle validation.')
    }

    $nodeScript = @'
const fs = require('fs');
const yaml = require('js-yaml');
const path = process.argv[1];
yaml.load(fs.readFileSync(path, 'utf8'), { filename: path });
'@
    & node -e $nodeScript $Path
    if ($LASTEXITCODE -ne 0) {
        throw [System.FormatException]::new('YAML parse failed: {0}' -f $Path)
    }
}

$bundleRootFull = Get-ProStateKitFullPath -PathValue $BundleRoot -BasePath (Get-Location).Path
$manifestPathFull = Get-ProStateKitFullPath -PathValue $ManifestPath -BasePath $bundleRootFull
$manifestPathRelative = [System.IO.Path]::GetRelativePath($bundleRootFull, $manifestPathFull)
if ($manifestPathRelative.StartsWith('..') -or [System.IO.Path]::IsPathRooted($manifestPathRelative)) {
    throw [System.UnauthorizedAccessException]::new('ManifestPath must resolve inside BundleRoot.')
}
if (Test-ProStateKitPathHasLink -CandidatePath $manifestPathFull -RootPath $bundleRootFull) {
    throw [System.UnauthorizedAccessException]::new('ManifestPath must not contain symlink or reparse-point components.')
}
$schemaPath = Join-Path -Path $bundleRootFull -ChildPath 'schemas/bundle-manifest.schema.json'

if (-not (Test-Path -LiteralPath $manifestPathFull -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('bundle.manifest.json was not found.', $manifestPathFull)
}

if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('Bundle manifest schema was not found.', $schemaPath)
}

$manifestJson = Get-Content -LiteralPath $manifestPathFull -Raw
$schemaJson = Get-Content -LiteralPath $schemaPath -Raw
if (-not (Test-Json -Json $manifestJson -Schema $schemaJson)) {
    throw [System.FormatException]::new('Bundle manifest failed schema validation.')
}

$manifest = $manifestJson | ConvertFrom-Json -ErrorAction Stop

if ($null -eq $manifest.runtime -or [string]::IsNullOrWhiteSpace($manifest.runtime.path)) {
    throw [System.FormatException]::new('Bundle manifest must include runtime.path.')
}

$runtimePath = Resolve-ProStateKitBundlePath -RelativePath $manifest.runtime.path -CurrentBundleRoot $bundleRootFull
if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('Manifest runtime path was not found.', $runtimePath)
}

$runtimeHash = Get-ProStateKitSha256 -Path $runtimePath
if ($manifest.runtime.expectedHash -ne 'TBD' -and $runtimeHash -ne $manifest.runtime.expectedHash) {
    throw [System.Security.SecurityException]::new('Runtime hash mismatch.')
}

if ($manifest.dscVersion -ne 'TBD') {
    $versionOutput = & $runtimePath --version 2>&1 |
        Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new('Runtime version check failed.')
    }

    $observedVersion = ([string] $versionOutput).Trim()
    if ($observedVersion -ne $manifest.dscVersion) {
        throw [System.InvalidOperationException]::new('Runtime version mismatch.')
    }
}

$requiredFiles = @(
    '.github/linting/PSScriptAnalyzerSettings.psd1',
    '.github/scripts/lint-markdown-links.js',
    '.github/scripts/lint-nested-markdown.js',
    '.markdownlint.jsonc',
    '.pre-commit-config.yaml',
    '.yamllint.yml',
    'README.md',
    'LICENSE',
    'SECURITY.md',
    'bundle.manifest.json',
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

foreach ($requiredFile in $requiredFiles) {
    $requiredPath = Resolve-ProStateKitBundlePath -RelativePath $requiredFile -CurrentBundleRoot $bundleRootFull
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new('Required bundle file was not found.', $requiredPath)
    }
}

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

foreach ($requiredFile in @($requiredFiles | Where-Object -FilterScript { $_ -ne 'bundle.manifest.json' })) {
    if ($manifestFilePaths -notcontains $requiredFile) {
        throw [System.Security.SecurityException]::new('Required bundle file is not covered by manifest hashes: {0}' -f $requiredFile)
    }
}

foreach ($bundleFile in Get-ChildItem -LiteralPath $bundleRootFull -File -Recurse -Force) {
    $relativeBundleFile = [System.IO.Path]::GetRelativePath($bundleRootFull, $bundleFile.FullName).Replace('\', '/')
    if ($relativeBundleFile -eq 'bundle.manifest.json') {
        continue
    }

    if ($manifestFilePaths -notcontains $relativeBundleFile) {
        throw [System.Security.SecurityException]::new('Bundle file is not covered by manifest hashes: {0}' -f $relativeBundleFile)
    }
}

$baselineYamlPath = Resolve-ProStateKitBundlePath -RelativePath 'configs/baseline.dsc.yaml' -CurrentBundleRoot $bundleRootFull
$baselineJsonPath = Resolve-ProStateKitBundlePath -RelativePath 'configs/generated/baseline.dsc.json' -CurrentBundleRoot $bundleRootFull
Test-ProStateKitYamlDocument -Path $baselineYamlPath
Test-ProStateKitJsonDocument -Path $baselineJsonPath

$observedWrapperHash = Get-ProStateKitSha256 -Path (Resolve-ProStateKitBundlePath -RelativePath 'src/runner/Runner.ps1' -CurrentBundleRoot $bundleRootFull)
if ($manifest.wrapperHash -ne 'TBD' -and $observedWrapperHash -ne $manifest.wrapperHash) {
    throw [System.Security.SecurityException]::new('Wrapper hash mismatch.')
}

$observedConfigHash = Get-ProStateKitSha256 -Path $baselineYamlPath
if ($manifest.configHash -ne 'TBD' -and $observedConfigHash -ne $manifest.configHash) {
    throw [System.Security.SecurityException]::new('Config hash mismatch.')
}

foreach ($fileEntry in @($manifest.files)) {
    $filePath = Resolve-ProStateKitBundlePath -RelativePath $fileEntry.path -CurrentBundleRoot $bundleRootFull
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new('Manifest file entry was not found.', $filePath)
    }

    $observedHash = Get-ProStateKitSha256 -Path $filePath
    if ($observedHash -ne $fileEntry.sha256) {
        throw [System.Security.SecurityException]::new('Manifest hash mismatch for {0}.' -f $fileEntry.path)
    }
}

Write-Output 'Bundle validation completed successfully.'
