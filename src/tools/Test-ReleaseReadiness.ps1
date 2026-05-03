[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),

    [string] $ReleaseOutputPath,

    [string] $LabEvidenceRoot,

    [string] $IntuneEvidencePath,

    [string] $ConfigMgrEvidencePath,

    [ValidateSet('Text', 'Json')]
    [string] $OutputFormat = 'Text'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-ProStateKitReadinessCheck {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [bool] $Passed,

        [Parameter(Mandatory)]
        [string] $Evidence,

        [Parameter(Mandatory)]
        [string] $Detail
    )

    return [pscustomobject]@{
        name = $Name
        passed = $Passed
        evidence = $Evidence
        detail = $Detail
    }
}

function Test-ProStateKitEvidenceFile {
    param(
        [string] $Path,

        [string[]] $Include = @('*')
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    $files = @(
        Get-ChildItem -LiteralPath $Path -File -Recurse -Include $Include -ErrorAction SilentlyContinue
    )
    return $files.Count -gt 0
}

$repositoryRootFull = [System.IO.Path]::GetFullPath($RepositoryRoot)
$checks = [System.Collections.Generic.List[object]]::new()

$runtimeRoot = Join-Path -Path $repositoryRootFull -ChildPath 'runtime/dsc'
$runtimeExe = Join-Path -Path $runtimeRoot -ChildPath 'dsc.exe'
$runtimeFiles = @()
if (Test-Path -LiteralPath $runtimeRoot -PathType Container) {
    $runtimeFiles = @(Get-ChildItem -LiteralPath $runtimeRoot -File -Recurse -ErrorAction SilentlyContinue)
}
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'reviewed-pinned-runtime' `
            -Passed ((Test-Path -LiteralPath $runtimeExe -PathType Leaf) -and $runtimeFiles.Count -gt 1) `
            -Evidence 'runtime/dsc/dsc.exe plus reviewed archive payload' `
            -Detail 'NEXT-001 requires the reviewed Windows DSC archive payload under runtime/dsc/, not only source notes.'))

$nextStepsPath = Join-Path -Path $repositoryRootFull -ChildPath 'DSCv3-14a-next-steps.md'
$nextSteps = ''
if (Test-Path -LiteralPath $nextStepsPath -PathType Leaf) {
    $nextSteps = Get-Content -LiteralPath $nextStepsPath -Raw
}
$openReviewerItems = @($nextSteps -split "`n" | Where-Object -FilterScript { $_ -match '^- \[ \]' })
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'runtime-reviewer-signoff' `
            -Passed ($openReviewerItems.Count -eq 0 -and $nextSteps -notmatch 'does not close NEXT-001') `
            -Evidence 'DSCv3-14a-next-steps.md NEXT-001 reviewer checklist' `
            -Detail 'NEXT-001 remains open while reviewer sign-off checklist items are unchecked or candidate-only language remains.'))

$releaseReady = $false
$releaseDetail = 'ReleaseOutputPath was not provided; dry release evidence is missing.'
if (-not [string]::IsNullOrWhiteSpace($ReleaseOutputPath)) {
    $releaseOutputFull = [System.IO.Path]::GetFullPath($ReleaseOutputPath)
    $zipFiles = @()
    $checksumFiles = @()
    $stagedBundles = @()
    $manifestPath = Join-Path -Path $releaseOutputFull -ChildPath 'bundle.manifest.json'
    if (Test-Path -LiteralPath $releaseOutputFull -PathType Container) {
        $zipFiles = @(Get-ChildItem -LiteralPath $releaseOutputFull -File -Filter '*.zip' -ErrorAction SilentlyContinue)
        $checksumFiles = @(Get-ChildItem -LiteralPath $releaseOutputFull -File -Filter '*.sha256' -ErrorAction SilentlyContinue)
        $stagedBundles = @(
            Get-ChildItem -LiteralPath $releaseOutputFull -Directory -Filter 'ProStateKit-*' -ErrorAction SilentlyContinue |
                Where-Object -FilterScript {
                    $candidateManifestPath = Join-Path -Path $_.FullName -ChildPath 'bundle.manifest.json'
                    $candidateVerifierPath = Join-Path -Path $_.FullName -ChildPath 'src/tools/Test-Bundle.ps1'
                    (Test-Path -LiteralPath $candidateManifestPath -PathType Leaf) -and
                    (Test-Path -LiteralPath $candidateVerifierPath -PathType Leaf)
                }
        )
    }
    $hasReleaseZip = $zipFiles.Count -gt 0
    $hasReleaseChecksum = $checksumFiles.Count -gt 0
    $hasReleaseManifest = Test-Path -LiteralPath $manifestPath -PathType Leaf
    $hasVerifiedStagedBundle = $false
    $stagedBundleDetail = 'No staged ProStateKit-* bundle with src/tools/Test-Bundle.ps1 was found.'
    if ($stagedBundles.Count -gt 0) {
        $stagedBundleRoot = $stagedBundles[0].FullName
        $stagedVerifierPath = Join-Path -Path $stagedBundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
        $currentPowerShellPath = (Get-Process -Id $PID).Path
        $stagedVerifierErrorPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('prostatekit-readiness-{0}.err' -f ([guid]::NewGuid().ToString('N')))
        try {
            & $currentPowerShellPath -NoProfile -File $stagedVerifierPath -BundleRoot $stagedBundleRoot 2>$stagedVerifierErrorPath | Out-Null
            $hasVerifiedStagedBundle = $LASTEXITCODE -eq 0
            if (-not $hasVerifiedStagedBundle) {
                $stagedVerifierError = ''
                if (Test-Path -LiteralPath $stagedVerifierErrorPath -PathType Leaf) {
                    $stagedVerifierError = (Get-Content -LiteralPath $stagedVerifierErrorPath -Raw).Trim()
                }
                if ([string]::IsNullOrWhiteSpace($stagedVerifierError)) {
                    $stagedBundleDetail = 'Staged bundle verifier returned a non-zero exit code.'
                } else {
                    $stagedBundleDetail = 'Staged bundle verifier returned a non-zero exit code: {0}' -f $stagedVerifierError
                }
            }
        } catch {
            $stagedBundleDetail = 'Staged bundle verifier failed: {0}' -f $_.Exception.Message
        } finally {
            Remove-Item -LiteralPath $stagedVerifierErrorPath -Force -ErrorAction SilentlyContinue
        }
    }
    $releaseReady = $hasReleaseZip -and $hasReleaseChecksum -and $hasReleaseManifest -and $hasVerifiedStagedBundle
    if ($releaseReady) {
        $releaseDetail = 'Dry release output includes a ZIP, root bundle.manifest.json, .sha256 file, and a staged bundle verified by src/tools/Test-Bundle.ps1.'
    } else {
        $releaseDetail = 'Dry release output must include a ZIP, root bundle.manifest.json, .sha256 file, and a staged bundle verified by src/tools/Test-Bundle.ps1. {0}' -f $stagedBundleDetail
    }
}
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'dry-release-artifacts' `
            -Passed $releaseReady `
            -Evidence 'tools/New-Package.ps1 disposable output directory' `
            -Detail $releaseDetail))

$labReady = $false
$labDetail = 'LabEvidenceRoot was not provided; two clean local rehearsal evidence directories are missing.'
if (-not [string]::IsNullOrWhiteSpace($LabEvidenceRoot) -and (Test-Path -LiteralPath $LabEvidenceRoot -PathType Container)) {
    $labRuns = @(
        Get-ChildItem -LiteralPath $LabEvidenceRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object -FilterScript { Test-ProStateKitEvidenceFile -Path $_.FullName -Include @('wrapper.result.json', 'preflight.report.json') }
    )
    $labReady = $labRuns.Count -ge 2
    $labDetail = 'LabEvidenceRoot must contain at least two rehearsal directories with wrapper or preflight evidence.'
}
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'local-demo-rehearsals' `
            -Passed $labReady `
            -Evidence 'two timestamped local rehearsal evidence directories' `
            -Detail $labDetail))

$intuneReady = Test-ProStateKitEvidenceFile -Path $IntuneEvidencePath -Include @('*.png', '*.json', '*.txt')
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'intune-lab-validation' `
            -Passed $intuneReady `
            -Evidence 'sanitized Intune portal screenshots and detection/remediation evidence' `
            -Detail 'IntuneEvidencePath must contain sanitized screenshots or evidence files from final pinned bundle validation.'))

$configMgrReady = Test-ProStateKitEvidenceFile -Path $ConfigMgrEvidencePath -Include @('*.png', '*.json', '*.txt')
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'configmgr-lab-validation' `
            -Passed $configMgrReady `
            -Evidence 'sanitized ConfigMgr console screenshots and compliance evidence' `
            -Detail 'ConfigMgrEvidencePath must contain sanitized screenshots or evidence files from final pinned bundle validation.'))

$todoPath = Join-Path -Path $repositoryRootFull -ChildPath '_TODO.md'
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'public-flip-tasks' `
            -Passed (-not (Test-Path -LiteralPath $todoPath -PathType Leaf)) `
            -Evidence '_TODO.md removed after public-flip tasks are completed' `
            -Detail 'Private-staging _TODO.md still exists, so public flip tasks are not complete.'))

$deckPath = Join-Path -Path $repositoryRootFull -ChildPath 'DSCv3-14-deck-spec.md'
$deckReconciled = $false
if (Test-Path -LiteralPath $deckPath -PathType Leaf) {
    $deck = Get-Content -LiteralPath $deckPath -Raw
    $deckReconciled = $deck -notmatch '\[(REPO|LAB|REHEARSAL)\]'
}
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'deck-reconciled-to-real-evidence' `
            -Passed $deckReconciled `
            -Evidence 'DSCv3-14-deck-spec.md contains no REPO/LAB/REHEARSAL placeholders' `
            -Detail 'Deck placeholders must be replaced with actual commands, evidence, screenshots, and timings.'))

$finalRecheckComplete = $nextSteps -notmatch '\| NEXT-009 \|'
[void] $checks.Add((Get-ProStateKitReadinessCheck `
            -Name 'final-dsc-release-recheck' `
            -Passed $finalRecheckComplete `
            -Evidence 'NEXT-009 closed or moved out of blocking actions' `
            -Detail 'The latest stable DSC release must be rechecked one week before deck freeze.'))

$failedChecks = @($checks | Where-Object -FilterScript { -not $_.passed })
$result = [pscustomobject]@{
    schemaVersion = '1.0.0'
    generatedAt = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
    repositoryRoot = $repositoryRootFull
    ready = $failedChecks.Count -eq 0
    checks = @($checks)
}

if ($OutputFormat -eq 'Json') {
    $result | ConvertTo-Json -Depth 10
} else {
    if ($result.ready) {
        Write-Output 'ProStateKit release readiness: ready.'
    } else {
        Write-Output 'ProStateKit release readiness: blocked.'
    }

    foreach ($check in $checks) {
        $status = 'PASS'
        if (-not $check.passed) {
            $status = 'FAIL'
        }
        Write-Output ('[{0}] {1}: {2}' -f $status, $check.name, $check.detail)
    }
}

if ($result.ready) {
    exit 0
}

exit 1
