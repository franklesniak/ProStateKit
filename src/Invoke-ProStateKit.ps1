[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Detect', 'Remediate', 'ValidateBundle', 'Preflight')]
    [string] $Mode,

    [ValidateSet('Local', 'Intune', 'ConfigMgr', 'CI')]
    [string] $Plane = 'Local',

    [string] $ConfigPath = 'configs/baseline.dsc.yaml',

    [ValidateSet('PinnedBundle', 'InstalledPath', 'LabLatest')]
    [string] $RuntimeMode = 'PinnedBundle',

    [string] $RuntimePath,

    [string] $RuntimeExpectedHash,

    [string] $RuntimeExpectedVersion,

    [string] $EvidenceRoot = 'C:\ProgramData\ProStateKit\Evidence',

    [string] $OperationId,

    [string] $DemoMarkerPath = '',

    [switch] $AllowLabLatest,

    [string] $BundleRoot = (Split-Path -Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Exit-ProStateKitPlaneCode {
    param(
        [Parameter(Mandatory)]
        [int] $RunnerExitCode,

        [Parameter(Mandatory)]
        [string] $CurrentPlane,

        [Parameter(Mandatory)]
        [string] $CurrentMode
    )

    if ($RunnerExitCode -eq 0) {
        if ($CurrentPlane -eq 'Intune') {
            Write-Output ('ProStateKit {0}: verified success. Full evidence is on disk.' -f $CurrentMode)
        } elseif ($CurrentPlane -eq 'ConfigMgr') {
            Write-Output 'Compliant'
        }
        exit 0
    }

    if ($CurrentPlane -eq 'ConfigMgr') {
        Write-Output 'NonCompliant'
    } elseif ($CurrentPlane -eq 'Intune') {
        Write-Output ('ProStateKit {0}: noncompliant or failed closed. Full evidence is on disk.' -f $CurrentMode)
    }

    exit 1
}

function Write-ProStateKitPreflightReport {
    param(
        [Parameter(Mandatory)]
        [string] $ReportRoot,

        [Parameter(Mandatory)]
        [string] $CurrentOperationId,

        [Parameter(Mandatory)]
        [object[]] $Steps,

        [Parameter(Mandatory)]
        [bool] $Succeeded
    )

    [void] (New-Item -Path $ReportRoot -ItemType Directory -Force)
    $report = [pscustomobject]@{
        schemaVersion = '1.0.0'
        operationId = $CurrentOperationId
        startedAt = $script:preflightStartedAt.ToString('yyyy-MM-ddTHH:mm:ssZ')
        endedAt = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
        succeeded = $Succeeded
        steps = @($Steps)
    }
    Set-Content -LiteralPath (Join-Path -Path $ReportRoot -ChildPath 'preflight.report.json') -Value ($report | ConvertTo-Json -Depth 20) -Encoding utf8
    $summary = 'Preflight failed closed. Review preflight.report.json.'
    if ($Succeeded) {
        $summary = 'Preflight completed successfully.'
    }
    Set-Content -LiteralPath (Join-Path -Path $ReportRoot -ChildPath 'summary.txt') -Value $summary -Encoding utf8
}

$bundleRootFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BundleRoot)
$configPathFull = $ConfigPath
if (-not [System.IO.Path]::IsPathRooted($configPathFull)) {
    $configPathFull = Join-Path -Path $bundleRootFull -ChildPath $ConfigPath
}
$configPathFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($configPathFull)

if ([string]::IsNullOrWhiteSpace($OperationId)) {
    $nowUtc = [datetime]::UtcNow
    $OperationId = '{0}-{1}' -f $nowUtc.ToString('yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
}

if ($RuntimeMode -eq 'LabLatest' -and -not $AllowLabLatest.IsPresent) {
    throw [System.InvalidOperationException]::new('LabLatest runtime mode requires -AllowLabLatest.')
}

if ($RuntimeMode -eq 'LabLatest' -and $Plane -in @('Intune', 'ConfigMgr')) {
    throw [System.InvalidOperationException]::new('LabLatest runtime mode is blocked for production plane shims.')
}

if ($RuntimeMode -eq 'InstalledPath' -and $Plane -in @('Intune', 'ConfigMgr') -and
    ([string]::IsNullOrWhiteSpace($RuntimeExpectedHash) -or [string]::IsNullOrWhiteSpace($RuntimeExpectedVersion))) {
    throw [System.InvalidOperationException]::new('InstalledPath runtime mode requires -RuntimeExpectedHash and -RuntimeExpectedVersion for production planes.')
}

if ($Mode -eq 'ValidateBundle') {
    $testBundlePath = Join-Path -Path $bundleRootFull -ChildPath 'src/tools/Test-Bundle.ps1'
    & $testBundlePath -BundleRoot $bundleRootFull
    exit $LASTEXITCODE
}

if ($Mode -eq 'Preflight') {
    $script:preflightStartedAt = [datetime]::UtcNow
    $preflightRoot = Join-Path -Path $EvidenceRoot -ChildPath (Join-Path -Path 'Preflight' -ChildPath $OperationId)
    $steps = [System.Collections.Generic.List[object]]::new()

    $testBundlePath = Join-Path -Path $bundleRootFull -ChildPath 'src/tools/Test-Bundle.ps1'
    try {
        & $testBundlePath -BundleRoot $bundleRootFull
        if ($LASTEXITCODE -ne 0) {
            throw [System.InvalidOperationException]::new('ValidateBundle returned a non-zero exit code.')
        }
        $step = [pscustomobject]@{
            name = 'ValidateBundle'
            succeeded = $true
            exitCode = 0
            message = 'Bundle manifest and hashes validated.'
        }
        [void] $steps.Add($step)
    } catch {
        $step = [pscustomobject]@{
            name = 'ValidateBundle'
            succeeded = $false
            exitCode = 1
            message = $_.Exception.Message
        }
        [void] $steps.Add($step)
        Write-ProStateKitPreflightReport -ReportRoot $preflightRoot -CurrentOperationId $OperationId -Steps $steps -Succeeded $false
        exit 1
    }

    $preReqPath = Join-Path -Path $bundleRootFull -ChildPath 'src/tools/Invoke-PreReqChecks.ps1'
    try {
        & $preReqPath `
            -BundleRoot $bundleRootFull `
            -ConfigPath $configPathFull `
            -LogRoot $EvidenceRoot `
            -RuntimeMode $RuntimeMode `
            -RuntimePath $RuntimePath `
            -RuntimeExpectedHash $RuntimeExpectedHash `
            -RuntimeExpectedVersion $RuntimeExpectedVersion `
            -AllowLabLatest:$AllowLabLatest.IsPresent
        if ($LASTEXITCODE -ne 0) {
            throw [System.InvalidOperationException]::new('Prerequisite checks returned a non-zero exit code.')
        }
        $step = [pscustomobject]@{
            name = 'Prerequisites'
            succeeded = $true
            exitCode = 0
            message = 'Prerequisite checks completed.'
        }
        [void] $steps.Add($step)
    } catch {
        $step = [pscustomobject]@{
            name = 'Prerequisites'
            succeeded = $false
            exitCode = 1
            message = $_.Exception.Message
        }
        [void] $steps.Add($step)
        Write-ProStateKitPreflightReport -ReportRoot $preflightRoot -CurrentOperationId $OperationId -Steps $steps -Succeeded $false
        exit 1
    }

    $runnerPath = Join-Path -Path $bundleRootFull -ChildPath 'src/runner/Runner.ps1'
    $runnerSteps = @(
        [pscustomobject]@{ Name = 'DetectKnownGood'; Mode = 'Detect' },
        [pscustomobject]@{ Name = 'DetectAfterDrift'; Mode = 'Detect' },
        [pscustomobject]@{ Name = 'Remediate'; Mode = 'Remediate' },
        [pscustomobject]@{ Name = 'FinalDetect'; Mode = 'Detect' }
    )

    foreach ($runnerStep in $runnerSteps) {
        if ($runnerStep.Name -eq 'DetectAfterDrift') {
            $driftPath = Join-Path -Path $bundleRootFull -ChildPath 'src/tools/New-DemoDrift.ps1'
            try {
                $driftArguments = @{}
                if (-not [string]::IsNullOrWhiteSpace($DemoMarkerPath)) {
                    $driftArguments.MarkerPath = $DemoMarkerPath
                }

                & $driftPath @driftArguments
                if ($LASTEXITCODE -ne 0) {
                    throw [System.InvalidOperationException]::new('Drift tool returned a non-zero exit code.')
                }
                $step = [pscustomobject]@{
                    name = 'ApplyDrift'
                    succeeded = $true
                    exitCode = 0
                    message = 'Deterministic drift applied.'
                }
                [void] $steps.Add($step)
            } catch {
                $step = [pscustomobject]@{
                    name = 'ApplyDrift'
                    succeeded = $false
                    exitCode = 1
                    message = $_.Exception.Message
                }
                [void] $steps.Add($step)
                Write-ProStateKitPreflightReport -ReportRoot $preflightRoot -CurrentOperationId $OperationId -Steps $steps -Succeeded $false
                exit 1
            }
        }

        $stepRunId = '{0}-{1}' -f $OperationId, $runnerStep.Name
        & $runnerPath `
            -Mode $runnerStep.Mode `
            -ConfigPath $configPathFull `
            -BundleRoot $bundleRootFull `
            -Plane $Plane `
            -RuntimeMode $RuntimeMode `
            -RuntimePath $RuntimePath `
            -RuntimeExpectedHash $RuntimeExpectedHash `
            -RuntimeExpectedVersion $RuntimeExpectedVersion `
            -LogRoot $EvidenceRoot `
            -RunId $stepRunId `
            -AllowLabLatest:$AllowLabLatest.IsPresent
        $stepExitCode = $LASTEXITCODE
        $expectedExitCode = 0
        if ($runnerStep.Name -eq 'DetectAfterDrift') {
            $expectedExitCode = 1
        }

        $step = [pscustomobject]@{
            name = $runnerStep.Name
            succeeded = $stepExitCode -eq $expectedExitCode
            exitCode = $stepExitCode
            expectedExitCode = $expectedExitCode
            message = 'Runner step completed.'
        }
        [void] $steps.Add($step)

        if ($stepExitCode -ne $expectedExitCode) {
            Write-ProStateKitPreflightReport -ReportRoot $preflightRoot -CurrentOperationId $OperationId -Steps $steps -Succeeded $false
            exit 1
        }
    }

    Write-ProStateKitPreflightReport -ReportRoot $preflightRoot -CurrentOperationId $OperationId -Steps $steps -Succeeded $true
    exit 0
}

$runnerPath = Join-Path -Path $bundleRootFull -ChildPath 'src/runner/Runner.ps1'
$runnerArguments = @{
    Mode = $Mode
    ConfigPath = $configPathFull
    BundleRoot = $bundleRootFull
    Plane = $Plane
    RuntimeMode = $RuntimeMode
    LogRoot = $EvidenceRoot
}

if (-not [string]::IsNullOrWhiteSpace($OperationId)) {
    $runnerArguments.RunId = $OperationId
}
if (-not [string]::IsNullOrWhiteSpace($RuntimePath)) {
    $runnerArguments.RuntimePath = $RuntimePath
}
if (-not [string]::IsNullOrWhiteSpace($RuntimeExpectedHash)) {
    $runnerArguments.RuntimeExpectedHash = $RuntimeExpectedHash
}
if (-not [string]::IsNullOrWhiteSpace($RuntimeExpectedVersion)) {
    $runnerArguments.RuntimeExpectedVersion = $RuntimeExpectedVersion
}
if ($AllowLabLatest.IsPresent) {
    $runnerArguments.AllowLabLatest = $true
}

& $runnerPath @runnerArguments
$runnerExitCode = $LASTEXITCODE
Exit-ProStateKitPlaneCode -RunnerExitCode $runnerExitCode -CurrentPlane $Plane -CurrentMode $Mode
