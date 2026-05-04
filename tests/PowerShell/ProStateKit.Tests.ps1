$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

BeforeAll {
    $script:testRoot = Split-Path -Path $PSCommandPath -Parent
    $script:testsRoot = Split-Path -Path $script:testRoot -Parent
    $script:repoRoot = Split-Path -Path $script:testsRoot -Parent
    $script:fakeRuntimeBinaryPath = $null

    function Get-ProStateKitTestFakeRuntimeBinary {
        if (-not [string]::IsNullOrWhiteSpace($script:fakeRuntimeBinaryPath) -and (Test-Path -LiteralPath $script:fakeRuntimeBinaryPath -PathType Leaf)) {
            return $script:fakeRuntimeBinaryPath
        }

        $csharpSource = @'
using System;
using System.IO;

class Program
{
    static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--version")
        {
            Console.WriteLine("3.2.0-test");
            return 0;
        }

        string markerPath = Environment.GetEnvironmentVariable("PROSTATEKIT_TEST_FAKE_DSC_MARKER");
        if (string.IsNullOrEmpty(markerPath))
        {
            return 0;
        }

        if (args.Length > 1 && args[1] == "set")
        {
            File.WriteAllText(markerPath, "present\n");
            Console.WriteLine("{\"resources\":[{\"name\":\"Fake resource\",\"type\":\"ProStateKit/Fake\",\"succeeded\":true,\"changed\":true,\"error\":null,\"rebootRequired\":false}]}");
            return 0;
        }

        Console.WriteLine(File.Exists(markerPath)
            ? "{\"resources\":[{\"name\":\"Fake resource\",\"type\":\"ProStateKit/Fake\",\"succeeded\":true,\"changed\":false,\"error\":null,\"rebootRequired\":false}]}"
            : "{\"resources\":[{\"name\":\"Fake resource\",\"type\":\"ProStateKit/Fake\",\"succeeded\":false,\"changed\":false,\"error\":\"Synthetic drift fixture\",\"rebootRequired\":false}]}");
        return 0;
    }
}
'@

        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try {
            $sourceHashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($csharpSource))
        } finally {
            $hasher.Dispose()
        }
        $sourceHash = (([System.BitConverter]::ToString($sourceHashBytes)) -replace '-', '').Substring(0, 16).ToLowerInvariant()

        $cacheRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('prostatekit-fake-runtime-{0}' -f $sourceHash)
        $exeName = 'dsc'
        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $exeName = 'dsc.exe'
        }
        $exePath = Join-Path -Path $cacheRoot -ChildPath $exeName

        if (Test-Path -LiteralPath $exePath -PathType Leaf) {
            $cachedSanityOutput = & $exePath --version
            $cachedSanityExit = $LASTEXITCODE
            $cachedSanityText = (($cachedSanityOutput | ForEach-Object -Process { [string] $_ }) -join "`n").Trim()
            if ($cachedSanityExit -eq 0 -and $cachedSanityText -eq '3.2.0-test') {
                $script:fakeRuntimeBinaryPath = $exePath
                return $exePath
            }
            Remove-Item -LiteralPath $cacheRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        [void] (New-Item -Path $cacheRoot -ItemType Directory -Force)

        $sourcePath = Join-Path -Path $cacheRoot -ChildPath 'Program.cs'
        Set-Content -LiteralPath $sourcePath -Encoding utf8 -Value $csharpSource

        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $cscCandidates = @(
                (Join-Path -Path $env:WINDIR -ChildPath 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
                (Join-Path -Path $env:WINDIR -ChildPath 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
            )
            $csc = $cscCandidates | Where-Object -FilterScript { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
            if ($null -eq $csc) {
                throw [System.IO.FileNotFoundException]::new(
                    ('No csc.exe found at expected .NET Framework paths: {0}' -f ($cscCandidates -join ', ')))
            }

            $cscOutput = & $csc /nologo /target:exe /optimize /out:$exePath $sourcePath 2>&1
            $cscExit = $LASTEXITCODE
            $cscOutputText = ($cscOutput | ForEach-Object -Process { [string] $_ }) -join "`n"
            if ($cscExit -ne 0) {
                throw [System.InvalidOperationException]::new(
                    ('csc.exe failed to compile fake DSC runtime (exit {0}): {1}' -f $cscExit, $cscOutputText))
            }
        } else {
            # POSIX path uses a shell script directly; nothing to compile.
            Set-Content -LiteralPath $exePath -Encoding utf8 -Value @'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
exit 0
'@
            & chmod +x $exePath
        }

        if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]::new(
                ('Fake DSC runtime binary was not produced at {0}.' -f $exePath), $exePath)
        }

        $sanityOutput = & $exePath --version
        $sanityExit = $LASTEXITCODE
        $sanityOutputText = (($sanityOutput | ForEach-Object -Process { [string] $_ }) -join "`n").Trim()
        if ($sanityExit -ne 0 -or $sanityOutputText -ne '3.2.0-test') {
            throw [System.InvalidOperationException]::new(
                ('Fake DSC runtime sanity check failed (exit {0}): expected "3.2.0-test", got "{1}"' -f $sanityExit, $sanityOutputText))
        }

        $script:fakeRuntimeBinaryPath = $exePath
        return $script:fakeRuntimeBinaryPath
    }

    function Copy-ProStateKitTestFakeRuntime {
        param(
            [Parameter(Mandatory)]
            [string] $DestinationPath
        )

        $sourceBinary = Get-ProStateKitTestFakeRuntimeBinary
        $destinationDir = Split-Path -Path $DestinationPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($destinationDir)) {
            [void] (New-Item -Path $destinationDir -ItemType Directory -Force)
        }
        Copy-Item -LiteralPath $sourceBinary -Destination $DestinationPath -Force
        if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
            & chmod +x $DestinationPath
        }
    }
}

Describe -Name 'ProStateKit schema examples' -Fixture {
    It -Name 'Valid wrapper result fixture validates against its schema' -Test {
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/wrapper-result.schema.json'
        $fixturePath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/examples/wrapper-result.valid.json'
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        $fixture = Get-Content -LiteralPath $fixturePath -Raw

        Test-Json -Json $fixture -Schema $schema | Should -BeTrue
    }

    It -Name 'Invalid wrapper result fixture fails schema validation' -Test {
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/wrapper-result.schema.json'
        $fixturePath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/examples/wrapper-result.invalid.json'
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        $fixture = Get-Content -LiteralPath $fixturePath -Raw

        Test-Json -Json $fixture -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
    }

    It -Name 'Valid bundle manifest fixture validates against its schema' -Test {
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/bundle-manifest.schema.json'
        $fixturePath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/examples/bundle-manifest.valid.json'
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        $fixture = Get-Content -LiteralPath $fixturePath -Raw

        Test-Json -Json $fixture -Schema $schema | Should -BeTrue
    }

    It -Name 'Invalid bundle manifest fixture fails schema validation' -Test {
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/bundle-manifest.schema.json'
        $fixturePath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/examples/bundle-manifest.invalid.json'
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        $fixture = Get-Content -LiteralPath $fixturePath -Raw

        Test-Json -Json $fixture -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
    }

    It -Name 'Valid release readiness fixture validates against its schema' -Test {
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/release-readiness.schema.json'
        $fixturePath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/examples/release-readiness.valid.json'
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        $fixture = Get-Content -LiteralPath $fixturePath -Raw

        Test-Json -Json $fixture -Schema $schema | Should -BeTrue
    }

    It -Name 'Invalid release readiness fixture fails schema validation' -Test {
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/release-readiness.schema.json'
        $fixturePath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/examples/release-readiness.invalid.json'
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        $fixture = Get-Content -LiteralPath $fixturePath -Raw

        Test-Json -Json $fixture -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
    }
}

Describe -Name 'Runner parameter contract' -Fixture {
    It -Name 'Limits Mode to Detect and Remediate' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $runnerPath,
            [ref] $tokens,
            [ref] $errors
        )
        $errors.Count | Should -Be 0

        $modeParameter = @($ast.ParamBlock.Parameters | Where-Object -FilterScript {
                $_.Name.VariablePath.UserPath -eq 'Mode'
            })[0]
        $validateSet = @($modeParameter.Attributes | Where-Object -FilterScript {
                $_.TypeName.FullName -eq 'ValidateSet'
            })[0]
        $allowedValues = @($validateSet.PositionalArguments | ForEach-Object -Process { $_.Value })

        $allowedValues | Should -Contain 'Detect'
        $allowedValues | Should -Contain 'Remediate'
        $allowedValues.Count | Should -Be 2
    }

    It -Name 'Marks ConfigPath and BundleRoot as mandatory' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $runnerPath,
            [ref] $tokens,
            [ref] $errors
        )
        $errors.Count | Should -Be 0

        foreach ($parameterName in @('ConfigPath', 'BundleRoot')) {
            $parameter = @($ast.ParamBlock.Parameters | Where-Object -FilterScript {
                    $_.Name.VariablePath.UserPath -eq $parameterName
                })[0]
            $parameterAttribute = @($parameter.Attributes | Where-Object -FilterScript {
                    $_.TypeName.FullName -eq 'Parameter'
                })[0]
            $mandatoryArgument = @($parameterAttribute.NamedArguments | Where-Object -FilterScript {
                    $_.ArgumentName -eq 'Mandatory'
                })

            $mandatoryArgument.Count | Should -BeGreaterThan 0
        }
    }
}

Describe -Name 'Fail-closed behavior' -Fixture {
    It -Name 'Runner writes schema-valid evidence when pinned runtime proof is missing' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $configPath = Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.yaml'
        $runId = 'pester-{0}' -f ([guid]::NewGuid().ToString('N'))
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $runRoot = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath $runId)
        $pwshPath = (Get-Process -Id $PID).Path
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/wrapper-result.schema.json'
        $currentPath = Join-Path -Path $logRoot -ChildPath 'Current/last-result.json'

        try {
            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $configPath -BundleRoot $script:repoRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            foreach ($fileName in @(
                    'dsc.exitcode.txt',
                    'dsc.raw.json',
                    'dsc.stderr.log',
                    'manifest.snapshot.json',
                    'runtime.json',
                    'summary.txt',
                    'transcript.log',
                    'wrapper.log',
                    'wrapper.result.json'
                )) {
                Test-Path -LiteralPath (Join-Path -Path $runRoot -ChildPath $fileName) -PathType Leaf | Should -BeTrue
            }

            $schema = Get-Content -LiteralPath $schemaPath -Raw
            $result = Get-Content -LiteralPath (Join-Path -Path $runRoot -ChildPath 'wrapper.result.json') -Raw
            Test-Json -Json $result -Schema $schema | Should -BeTrue
            Test-Path -LiteralPath $currentPath -PathType Leaf | Should -BeTrue

            $resultObject = $result | ConvertFrom-Json
            $resultObject.operationId | Should -Be $runId
            $resultObject.plane | Should -Be 'Local'
            $resultObject.exitDecision.exitCode | Should -Be 2
        } finally {
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Primary entry point maps local runtime failure to plane exit code 1' -Test {
        $entryPointPath = Join-Path -Path $script:repoRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
        $runId = 'entry-{0}' -f ([guid]::NewGuid().ToString('N'))
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            & $pwshPath `
                -NoProfile `
                -File $entryPointPath `
                -Mode Detect `
                -Plane Local `
                -ConfigPath 'configs/baseline.dsc.yaml' `
                -RuntimeMode PinnedBundle `
                -EvidenceRoot $logRoot `
                -OperationId $runId `
                -BundleRoot $script:repoRoot
            $LASTEXITCODE | Should -Be 1

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.exitDecision.exitCode | Should -Be 2
            $result.classification | Should -Be 'Failed'
        } finally {
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Primary entry point emits concise Intune summary on fail-closed detection' -Test {
        $entryPointPath = Join-Path -Path $script:repoRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
        $runId = 'intune-summary-{0}' -f ([guid]::NewGuid().ToString('N'))
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            $output = & $pwshPath `
                -NoProfile `
                -File $entryPointPath `
                -Mode Detect `
                -Plane Intune `
                -ConfigPath 'configs/baseline.dsc.yaml' `
                -RuntimeMode PinnedBundle `
                -EvidenceRoot $logRoot `
                -OperationId $runId `
                -BundleRoot $script:repoRoot
            $LASTEXITCODE | Should -Be 1

            $summary = ($output -join [Environment]::NewLine)
            $summary | Should -Match 'ProStateKit Detect'
            $summary.Length | Should -BeLessOrEqual 2048
        } finally {
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner fails closed when bundle manifest hashes do not match' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'tamper-{0}' -f ([guid]::NewGuid().ToString('N'))
        $bundleRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $configDestination = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
        $schemaDestination = Join-Path -Path $bundleRoot -ChildPath 'schemas/bundle-manifest.schema.json'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path (Split-Path -Path $configDestination -Parent) -ItemType Directory -Force)
            [void] (New-Item -Path (Split-Path -Path $schemaDestination -Parent) -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $configDestination -Force
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'schemas/bundle-manifest.schema.json') -Destination $schemaDestination -Force
            Set-Content -LiteralPath (Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json') -Value (
                [pscustomobject]@{
                    name = 'ProStateKit'
                    version = '0.1.0'
                    schemaVersion = '1.0.0'
                    dscVersion = 'TBD'
                    builtAt = 'TBD'
                    sourceCommit = 'unknown'
                    wrapperHash = 'TBD'
                    configHash = 'TBD'
                    runtime = [pscustomobject]@{
                        path = 'runtime/dsc/dsc'
                        expectedHash = 'TBD'
                    }
                    validationStatus = 'test'
                    supportedPlanes = @('Local')
                    files = @(
                        [pscustomobject]@{
                            path = 'configs/baseline.dsc.yaml'
                            sha256 = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
                        }
                    )
                } | ConvertTo-Json -Depth 10
            ) -Encoding utf8

            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $configDestination -BundleRoot $bundleRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'Manifest hash mismatch'
        } finally {
            Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner requires a manifest before executing PinnedBundle runtime' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'manifest-required-{0}' -f ([guid]::NewGuid().ToString('N'))
        $bundleRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $configDestination = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
        $dscExeName = 'dsc'
        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $dscExeName = 'dsc.exe'
        }
        $runtimePath = Join-Path -Path $bundleRoot -ChildPath (Join-Path -Path 'runtime/dsc' -ChildPath $dscExeName)
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path (Split-Path -Path $configDestination -Parent) -ItemType Directory -Force)
            [void] (New-Item -Path (Split-Path -Path $runtimePath -Parent) -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $configDestination -Force
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                Copy-ProStateKitTestFakeRuntime -DestinationPath $runtimePath
            } else {
                Set-Content -LiteralPath $runtimePath -Value @'
#!/usr/bin/env sh
printf '%s\n' '3.2.0-test'
exit 0
'@ -Encoding utf8
                & chmod +x $runtimePath
            }

            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Detect `
                -ConfigPath $configDestination `
                -BundleRoot $bundleRoot `
                -LogRoot $logRoot `
                -RunId $runId `
                -RuntimeMode PinnedBundle
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'PinnedBundle runtime mode requires bundle.manifest.json'
        } finally {
            Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner validates bundle manifest schema before execution' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'manifest-schema-{0}' -f ([guid]::NewGuid().ToString('N'))
        $bundleRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $configDestination = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
        $schemaDestination = Join-Path -Path $bundleRoot -ChildPath 'schemas/bundle-manifest.schema.json'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path (Split-Path -Path $configDestination -Parent) -ItemType Directory -Force)
            [void] (New-Item -Path (Split-Path -Path $schemaDestination -Parent) -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $configDestination -Force
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'schemas/bundle-manifest.schema.json') -Destination $schemaDestination -Force
            Set-Content -LiteralPath (Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json') -Value (
                [pscustomobject]@{
                    name = 'ProStateKit'
                    version = '0.1.0'
                    schemaVersion = '1.0.0'
                    dscVersion = 'TBD'
                    builtAt = 'TBD'
                    sourceCommit = 'unknown'
                    wrapperHash = 'TBD'
                    configHash = 'TBD'
                    runtime = [pscustomobject]@{
                        path = 'runtime/dsc/dsc'
                        expectedHash = 'TBD'
                    }
                    validationStatus = 'test'
                    files = @(
                        [pscustomobject]@{
                            path = 'configs/baseline.dsc.yaml'
                            sha256 = 'TBD'
                        }
                    )
                } | ConvertTo-Json -Depth 10
            ) -Encoding utf8

            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $configDestination -BundleRoot $bundleRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'Bundle manifest failed schema validation'
        } finally {
            Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner rejects duplicate bundle manifest file paths before execution' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'manifest-duplicate-{0}' -f ([guid]::NewGuid().ToString('N'))
        $bundleRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $configDestination = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
        $schemaDestination = Join-Path -Path $bundleRoot -ChildPath 'schemas/bundle-manifest.schema.json'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path (Split-Path -Path $configDestination -Parent) -ItemType Directory -Force)
            [void] (New-Item -Path (Split-Path -Path $schemaDestination -Parent) -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $configDestination -Force
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'schemas/bundle-manifest.schema.json') -Destination $schemaDestination -Force
            $configHash = 'sha256:{0}' -f (Get-FileHash -LiteralPath $configDestination -Algorithm SHA256).Hash.ToLowerInvariant()
            Set-Content -LiteralPath (Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json') -Value (
                [pscustomobject]@{
                    name = 'ProStateKit'
                    version = '0.1.0'
                    schemaVersion = '1.0.0'
                    dscVersion = 'TBD'
                    builtAt = 'TBD'
                    sourceCommit = 'unknown'
                    wrapperHash = 'TBD'
                    configHash = 'TBD'
                    runtime = [pscustomobject]@{
                        path = 'runtime/dsc/dsc'
                        expectedHash = 'TBD'
                    }
                    validationStatus = 'test'
                    supportedPlanes = @('Local')
                    files = @(
                        [pscustomobject]@{
                            path = 'configs/baseline.dsc.yaml'
                            sha256 = $configHash
                        }
                        [pscustomobject]@{
                            path = 'configs/baseline.dsc.yaml'
                            sha256 = $configHash
                        }
                    )
                } | ConvertTo-Json -Depth 10
            ) -Encoding utf8

            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $configDestination -BundleRoot $bundleRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'Bundle manifest contains duplicate file paths: configs/baseline.dsc.yaml'
        } finally {
            Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner requires ConfigPath to be covered by manifest hashes' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'manifest-config-{0}' -f ([guid]::NewGuid().ToString('N'))
        $bundleRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $configDestination = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
        $schemaDestination = Join-Path -Path $bundleRoot -ChildPath 'schemas/bundle-manifest.schema.json'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path (Split-Path -Path $configDestination -Parent) -ItemType Directory -Force)
            [void] (New-Item -Path (Split-Path -Path $schemaDestination -Parent) -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $configDestination -Force
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'schemas/bundle-manifest.schema.json') -Destination $schemaDestination -Force
            $schemaHash = 'sha256:{0}' -f (Get-FileHash -LiteralPath $schemaDestination -Algorithm SHA256).Hash.ToLowerInvariant()
            Set-Content -LiteralPath (Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json') -Value (
                [pscustomobject]@{
                    name = 'ProStateKit'
                    version = '0.1.0'
                    schemaVersion = '1.0.0'
                    dscVersion = 'TBD'
                    builtAt = 'TBD'
                    sourceCommit = 'unknown'
                    wrapperHash = 'TBD'
                    configHash = 'TBD'
                    runtime = [pscustomobject]@{
                        path = 'runtime/dsc/dsc'
                        expectedHash = 'TBD'
                    }
                    validationStatus = 'test'
                    supportedPlanes = @('Local')
                    files = @(
                        [pscustomobject]@{
                            path = 'schemas/bundle-manifest.schema.json'
                            sha256 = $schemaHash
                        }
                    )
                } | ConvertTo-Json -Depth 10
            ) -Encoding utf8

            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $configDestination -BundleRoot $bundleRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'ConfigPath is not covered by manifest hashes: configs/baseline.dsc.yaml'
        } finally {
            Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner fails closed when bundle configHash does not match selected ConfigPath' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'manifest-config-hash-{0}' -f ([guid]::NewGuid().ToString('N'))
        $bundleRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $configDestination = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
        $schemaDestination = Join-Path -Path $bundleRoot -ChildPath 'schemas/bundle-manifest.schema.json'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path (Split-Path -Path $configDestination -Parent) -ItemType Directory -Force)
            [void] (New-Item -Path (Split-Path -Path $schemaDestination -Parent) -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $configDestination -Force
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'schemas/bundle-manifest.schema.json') -Destination $schemaDestination -Force
            $configHash = 'sha256:{0}' -f (Get-FileHash -LiteralPath $configDestination -Algorithm SHA256).Hash.ToLowerInvariant()
            Set-Content -LiteralPath (Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json') -Value (
                [pscustomobject]@{
                    name = 'ProStateKit'
                    version = '0.1.0'
                    schemaVersion = '1.0.0'
                    dscVersion = 'TBD'
                    builtAt = 'TBD'
                    sourceCommit = 'unknown'
                    wrapperHash = 'TBD'
                    configHash = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
                    runtime = [pscustomobject]@{
                        path = 'runtime/dsc/dsc'
                        expectedHash = 'TBD'
                    }
                    validationStatus = 'test'
                    supportedPlanes = @('Local')
                    files = @(
                        [pscustomobject]@{
                            path = 'configs/baseline.dsc.yaml'
                            sha256 = $configHash
                        }
                    )
                } | ConvertTo-Json -Depth 10
            ) -Encoding utf8

            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $configDestination -BundleRoot $bundleRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'Config hash mismatch'
        } finally {
            Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner rejects config paths outside BundleRoot' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'path-{0}' -f ([guid]::NewGuid().ToString('N'))
        $outsideRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('outside-{0}' -f $runId)
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $outsideConfig = Join-Path -Path $outsideRoot -ChildPath 'outside.yaml'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path $outsideRoot -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $outsideConfig -Force

            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $outsideConfig -BundleRoot $script:repoRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'ConfigPath must resolve inside BundleRoot'
        } finally {
            Remove-Item -LiteralPath $outsideRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner rejects symlink config paths inside BundleRoot' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $runId = 'symlink-{0}' -f ([guid]::NewGuid().ToString('N'))
        $bundleRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('bundle-{0}' -f $runId)
        $outsideRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('outside-{0}' -f $runId)
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('log-{0}' -f $runId)
        $linkedConfig = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
        $outsideConfig = Join-Path -Path $outsideRoot -ChildPath 'outside.yaml'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path (Split-Path -Path $linkedConfig -Parent) -ItemType Directory -Force)
            [void] (New-Item -Path $outsideRoot -ItemType Directory -Force)
            Copy-Item -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml') -Destination $outsideConfig -Force
            try {
                [void] (New-Item -ItemType SymbolicLink -Path $linkedConfig -Target $outsideConfig -ErrorAction Stop)
            } catch {
                Set-ItResult -Skipped -Because ('Symlink creation is unavailable in this environment: {0}' -f $_.Exception.Message)
                return
            }

            & $pwshPath -NoProfile -File $runnerPath -Mode Detect -ConfigPath $linkedConfig -BundleRoot $bundleRoot -LogRoot $logRoot -RunId $runId
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'ConfigPath must not contain symlink'
        } finally {
            Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $outsideRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Primary entry point blocks LabLatest for production planes' -Test {
        $entryPointPath = Join-Path -Path $script:repoRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
        $runId = 'lablatest-{0}' -f ([guid]::NewGuid().ToString('N'))
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            & $pwshPath `
                -NoProfile `
                -File $entryPointPath `
                -Mode Detect `
                -Plane Intune `
                -ConfigPath 'configs/baseline.dsc.yaml' `
                -RuntimeMode LabLatest `
                -EvidenceRoot $logRoot `
                -OperationId $runId `
                -BundleRoot $script:repoRoot `
                -AllowLabLatest 2>$null
            $LASTEXITCODE | Should -Not -Be 0
        } finally {
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Primary entry point blocks InstalledPath in production planes without runtime policy' -Test {
        $entryPointPath = Join-Path -Path $script:repoRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
        $runId = 'installedpath-policy-{0}' -f ([guid]::NewGuid().ToString('N'))
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path $tempRoot -ChildPath 'evidence'
        $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path $tempRoot -ItemType Directory -Force)
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc.cmd'
                Set-Content -LiteralPath $runtimePath -Encoding ascii -Value @'
@echo off
if "%1"=="--version" (
  echo 3.2.0-test
  exit /b 0
)
exit /b 0
'@
            } else {
                Set-Content -LiteralPath $runtimePath -Encoding utf8 -Value @'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
exit 0
'@
                & chmod +x $runtimePath
            }

            & $pwshPath `
                -NoProfile `
                -File $entryPointPath `
                -Mode Detect `
                -Plane Intune `
                -ConfigPath 'configs/baseline.dsc.yaml' `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath `
                -EvidenceRoot $logRoot `
                -OperationId $runId `
                -BundleRoot $script:repoRoot 2>$null
            $LASTEXITCODE | Should -Not -Be 0
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Preflight fails closed with a report when bundle validation cannot run' -Test {
        $entryPointPath = Join-Path -Path $script:repoRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
        $runId = 'preflight-{0}' -f ([guid]::NewGuid().ToString('N'))
        $logRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            & $pwshPath `
                -NoProfile `
                -File $entryPointPath `
                -Mode Preflight `
                -Plane Local `
                -ConfigPath 'configs/baseline.dsc.yaml' `
                -RuntimeMode PinnedBundle `
                -EvidenceRoot $logRoot `
                -OperationId $runId `
                -BundleRoot $script:repoRoot
            $LASTEXITCODE | Should -Be 1

            $reportPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Preflight' -ChildPath (Join-Path -Path $runId -ChildPath 'preflight.report.json'))
            Test-Path -LiteralPath $reportPath -PathType Leaf | Should -BeTrue

            $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
            $report.succeeded | Should -BeFalse
            $report.steps[0].name | Should -Be 'ValidateBundle'
        } finally {
            Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner normalizes structured runtime output for Detect and Remediate' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $configPath = Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
        $runId = 'fake-runtime-{0}' -f ([guid]::NewGuid().ToString('N'))
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path $tempRoot -ChildPath 'evidence'
        $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path $tempRoot -ItemType Directory -Force)
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc.cmd'
                Set-Content -LiteralPath $runtimePath -Encoding ascii -Value @'
@echo off
if "%1"=="--version" (
  echo 3.2.0-test
  exit /b 0
)
echo {"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":false}]}
exit /b 0
'@
            } else {
                Set-Content -LiteralPath $runtimePath -Encoding utf8 -Value @'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
printf '%s\n' '{"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":false}]}'
exit 0
'@
                & chmod +x $runtimePath
            }

            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Detect `
                -ConfigPath $configPath `
                -BundleRoot $script:repoRoot `
                -LogRoot $logRoot `
                -RunId "$runId-detect" `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath
            $LASTEXITCODE | Should -Be 0

            $detectResultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path "$runId-detect" -ChildPath 'wrapper.result.json'))
            $detectResult = Get-Content -LiteralPath $detectResultPath -Raw | ConvertFrom-Json
            $detectResult.compliant | Should -BeTrue
            $detectResult.runtime.version | Should -Be '3.2.0-test'
            Test-Path -LiteralPath (Join-Path -Path (Split-Path -Path $detectResultPath -Parent) -ChildPath 'dsc.test.stdout.raw.json') -PathType Leaf | Should -BeTrue

            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Remediate `
                -ConfigPath $configPath `
                -BundleRoot $script:repoRoot `
                -LogRoot $logRoot `
                -RunId "$runId-remediate" `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath
            $LASTEXITCODE | Should -Be 0

            $remediateRunRoot = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath "$runId-remediate")
            Test-Path -LiteralPath (Join-Path -Path $remediateRunRoot -ChildPath 'dsc.set.stdout.raw.json') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path -Path $remediateRunRoot -ChildPath 'dsc.test.stdout.raw.json') -PathType Leaf | Should -BeTrue
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner normalizes alternate DSC resource proof shapes' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $configPath = Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
        $runId = 'alternate-proof-{0}' -f ([guid]::NewGuid().ToString('N'))
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path $tempRoot -ChildPath 'evidence'
        $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path $tempRoot -ItemType Directory -Force)
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc.cmd'
                Set-Content -LiteralPath $runtimePath -Encoding ascii -Value @'
@echo off
if "%1"=="--version" (
  echo 3.2.0-test
  exit /b 0
)
echo {"actualState":{"instanceName":"Alternate proof","fullyQualifiedTypeName":"ProStateKit/Alternate","compliant":true,"wasChanged":true,"message":null,"rebootRequired":false}}
exit /b 0
'@
            } else {
                Set-Content -LiteralPath $runtimePath -Encoding utf8 -Value @'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
printf '%s\n' '{"actualState":{"instanceName":"Alternate proof","fullyQualifiedTypeName":"ProStateKit/Alternate","compliant":true,"wasChanged":true,"message":null,"rebootRequired":false}}'
exit 0
'@
                & chmod +x $runtimePath
            }

            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Detect `
                -ConfigPath $configPath `
                -BundleRoot $script:repoRoot `
                -LogRoot $logRoot `
                -RunId $runId `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath
            $LASTEXITCODE | Should -Be 0

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.compliant | Should -BeTrue
            @($result.resources)[0].name | Should -Be 'Alternate proof'
            @($result.resources)[0].type | Should -Be 'ProStateKit/Alternate'
            @($result.resources)[0].changed | Should -BeFalse
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner writes and clears the current reboot marker after verified compliance' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $configPath = Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
        $runId = 'reboot-marker-{0}' -f ([guid]::NewGuid().ToString('N'))
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path $tempRoot -ChildPath 'evidence'
        $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc'
        $flagPath = Join-Path -Path $tempRoot -ChildPath 'reboot-required.flag'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path $tempRoot -ItemType Directory -Force)
            Set-Content -LiteralPath $flagPath -Value 'reboot' -Encoding utf8
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc.cmd'
                Set-Content -LiteralPath $runtimePath -Encoding ascii -Value @"
@echo off
if "%1"=="--version" (
  echo 3.2.0-test
  exit /b 0
)
if exist "$flagPath" (
  echo {"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":true}]}
) else (
  echo {"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":false}]}
)
exit /b 0
"@
            } else {
                Set-Content -LiteralPath $runtimePath -Encoding utf8 -Value @"
#!/bin/sh
if [ "`$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
if [ -f "$flagPath" ]; then
  printf '%s\n' '{"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":true}]}'
else
  printf '%s\n' '{"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":false}]}'
fi
exit 0
"@
                & chmod +x $runtimePath
            }

            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Detect `
                -ConfigPath $configPath `
                -BundleRoot $script:repoRoot `
                -LogRoot $logRoot `
                -RunId "$runId-reboot" `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath
            $LASTEXITCODE | Should -Be 0

            $currentMarkerPath = Join-Path -Path $logRoot -ChildPath 'Current/reboot.marker.json'
            $runMarkerPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path "$runId-reboot" -ChildPath 'reboot.marker.json'))
            Test-Path -LiteralPath $currentMarkerPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $runMarkerPath -PathType Leaf | Should -BeTrue

            Remove-Item -LiteralPath $flagPath -Force
            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Detect `
                -ConfigPath $configPath `
                -BundleRoot $script:repoRoot `
                -LogRoot $logRoot `
                -RunId "$runId-clear" `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath
            $LASTEXITCODE | Should -Be 0

            Test-Path -LiteralPath $currentMarkerPath -PathType Leaf | Should -BeFalse
            Test-Path -LiteralPath $runMarkerPath -PathType Leaf | Should -BeTrue
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runner fails closed when InstalledPath runtime hash policy does not match' -Test {
        $runnerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1'
        $configPath = Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
        $runId = 'installedpath-hash-{0}' -f ([guid]::NewGuid().ToString('N'))
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $logRoot = Join-Path -Path $tempRoot -ChildPath 'evidence'
        $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            [void] (New-Item -Path $tempRoot -ItemType Directory -Force)
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                $runtimePath = Join-Path -Path $tempRoot -ChildPath 'dsc.cmd'
                Set-Content -LiteralPath $runtimePath -Encoding ascii -Value @'
@echo off
if "%1"=="--version" (
  echo 3.2.0-test
  exit /b 0
)
echo {"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":false}]}
exit /b 0
'@
            } else {
                Set-Content -LiteralPath $runtimePath -Encoding utf8 -Value @'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
printf '%s\n' '{"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":false}]}'
exit 0
'@
                & chmod +x $runtimePath
            }

            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Detect `
                -ConfigPath $configPath `
                -BundleRoot $script:repoRoot `
                -LogRoot $logRoot `
                -RunId $runId `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath `
                -RuntimeExpectedHash 'sha256:0000000000000000000000000000000000000000000000000000000000000000' `
                -RuntimeExpectedVersion '3.2.0-test'
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $logRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'InstalledPath runtime hash mismatch'
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe -Name 'Redaction helpers' -Fixture {
    It -Name 'Redacts obvious secret-shaped values' -Test {
        Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'src/ProStateKit.Redaction.psm1') -Force

        $redacted = ConvertTo-ProStateKitRedactedText -Text 'password=hunter2 token: abc123 Bearer abc.def.ghi'

        $redacted | Should -Not -Match 'hunter2'
        $redacted | Should -Not -Match 'abc123'
        $redacted | Should -Not -Match 'abc\.def\.ghi'
        $redacted | Should -Match '\[REDACTED\]'
    }
}

Describe -Name 'DSC output fixtures' -Fixture {
    It -Name 'Parses checked-in DSC 3.2.0-compatible resource fixtures' -Test {
        Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'src/ProStateKit.Dsc.psm1') -Force

        foreach ($fixtureName in @(
                'config-test.compliant.json',
                'config-test.noncompliant.json',
                'config-set.success.json',
                'config-test.results-wrapper.json',
                'config-set.result-wrapper.json',
                'config-test.actual-state.json',
                'config-test.single-resource.json'
            )) {
            $fixturePath = Join-Path -Path $script:repoRoot -ChildPath (Join-Path -Path 'tests/fixtures/dsc-3.2.0' -ChildPath $fixtureName)
            $mode = 'Detect'
            if ($fixtureName.StartsWith('config-set')) {
                $mode = 'Remediate'
            }
            $resources = ConvertFrom-ProStateKitDscJson -Json (Get-Content -LiteralPath $fixturePath -Raw) -Mode $mode

            @($resources).Count | Should -BeGreaterThan 0
            @($resources)[0].name | Should -Not -BeNullOrEmpty
            @($resources)[0].type | Should -Not -BeNullOrEmpty
            @($resources)[0].succeeded | Should -BeOfType ([bool])
            @($resources)[0].changed | Should -BeOfType ([bool])
            @($resources)[0].rebootRequired | Should -BeOfType ([bool])
        }
    }

    It -Name 'Fails closed when DSC output has no resource proof' -Test {
        Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'src/ProStateKit.Dsc.psm1') -Force

        { ConvertFrom-ProStateKitDscJson -Json '{"metadata":{"status":"ok"}}' } |
            Should -Throw -ExpectedMessage '*resource proof*'
    }
}

Describe -Name 'Bundle tooling' -Fixture {
    BeforeAll {
        function Initialize-ProStateKitFakeRuntimeForTest {
            [void] (New-Item -Path (Split-Path -Path $script:bundleRuntimePath -Parent) -ItemType Directory -Force)
            $runtimeCompanionPath = Join-Path -Path (Split-Path -Path $script:bundleRuntimePath -Parent) -ChildPath (Join-Path -Path 'lib' -ChildPath 'prostatekit-runtime-support.txt')
            [void] (New-Item -Path (Split-Path -Path $runtimeCompanionPath -Parent) -ItemType Directory -Force)
            Set-Content -LiteralPath $runtimeCompanionPath -Encoding utf8 -Value 'runtime companion fixture'

            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                # PowerShell on Windows invokes native commands via CreateProcess, which
                # rejects a non-PE file regardless of its `.exe` extension. Drop in a real
                # tiny .NET console binary so `& $dscPath --version` actually executes.
                Copy-ProStateKitTestFakeRuntime -DestinationPath $script:bundleRuntimePath
            } else {
                Set-Content -LiteralPath $script:bundleRuntimePath -Encoding utf8 -Value @'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
exit 0
'@
                & chmod +x $script:bundleRuntimePath
            }
        }

        function Invoke-ProStateKitBundleBuildForTest {
            $buildScript = Join-Path -Path $script:bundleSourceRoot -ChildPath 'tools/Build-Bundle.ps1'
            & $buildScript -RepositoryRoot $script:bundleSourceRoot -OutputPath $script:bundleOutputRoot -Version '0.1.0' | Out-Null
            $LASTEXITCODE | Should -Be 0

            return Join-Path -Path $script:bundleOutputRoot -ChildPath 'ProStateKit-0.1.0'
        }
    }

    It -Name 'Build and validation required file lists stay synchronized' -Test {
        function Get-AssignedStringArrayForTest {
            param(
                [Parameter(Mandatory)]
                [string] $Path,

                [Parameter(Mandatory)]
                [string] $VariableName
            )

            $targetVariableName = $VariableName
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $Path,
                [ref] $tokens,
                [ref] $errors
            )
            $errors.Count | Should -Be 0

            $assignment = @($ast.FindAll({
                        param($node)

                        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                        $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                        $node.Left.VariablePath.UserPath -eq $targetVariableName
                    }, $true))[0]

            return @($assignment.Right.FindAll({
                        param($node)

                        $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
                    }, $true) | ForEach-Object -Process { $_.Value })
        }

        $buildScriptPath = Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Build-Bundle.ps1'
        $testBundlePath = Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Test-Bundle.ps1'
        $stagedFiles = Get-AssignedStringArrayForTest -Path $buildScriptPath -VariableName 'relativePaths'
        $stagedDependencyRoots = Get-AssignedStringArrayForTest -Path $buildScriptPath -VariableName 'nodeRuntimeDependencyRoots'
        $requiredFiles = Get-AssignedStringArrayForTest -Path $testBundlePath -VariableName 'requiredFiles'

        $stagedFiles | Should -Not -BeNullOrEmpty
        $stagedDependencyRoots | Should -Not -BeNullOrEmpty
        $requiredFiles | Should -Not -BeNullOrEmpty

        $missingFromVerifier = @($stagedFiles | Where-Object -FilterScript { $requiredFiles -notcontains $_ })
        $missingFromBuilder = @($requiredFiles | Where-Object -FilterScript {
                $requiredFile = $_
                $isGeneratedManifest = $requiredFile -eq 'bundle.manifest.json'
                $isStagedFile = $stagedFiles -contains $requiredFile
                $isNodeRuntimeDependency = @($stagedDependencyRoots | Where-Object -FilterScript {
                        $requiredFile.StartsWith(('{0}/' -f $_), [System.StringComparison]::Ordinal)
                    }).Count -gt 0

                -not ($isGeneratedManifest -or $isStagedFile -or $isNodeRuntimeDependency)
            })

        $missingFromVerifier | Should -BeNullOrEmpty
        $missingFromBuilder | Should -BeNullOrEmpty
    }

    BeforeEach {
        $runId = 'bundle-{0}' -f ([guid]::NewGuid().ToString('N'))
        $script:bundleTempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
        $script:bundleSourceRoot = Join-Path -Path $script:bundleTempRoot -ChildPath 'source'
        $script:bundleOutputRoot = Join-Path -Path $script:bundleTempRoot -ChildPath 'dist'
        $script:bundleDscExeName = 'dsc'
        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $script:bundleDscExeName = 'dsc.exe'
        }
        $script:bundleRuntimePath = Join-Path -Path $script:bundleSourceRoot -ChildPath (Join-Path -Path 'runtime/dsc' -ChildPath $script:bundleDscExeName)

        [void] (New-Item -Path $script:bundleSourceRoot -ItemType Directory -Force)
        foreach ($relativePath in @(
                '.github',
                '.markdownlint.jsonc',
                '.pre-commit-config.yaml',
                '.yamllint.yml',
                'README.md',
                'LICENSE',
                'SECURITY.md',
                'bundle.manifest.template.json',
                'configs',
                'docs',
                'evidence',
                'planes',
                'resources',
                'runtime',
                'schemas',
                'src',
                'package-lock.json',
                'package.json',
                'node_modules/argparse',
                'node_modules/js-yaml',
                'tests',
                'tools'
            )) {
            $sourcePath = Join-Path -Path $script:repoRoot -ChildPath $relativePath
            $destinationPath = Join-Path -Path $script:bundleSourceRoot -ChildPath $relativePath
            $destinationParent = Split-Path -Path $destinationPath -Parent
            if (-not [string]::IsNullOrWhiteSpace($destinationParent)) {
                [void] (New-Item -Path $destinationParent -ItemType Directory -Force)
            }
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Recurse -Force
        }
    }

    AfterEach {
        Remove-Item -LiteralPath $script:bundleTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It -Name 'Builds and validates a bundle when a pinned runtime is present' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest

            $zipPath = Join-Path -Path $script:bundleOutputRoot -ChildPath 'ProStateKit-0.1.0.zip'
            $checksumPath = '{0}.sha256' -f $zipPath
            $releaseManifestPath = Join-Path -Path $script:bundleOutputRoot -ChildPath 'bundle.manifest.json'
            Test-Path -LiteralPath $zipPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $checksumPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $releaseManifestPath -PathType Leaf | Should -BeTrue
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
            try {
                $zipEntries = @($zipArchive.Entries | ForEach-Object -Process { $_.FullName })
                $zipEntries | Should -Contain '.github/scripts/lint-markdown-links.js'
                $zipEntries | Should -Contain '.pre-commit-config.yaml'
                $zipEntries | Should -Contain 'bundle.manifest.json'
                $zipEntries | Should -Contain 'node_modules/js-yaml/index.js'
                $zipEntries | Should -Contain 'runtime/dsc/lib/prostatekit-runtime-support.txt'
                $zipEntries | Should -Contain 'evidence/sample/compliant-detect/wrapper.result.json'
            } finally {
                $zipArchive.Dispose()
            }

            $manifestPath = Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $releaseManifest = Get-Content -LiteralPath $releaseManifestPath -Raw | ConvertFrom-Json
            $manifest.dscVersion | Should -Be '3.2.0-test'
            $releaseManifest.dscVersion | Should -Be '3.2.0-test'
            $releaseManifest.runtime.expectedHash | Should -Be $manifest.runtime.expectedHash
            @($releaseManifest.files.path) | Should -Contain 'src/tools/Test-Bundle.ps1'
            @($releaseManifest.files.path) | Should -Contain 'runtime/dsc/lib/prostatekit-runtime-support.txt'
            $manifest.wrapperHash | Should -Match '^sha256:[a-f0-9]{64}$'
            $manifest.configHash | Should -Match '^sha256:[a-f0-9]{64}$'
            @($manifest.files.path) | Should -Contain 'tools/New-Package.ps1'
            @($manifest.files.path) | Should -Contain 'src/tools/Build-Bundle.ps1'
            @($manifest.files.path) | Should -Contain 'src/tools/Invoke-PSScriptAnalyzer.ps1'
            @($manifest.files.path) | Should -Contain 'src/tools/Invoke-SchemaLint.ps1'
            @($manifest.files.path) | Should -Contain 'src/tools/Test-ReleaseReadiness.ps1'
            @($manifest.files.path) | Should -Contain 'src/runner/Intune/Detect.ps1'
            @($manifest.files.path) | Should -Contain 'src/runner/ConfigMgr/Runner.ps1'
            @($manifest.files.path) | Should -Contain 'docs/execution-contract.md'
            @($manifest.files.path) | Should -Contain 'docs/completion-audit.md'
            @($manifest.files.path) | Should -Contain 'runtime/dsc/README.md'
            @($manifest.files.path) | Should -Contain 'package.json'
            @($manifest.files.path) | Should -Contain 'node_modules/argparse/argparse.js'
            @($manifest.files.path) | Should -Contain 'node_modules/js-yaml/index.js'
            @($manifest.files.path) | Should -Contain '.github/scripts/lint-markdown-links.js'
            @($manifest.files.path) | Should -Contain 'tests/PowerShell/ProStateKit.Tests.ps1'
            @($manifest.files.path) | Should -Contain 'evidence/sample/compliant-detect/wrapper.result.json'
            @($manifest.files.path) | Should -Contain 'schemas/release-readiness.schema.json'
            @($manifest.files.path) | Should -Contain 'schemas/examples/release-readiness.valid.json'
            @($manifest.files.path) | Should -Contain 'schemas/examples/wrapper-result.valid.json'

            foreach ($expectedBundleFile in @(
                    '.github/linting/PSScriptAnalyzerSettings.psd1',
                    '.github/scripts/lint-markdown-links.js',
                    '.github/scripts/lint-nested-markdown.js',
                    '.markdownlint.jsonc',
                    '.pre-commit-config.yaml',
                    '.yamllint.yml',
                    'README.md',
                    'LICENSE',
                    'SECURITY.md',
                    'docs/completion-audit.md',
                    'docs/intune.md',
                    'docs/configmgr.md',
                    'docs/execution-contract.md',
                    'docs/resource-gaps.md',
                    'docs/runbooks/demo-runbook.md',
                    'docs/runbooks/windows-11-quickstart.md',
                    'src/tools/Invoke-PSScriptAnalyzer.ps1',
                    'src/tools/Invoke-SchemaLint.ps1',
                    'src/tools/Test-ReleaseReadiness.ps1',
                    'src/runner/Intune/Detect.ps1',
                    'src/runner/Intune/Remediate.ps1',
                    'src/runner/ConfigMgr/Runner.ps1',
                    'runtime/dsc/README.md',
                    'runtime/dsc/lib/prostatekit-runtime-support.txt',
                    'tests/PowerShell/ProStateKit.Tests.ps1',
                    'tests/fixtures/dsc-3.2.0/config-test.results-wrapper.json',
                    'evidence/sample/compliant-detect/wrapper.result.json',
                    'schemas/release-readiness.schema.json',
                    'schemas/examples/release-readiness.valid.json',
                    'schemas/examples/wrapper-result.valid.json',
                    'package.json',
                    'package-lock.json',
                    'node_modules/argparse/argparse.js',
                    'node_modules/js-yaml/index.js',
                    'tools/New-Package.ps1',
                    'tools/Test-ReleaseReadiness.ps1'
                )) {
                Test-Path -LiteralPath (Join-Path -Path $bundleRoot -ChildPath $expectedBundleFile) -PathType Leaf | Should -BeTrue
            }

            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            & $testBundleScript -BundleRoot $bundleRoot
            $LASTEXITCODE | Should -Be 0

            Push-Location -LiteralPath $bundleRoot
            try {
                & '.\src\tools\Test-Bundle.ps1' -BundleRoot '.'
                $LASTEXITCODE | Should -Be 0
            } finally {
                Pop-Location
            }
        } finally {
        }
    }

    It -Name 'New-Package builds validates and returns the bundle ZIP path' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $packageScript = Join-Path -Path $script:bundleSourceRoot -ChildPath 'tools/New-Package.ps1'
            $packageOutput = @(& $packageScript -RepositoryRoot $script:bundleSourceRoot -OutputPath $script:bundleOutputRoot -Version '0.1.0')
            $LASTEXITCODE | Should -Be 0

            $zipPath = Join-Path -Path $script:bundleOutputRoot -ChildPath 'ProStateKit-0.1.0.zip'
            $checksumPath = '{0}.sha256' -f $zipPath
            $releaseManifestPath = Join-Path -Path $script:bundleOutputRoot -ChildPath 'bundle.manifest.json'
            $packageOutput[-1] | Should -Be $zipPath
            Test-Path -LiteralPath $zipPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $checksumPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $releaseManifestPath -PathType Leaf | Should -BeTrue

            $bundleRoot = Join-Path -Path $script:bundleOutputRoot -ChildPath 'ProStateKit-0.1.0'
            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            & $testBundleScript -BundleRoot $bundleRoot
            $LASTEXITCODE | Should -Be 0
        } finally {
        }
    }

    It -Name 'Primary entry point validates a built bundle in ValidateBundle mode' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $entryPoint = Join-Path -Path $bundleRoot -ChildPath 'src/Invoke-ProStateKit.ps1'
            $pwshPath = (Get-Process -Id $PID).Path

            $output = & $pwshPath `
                -NoProfile `
                -File $entryPoint `
                -Mode ValidateBundle `
                -Plane Local `
                -BundleRoot $bundleRoot
            $LASTEXITCODE | Should -Be 0
            ($output -join "`n") | Should -Match 'Bundle validation completed successfully.'
        } finally {
        }
    }

    It -Name 'New-Package fails when post-build bundle validation fails' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $testBundleScript = Join-Path -Path $script:bundleSourceRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            Set-Content -LiteralPath $testBundleScript -Encoding utf8 -Value @'
[CmdletBinding()]
param(
    [string] $BundleRoot,

    [string] $ManifestPath = (Join-Path -Path $BundleRoot -ChildPath 'bundle.manifest.json')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

throw [System.InvalidOperationException]::new('Synthetic package validation failure.')
'@

            $message = ''
            $packageScript = Join-Path -Path $script:bundleSourceRoot -ChildPath 'tools/New-Package.ps1'
            try {
                & $packageScript -RepositoryRoot $script:bundleSourceRoot -OutputPath $script:bundleOutputRoot -Version '0.1.0'
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Synthetic package validation failure'
        } finally {
        }
    }

    It -Name 'Build-Bundle removes stale same-version artifacts before fail-closed runtime checks' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $null = Invoke-ProStateKitBundleBuildForTest

            $zipPath = Join-Path -Path $script:bundleOutputRoot -ChildPath 'ProStateKit-0.1.0.zip'
            $checksumPath = '{0}.sha256' -f $zipPath
            $releaseManifestPath = Join-Path -Path $script:bundleOutputRoot -ChildPath 'bundle.manifest.json'
            $bundleRoot = Join-Path -Path $script:bundleOutputRoot -ChildPath 'ProStateKit-0.1.0'
            Test-Path -LiteralPath $zipPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $checksumPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $releaseManifestPath -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath $bundleRoot -PathType Container | Should -BeTrue

            Remove-Item -LiteralPath $script:bundleRuntimePath -Force
            $buildScript = Join-Path -Path $script:bundleSourceRoot -ChildPath 'tools/Build-Bundle.ps1'
            $message = ''
            try {
                & $buildScript -RepositoryRoot $script:bundleSourceRoot -OutputPath $script:bundleOutputRoot -Version '0.1.0'
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'place the reviewed pinned DSC runtime'
            Test-Path -LiteralPath $zipPath | Should -BeFalse
            Test-Path -LiteralPath $checksumPath | Should -BeFalse
            Test-Path -LiteralPath $releaseManifestPath | Should -BeFalse
            Test-Path -LiteralPath $bundleRoot | Should -BeFalse
        } finally {
        }
    }

    It -Name 'Test-Bundle fails closed when a required bundle file is missing' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $manifestPath = Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $manifest.files = @($manifest.files | Where-Object -FilterScript { $_.path -ne 'tools/New-Package.ps1' })
            Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 20) -Encoding utf8
            Remove-Item -LiteralPath (Join-Path -Path $bundleRoot -ChildPath 'tools/New-Package.ps1') -Force

            $message = ''
            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            try {
                & $testBundleScript -BundleRoot $bundleRoot
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Required bundle file was not found'
        } finally {
        }
    }

    It -Name 'Test-Bundle fails closed when a required file is not hash-covered' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $manifestPath = Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $manifest.files = @($manifest.files | Where-Object -FilterScript { $_.path -ne 'tools/New-Package.ps1' })
            Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 20) -Encoding utf8

            $message = ''
            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            try {
                & $testBundleScript -BundleRoot $bundleRoot
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Required bundle file is not covered by manifest hashes'
        } finally {
        }
    }

    It -Name 'Test-Bundle fails closed when an extra bundle file is not hash-covered' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            Set-Content -LiteralPath (Join-Path -Path $bundleRoot -ChildPath 'untracked-extra.txt') -Value 'not in manifest' -Encoding utf8

            $message = ''
            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            try {
                & $testBundleScript -BundleRoot $bundleRoot
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Bundle file is not covered by manifest hashes: untracked-extra.txt'
        } finally {
        }
    }

    It -Name 'Test-Bundle fails closed when manifest file paths are duplicated' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $manifestPath = Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $manifest.files += @($manifest.files | Where-Object -FilterScript { $_.path -eq 'tools/New-Package.ps1' })[0]
            Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 20) -Encoding utf8

            $message = ''
            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            try {
                & $testBundleScript -BundleRoot $bundleRoot
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Bundle manifest contains duplicate file paths: tools/New-Package.ps1'
        } finally {
        }
    }

    It -Name 'Test-Bundle rejects manifest file paths that escape BundleRoot' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $manifestPath = Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $manifest.files += [pscustomobject]@{
                path = '../outside.txt'
                sha256 = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
            }
            Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 20) -Encoding utf8

            $message = ''
            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            try {
                & $testBundleScript -BundleRoot $bundleRoot
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Bundle path escaped BundleRoot'
        } finally {
        }
    }

    It -Name 'Test-Bundle rejects symlinked bundle files' -Test {
        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $outsidePath = Join-Path -Path $script:bundleTempRoot -ChildPath 'outside-package.ps1'
            $packagePath = Join-Path -Path $bundleRoot -ChildPath 'tools/New-Package.ps1'
            Copy-Item -LiteralPath $packagePath -Destination $outsidePath -Force
            Remove-Item -LiteralPath $packagePath -Force
            try {
                [void] (New-Item -ItemType SymbolicLink -Path $packagePath -Target $outsidePath -ErrorAction Stop)
            } catch {
                Set-ItResult -Skipped -Because ('Symlink creation is unavailable in this environment: {0}' -f $_.Exception.Message)
                return
            }

            $message = ''
            $testBundleScript = Join-Path -Path $bundleRoot -ChildPath 'src/tools/Test-Bundle.ps1'
            try {
                & $testBundleScript -BundleRoot $bundleRoot
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Bundle path must not contain symlink'
        } finally {
        }
    }

    It -Name 'Runner fails closed when manifest runtime hash does not match' -Test {
        $runId = 'runtime-manifest-{0}' -f ([guid]::NewGuid().ToString('N'))
        $evidenceRoot = Join-Path -Path $script:bundleTempRoot -ChildPath 'runtime-manifest-evidence'
        $pwshPath = (Get-Process -Id $PID).Path

        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $manifestPath = Join-Path -Path $bundleRoot -ChildPath 'bundle.manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $manifest.runtime.expectedHash = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
            Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 20) -Encoding utf8

            $runnerPath = Join-Path -Path $bundleRoot -ChildPath 'src/runner/Runner.ps1'
            $configPath = Join-Path -Path $bundleRoot -ChildPath 'configs/baseline.dsc.yaml'
            & $pwshPath `
                -NoProfile `
                -File $runnerPath `
                -Mode Detect `
                -ConfigPath $configPath `
                -BundleRoot $bundleRoot `
                -LogRoot $evidenceRoot `
                -RunId $runId `
                -RuntimeMode PinnedBundle
            $LASTEXITCODE | Should -Be 2

            $resultPath = Join-Path -Path $evidenceRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath (Join-Path -Path $runId -ChildPath 'wrapper.result.json'))
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $result.errors[0] | Should -Match 'Runtime hash mismatch'
        } finally {
        }
    }

    It -Name 'Preflight enforces InstalledPath runtime hash policy' -Test {
        $evidenceRoot = Join-Path -Path $script:bundleTempRoot -ChildPath 'preflight-policy-evidence'
        $operationId = 'preflight-policy'

        try {
            Initialize-ProStateKitFakeRuntimeForTest
            $bundleRoot = Invoke-ProStateKitBundleBuildForTest
            $runtimePath = Join-Path -Path $bundleRoot -ChildPath (Join-Path -Path 'runtime/dsc' -ChildPath $script:bundleDscExeName)
            $entryPoint = Join-Path -Path $bundleRoot -ChildPath 'src/Invoke-ProStateKit.ps1'

            & $entryPoint `
                -Mode Preflight `
                -Plane Local `
                -ConfigPath 'configs/baseline.dsc.yaml' `
                -RuntimeMode InstalledPath `
                -RuntimePath $runtimePath `
                -RuntimeExpectedHash 'sha256:0000000000000000000000000000000000000000000000000000000000000000' `
                -RuntimeExpectedVersion '3.2.0-test' `
                -EvidenceRoot $evidenceRoot `
                -OperationId $operationId `
                -BundleRoot $bundleRoot
            $LASTEXITCODE | Should -Be 1

            $reportPath = Join-Path -Path $evidenceRoot -ChildPath (Join-Path -Path 'Preflight' -ChildPath (Join-Path -Path $operationId -ChildPath 'preflight.report.json'))
            $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
            $report.succeeded | Should -BeFalse
            @($report.steps)[-1].name | Should -Be 'Prerequisites'
            @($report.steps)[-1].message | Should -Match 'InstalledPath runtime hash mismatch'
        } finally {
        }
    }

    It -Name 'Runs full local preflight against a bundle with a fake pinned runtime' -Test {
        $markerPath = Join-Path -Path $script:bundleTempRoot -ChildPath 'baseline-applied.txt'
        $evidenceRoot = Join-Path -Path $script:bundleTempRoot -ChildPath 'evidence'
        $operationId = 'preflight-success'

        try {
            Set-Content -LiteralPath $markerPath -Value 'present' -Encoding utf8
            [void] (New-Item -Path (Split-Path -Path $script:bundleRuntimePath -Parent) -ItemType Directory -Force)
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                Copy-ProStateKitTestFakeRuntime -DestinationPath $script:bundleRuntimePath
                $env:PROSTATEKIT_TEST_FAKE_DSC_MARKER = $markerPath
            } else {
                Set-Content -LiteralPath $script:bundleRuntimePath -Encoding utf8 -Value @"
#!/bin/sh
if [ "`$1" = "--version" ]; then
  echo "3.2.0-test"
  exit 0
fi
if [ "`$2" = "set" ]; then
  printf '%s\n' present > "$markerPath"
  printf '%s\n' '{"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":true,"error":null,"rebootRequired":false}]}'
  exit 0
fi
if [ -f "$markerPath" ]; then
  printf '%s\n' '{"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":true,"changed":false,"error":null,"rebootRequired":false}]}'
else
  printf '%s\n' '{"resources":[{"name":"Fake resource","type":"ProStateKit/Fake","succeeded":false,"changed":false,"error":"Synthetic drift fixture","rebootRequired":false}]}'
fi
exit 0
"@
                & chmod +x $script:bundleRuntimePath
            }

            $buildScript = Join-Path -Path $script:bundleSourceRoot -ChildPath 'tools/Build-Bundle.ps1'
            & $buildScript -RepositoryRoot $script:bundleSourceRoot -OutputPath $script:bundleOutputRoot -Version '0.1.0'
            $LASTEXITCODE | Should -Be 0

            $bundleRoot = Join-Path -Path $script:bundleOutputRoot -ChildPath 'ProStateKit-0.1.0'
            Push-Location -LiteralPath $bundleRoot
            try {
                & '.\planes\local\Invoke-LocalPreflight.ps1' `
                    -BundleRoot '.' `
                    -RuntimeMode PinnedBundle `
                    -EvidenceRoot $evidenceRoot `
                    -OperationId $operationId `
                    -DemoMarkerPath $markerPath
                $LASTEXITCODE | Should -Be 0
            } finally {
                Pop-Location
            }

            $reportPath = Join-Path -Path $evidenceRoot -ChildPath (Join-Path -Path 'Preflight' -ChildPath (Join-Path -Path $operationId -ChildPath 'preflight.report.json'))
            $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
            $report.succeeded | Should -BeTrue
            @($report.steps | Where-Object -FilterScript { -not $_.succeeded }).Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath Env:\PROSTATEKIT_TEST_FAKE_DSC_MARKER -ErrorAction SilentlyContinue
        }
    }
}

Describe -Name 'Configuration hygiene' -Fixture {
    It -Name 'Baseline configs do not contain obvious secret-shaped tokens' -Test {
        $configPaths = @(
            Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.yaml'
            Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.json'
            Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
            Join-Path -Path $script:repoRoot -ChildPath 'configs/generated/baseline.dsc.json'
        )
        $pattern = '(?i)(password|secret|apikey|api_key|token|bearer|clientsecret|connectionstring)'

        foreach ($configPath in $configPaths) {
            $content = Get-Content -LiteralPath $configPath -Raw
            $content | Should -Not -Match $pattern
        }
    }

    It -Name 'Authored baseline YAML files keep lab-use review warnings' -Test {
        $configPaths = @(
            Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.yaml'
            Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
        )
        $requiredTerms = @(
            'lab use only',
            'Review resource types, property names, and desired state before any production use.'
        )

        foreach ($configPath in $configPaths) {
            $content = Get-Content -LiteralPath $configPath -Raw
            foreach ($requiredTerm in $requiredTerms) {
                $content | Should -Match ([regex]::Escape($requiredTerm)) -Because $configPath
            }
        }
    }

    It -Name 'Authored baseline YAML files declare required DSC v3 schema and version directive' -Test {
        $configPaths = @(
            Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.yaml'
            Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
        )
        $requiredTerms = @(
            '$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json',
            'directives:',
            "version: '=3.2.0'"
        )

        foreach ($configPath in $configPaths) {
            $content = Get-Content -LiteralPath $configPath -Raw
            foreach ($requiredTerm in $requiredTerms) {
                $content | Should -Match ([regex]::Escape($requiredTerm)) -Because $configPath
            }
        }
    }

    It -Name 'Baseline configs do not retain placeholder markers' -Test {
        $configPaths = @(
            Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.yaml'
            Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.json'
            Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
            Join-Path -Path $script:repoRoot -ChildPath 'configs/generated/baseline.dsc.json'
        )

        foreach ($configPath in $configPaths) {
            $content = Get-Content -LiteralPath $configPath -Raw
            $content | Should -Not -Match '(?i)\b(TODO|TBD)\b' -Because $configPath
        }
    }

    It -Name 'Baseline DSC resource names satisfy DSC schema-safe pattern' -Test {
        $configPath = Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $resources = @($config.resources)

        $resources | Should -Not -BeNullOrEmpty
        foreach ($resource in $resources) {
            $resource.name | Should -Match '^[a-zA-Z0-9 ]+$' -Because $resource.name
            if ($resource.properties.PSObject.Properties.Name -contains 'resources') {
                foreach ($nestedResource in @($resource.properties.resources)) {
                    $nestedResource.name | Should -Match '^[a-zA-Z0-9 ]+$' -Because $nestedResource.name
                }
            }
        }
    }

    It -Name 'Baseline uses DSC 3.2 listed resource types at the top level' -Test {
        $configPath = Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $resources = @($config.resources)
        $resourceTypes = @($resources | ForEach-Object -Process { $_.type })

        $resources | Should -Not -BeNullOrEmpty
        $resourceTypes | Should -Contain 'Microsoft.Windows/WindowsPowerShell'
        $resourceTypes | Should -Contain 'Microsoft.Windows/Registry'
        $resourceTypes | Should -Not -Contain 'PSDesiredStateConfiguration/Group'
        $resourceTypes | Should -Not -Contain 'PSDesiredStateConfiguration/File'

        $adapter = @($resources | Where-Object -FilterScript { $_.type -eq 'Microsoft.Windows/WindowsPowerShell' })[0]
        $registry = @($resources | Where-Object -FilterScript { $_.type -eq 'Microsoft.Windows/Registry' })[0]

        $adapter.requireVersion | Should -Be '=0.1.0'
        $registry.requireVersion | Should -Be '=1.0.0'
        @($adapter.properties.resources | ForEach-Object -Process { $_.type }) |
            Should -Contain 'PSDesiredStateConfiguration/Group'
        @($adapter.properties.resources | ForEach-Object -Process { $_.type }) |
            Should -Contain 'PSDesiredStateConfiguration/File'
    }

    It -Name 'Sample evidence does not contain secret-shaped or environment-specific tokens' -Test {
        $evidenceRoot = Join-Path -Path $script:repoRoot -ChildPath 'evidence/sample'
        $blockedPatterns = @(
            '(?i)(password|passwd|secret|apikey|api[_-]?key|token|bearer|clientsecret|connectionstring)',
            '(?i)(tenant|customer|username|userName|machine|computer)',
            '(?i)(contoso|example\.com)',
            '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
        )

        foreach ($evidenceFile in Get-ChildItem -LiteralPath $evidenceRoot -File -Recurse) {
            $content = Get-Content -LiteralPath $evidenceFile.FullName -Raw
            foreach ($blockedPattern in $blockedPatterns) {
                $content | Should -Not -Match $blockedPattern -Because ('{0} must stay synthetic and sanitized' -f $evidenceFile.FullName)
            }
        }
    }

    It -Name 'Checked-in JSON mirrors are synchronized with authored YAML' -Test {
        $converterPath = Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Convert-ConfigYamlToJson.ps1'
        $configPairs = @(
            @{
                Name = 'bundle baseline'
                SourceYamlPath = Join-Path -Path $script:repoRoot -ChildPath 'configs/baseline.dsc.yaml'
                CheckedInJsonPath = Join-Path -Path $script:repoRoot -ChildPath 'configs/generated/baseline.dsc.json'
            }
            @{
                Name = 'source baseline'
                SourceYamlPath = Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.yaml'
                CheckedInJsonPath = Join-Path -Path $script:repoRoot -ChildPath 'src/configs/baseline.windows.json'
            }
        )

        foreach ($configPair in $configPairs) {
            $runId = 'config-convert-{0}' -f ([guid]::NewGuid().ToString('N'))
            $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $runId
            $generatedJsonPath = Join-Path -Path $tempRoot -ChildPath (Split-Path -Path $configPair.CheckedInJsonPath -Leaf)

            try {
                [void] (New-Item -Path $tempRoot -ItemType Directory -Force)
                & $converterPath -SourcePath $configPair.SourceYamlPath -DestinationPath $generatedJsonPath | Out-Null
                $LASTEXITCODE | Should -Be 0

                $generated = (Get-Content -LiteralPath $generatedJsonPath -Raw) -replace "`r`n?", "`n"
                $checkedIn = (Get-Content -LiteralPath $configPair.CheckedInJsonPath -Raw) -replace "`r`n?", "`n"
                $generated | Should -Be $checkedIn -Because $configPair.Name
            } finally {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It -Name 'Packaged runtime PowerShell paths do not perform live downloads or enable DSC trace' -Test {
        $runtimeRoots = @(
            Join-Path -Path $script:repoRoot -ChildPath 'planes'
            Join-Path -Path $script:repoRoot -ChildPath 'src'
            Join-Path -Path $script:repoRoot -ChildPath 'tools'
        )
        $blockedPatterns = @(
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'Start-BitsTransfer',
            'DownloadFile',
            'DownloadString',
            'System\.Net\.WebClient',
            'HttpClient',
            '\bcurl\b',
            '\bwget\b',
            '--trace\b',
            'trace-level'
        )

        foreach ($runtimeRoot in $runtimeRoots) {
            foreach ($scriptPath in Get-ChildItem -LiteralPath $runtimeRoot -Include '*.ps1', '*.psm1' -Recurse -File) {
                $content = Get-Content -LiteralPath $scriptPath.FullName -Raw
                foreach ($blockedPattern in $blockedPatterns) {
                    $content | Should -Not -Match $blockedPattern -Because ('{0} must not contain {1}' -f $scriptPath.FullName, $blockedPattern)
                }
            }
        }
    }
}

Describe -Name 'Documentation path consistency' -Fixture {
    It -Name 'Contract and packaging docs reference actual scaffold paths' -Test {
        $contractPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/contract.md'
        $packagingPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/packaging.md'
        $contract = Get-Content -LiteralPath $contractPath -Raw
        $packaging = Get-Content -LiteralPath $packagingPath -Raw

        $contract | Should -Match ([regex]::Escape('src/runner/Runner.ps1'))
        $contract | Should -Match ([regex]::Escape('The public entry point supports `Detect`, `Remediate`, `ValidateBundle`, and `Preflight`.'))
        $contract | Should -Match ([regex]::Escape('`ValidateBundle` runs [src/tools/Test-Bundle.ps1](../src/tools/Test-Bundle.ps1) against the selected bundle root.'))
        $contract | Should -Match ([regex]::Escape('`Preflight` runs bundle validation, prerequisite checks, known-good Detect, deterministic drift, Remediate, and final Detect.'))
        $packaging | Should -Match ([regex]::Escape('src/'))
        $packaging | Should -Match ([regex]::Escape('planes/'))
        $packaging | Should -Match ([regex]::Escape('[tools/New-Package.ps1](../tools/New-Package.ps1) runs bundle validation before returning success.'))
        $packaging | Should -Match ([regex]::Escape('validate the staged bundle with `tools/Test-Bundle.ps1`'))
        $packaging | Should -Match ([regex]::Escape('duplicate manifest paths, untracked bundle files'))
        $packaging | Should -Match ([regex]::Escape('.github/scripts/      (selected Markdown validation helpers only)'))
        $packaging | Should -Match ([regex]::Escape('Maintainer-only review helpers such as `.github/scripts/Save-DscRuntimeCandidate.ps1` stay source-only and are not included in endpoint bundles.'))
        Test-Path -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'src/runner/Runner.ps1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'src/tools/New-Package.ps1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'src/Invoke-ProStateKit.ps1') | Should -BeTrue
    }

    It -Name 'Evidence schema documentation sample validates against the wrapper schema' -Test {
        $schemaPath = Join-Path -Path $script:repoRoot -ChildPath 'schemas/wrapper-result.schema.json'
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        $samples = @(
            @{
                Path = Join-Path -Path $script:repoRoot -ChildPath 'docs/evidence-schema.md'
                Pattern = '(?s)## Sample\s+```json\s+(?<json>.*?)\s+```'
            }
            @{
                Path = Join-Path -Path $script:repoRoot -ChildPath 'docs/spec/ProStateKit.md'
                Pattern = '(?s)## Normalized Result Schema.*?```json\s+(?<json>.*?)\s+```'
            }
        )

        foreach ($sample in $samples) {
            $doc = Get-Content -LiteralPath $sample.Path -Raw
            $sampleMatch = [regex]::Match($doc, $sample.Pattern)

            $sampleMatch.Success | Should -BeTrue -Because $sample.Path
            Test-Json -Json $sampleMatch.Groups['json'].Value -Schema $schema |
                Should -BeTrue -Because $sample.Path
        }
    }
}

Describe -Name 'Workflow guardrails' -Fixture {
    It -Name 'Validate workflow runs full repository validation and pre-commit gates' -Test {
        $workflowPath = Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/validate.yml'
        $workflow = Get-Content -LiteralPath $workflowPath -Raw
        $requiredTerms = @(
            'name: Validate',
            'permissions:',
            'contents: read',
            'push:',
            'pull_request:',
            'workflow_dispatch:',
            'actions/checkout@v6',
            'actions/setup-node@v6',
            'node-version: "20"',
            'npm ci --ignore-scripts',
            'actions/setup-python@v6',
            'python -m pip install pre-commit',
            'Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser',
            'Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser',
            'npm run validate -- -SkipPreCommit',
            'pre-commit run --all-files'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $workflow | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Bundle workflow covers bundle-affecting paths and fails closed without runtime' -Test {
        $workflowPath = Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/build-bundle.yml'
        $workflow = Get-Content -LiteralPath $workflowPath -Raw
        $requiredTerms = @(
            'name: Build Bundle',
            'push:',
            'pull_request:',
            'workflow_dispatch:',
            'configs/**',
            'runtime/**',
            'resources/**',
            'src/**',
            'tools/**',
            'bundle.manifest.template.json',
            'windows-latest',
            'actions/setup-node@v6',
            'node-version: "20"',
            'npm ci --ignore-scripts',
            'runtime/dsc/dsc.exe',
            './tools/Build-Bundle.ps1 -OutputPath $outputPath',
            'Build-Bundle.ps1 failed even though a pinned runtime exists.',
            'Build-Bundle.ps1 did not produce a ZIP artifact.',
            'Build-Bundle.ps1 did not produce bundle.manifest.json.',
            'Build-Bundle.ps1 did not produce a SHA-256 checksum artifact.',
            './tools/Test-Bundle.ps1 -BundleRoot $bundleRoot',
            'Test-Bundle.ps1 failed for the built bundle.',
            'Build-Bundle.ps1 succeeded without a pinned runtime.',
            'Build-Bundle.ps1 emitted artifacts without a pinned runtime.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $workflow | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Fixture compatibility workflow runs schema and Pester fixture checks on push PR schedule and dispatch' -Test {
        $workflowPath = Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/fixture-compat.yml'
        $workflow = Get-Content -LiteralPath $workflowPath -Raw
        $requiredTerms = @(
            'name: Fixture Compatibility',
            'push:',
            'pull_request:',
            'schedule:',
            'cron: "23 10 * * 1"',
            'workflow_dispatch:',
            'evidence/**',
            'schemas/**',
            'src/**',
            'tests/**',
            'actions/setup-node@v6',
            'node-version: "20"',
            'npm ci --ignore-scripts',
            'Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser',
            './src/tools/Invoke-SchemaLint.ps1',
            'Invoke-Pester -Path tests/PowerShell -Output Detailed -PassThru',
            'if ($result.FailedCount -gt 0)',
            'exit 1'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $workflow | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'PowerShell CI keeps analyzer and cross-platform Pester gates' -Test {
        $workflowPath = Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/powershell-ci.yml'
        $workflow = Get-Content -LiteralPath $workflowPath -Raw
        $requiredTerms = @(
            'name: PowerShell CI',
            'push:',
            'pull_request:',
            'workflow_dispatch:',
            'PSScriptAnalyzerSettings.psd1',
            'Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser',
            './src/tools/Invoke-PSScriptAnalyzer.ps1',
            'os: [ubuntu-latest, windows-latest, macos-latest]',
            'Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser',
            '$config.Run.Path = "tests/"',
            '$config.Run.Exit = $true',
            '$config.TestResult.Enabled = $true',
            '$config.Output.Verbosity = "Detailed"',
            'Invoke-Pester -Configuration $config'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $workflow | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Release workflow remains manual and fail-closed while runtime is unpinned' -Test {
        $releaseWorkflowPath = Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/release.yml'
        $specPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/spec/ProStateKit.md'
        $releaseWorkflow = Get-Content -LiteralPath $releaseWorkflowPath -Raw
        $spec = Get-Content -LiteralPath $specPath -Raw

        $releaseWorkflow | Should -Match '(?m)^\s*workflow_dispatch:\s*$'
        $releaseWorkflow | Should -Not -Match '(?m)^\s*(push|release):\s*$'
        $releaseWorkflow | Should -Not -Match '(?i)(create-release|upload-release|action-gh-release|gh release|upload-artifact)'
        $releaseWorkflow | Should -Match 'Release publishing is disabled'
        $spec | Should -Not -Match '\| `release\.yml` \| Version tag \|'
        $spec | Should -Match '\| `release\.yml` \| Manual dispatch fail-closed guard only \|'
    }
}

Describe -Name 'Plane shim guardrails' -Fixture {
    It -Name 'Plane shims are marked preview and route through the common entry point or runner' -Test {
        $shimExpectations = @(
            @{
                Path = 'planes/intune/Detect-ProStateKit.ps1'
                RequiredCall = 'src/Invoke-ProStateKit.ps1'
                Plane = 'Intune'
                Mode = 'Detect'
            }
            @{
                Path = 'planes/intune/Remediate-ProStateKit.ps1'
                RequiredCall = 'src/Invoke-ProStateKit.ps1'
                Plane = 'Intune'
                Mode = 'Remediate'
            }
            @{
                Path = 'planes/configmgr/Discover-ProStateKit.ps1'
                RequiredCall = 'src/Invoke-ProStateKit.ps1'
                Plane = 'ConfigMgr'
                Mode = 'Detect'
            }
            @{
                Path = 'planes/configmgr/Remediate-ProStateKit.ps1'
                RequiredCall = 'src/Invoke-ProStateKit.ps1'
                Plane = 'ConfigMgr'
                Mode = 'Remediate'
            }
            @{
                Path = 'planes/local/Invoke-LocalPreflight.ps1'
                RequiredCall = 'src/Invoke-ProStateKit.ps1'
                Plane = 'Local'
                Mode = 'Preflight'
            }
            @{
                Path = 'src/runner/Intune/Detect.ps1'
                RequiredCall = 'Runner.ps1'
                Plane = 'Intune'
                Mode = 'Detect'
            }
            @{
                Path = 'src/runner/Intune/Remediate.ps1'
                RequiredCall = 'Runner.ps1'
                Plane = 'Intune'
                Mode = 'Remediate'
            }
            @{
                Path = 'src/runner/ConfigMgr/Runner.ps1'
                RequiredCall = 'Runner.ps1'
                Plane = 'ConfigMgr'
                Mode = $null
            }
        )

        foreach ($shim in $shimExpectations) {
            $shimPath = Join-Path -Path $script:repoRoot -ChildPath $shim.Path
            $content = Get-Content -LiteralPath $shimPath -Raw

            $content | Should -Match '(?m)^# Preview scaffold' -Because $shim.Path
            $content | Should -Match 'Production behavior requires the final pinned bundle' -Because $shim.Path
            $content | Should -Match ([regex]::Escape($shim.RequiredCall)) -Because $shim.Path
            $content | Should -Match ("-Plane '{0}'" -f $shim.Plane) -Because $shim.Path
            if ($null -ne $shim.Mode) {
                $content | Should -Match ("-Mode '{0}'" -f $shim.Mode) -Because $shim.Path
            }
        }
    }

    It -Name 'Production plane shims use pinned bundle runtime and do not allow LabLatest' -Test {
        foreach ($shimPath in @(
                'planes/intune/Detect-ProStateKit.ps1',
                'planes/intune/Remediate-ProStateKit.ps1',
                'planes/configmgr/Discover-ProStateKit.ps1',
                'planes/configmgr/Remediate-ProStateKit.ps1'
            )) {
            $content = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath $shimPath) -Raw

            $content | Should -Match "-RuntimeMode 'PinnedBundle'" -Because $shimPath
            $content | Should -Not -Match 'LabLatest' -Because $shimPath
            $content | Should -Not -Match 'AllowLabLatest' -Because $shimPath
        }
    }
}

Describe -Name 'Initialization guardrails' -Fixture {
    It -Name 'Post-public TODO retains all deferred public-flip tasks' -Test {
        $todoPath = Join-Path -Path $script:repoRoot -ChildPath '_TODO.md'
        $todo = Get-Content -LiteralPath $todoPath -Raw
        $expectedItems = @(
            '- [ ] Change repository visibility from Private to Public.',
            '- [ ] Enable Private Vulnerability Reporting (Settings -> Security -> Private vulnerability reporting).',
            '- [ ] Replace private-staging security reporting text in `SECURITY.md` with PVR instructions and the advisory submission URL.',
            '- [ ] Update `.github/ISSUE_TEMPLATE/config.yml` security URL to `https://github.com/franklesniak/ProStateKit/security/advisories/new`.',
            '- [ ] Replace private-staging Code of Conduct reporting text in `CODE_OF_CONDUCT.md` with the final public contact method.',
            '- [ ] Confirm the Discussions link in `.github/ISSUE_TEMPLATE/config.yml` resolves.',
            '- [ ] Configure branch protection on `main` once workflow names and required checks have stabilized:',
            '- [ ] Pin the DSC version in `README.md`, `docs/contract.md`, sample manifests, and any deck references.',
            '- [ ] Run a dry release through `Tools/New-Package.ps1` after packaging is implemented and confirm `bundle.manifest.json` and SHA-256 checksum file are produced.',
            '- [ ] Add or enable the tag-triggered release workflow once `Tools/New-Package.ps1` produces real artifacts.',
            '- [ ] Remove this `_TODO.md` file.'
        )

        Test-Path -LiteralPath $todoPath -PathType Leaf | Should -BeTrue
        foreach ($expectedItem in $expectedItems) {
            $todo | Should -Match ([regex]::Escape($expectedItem))
        }
        @([regex]::Matches($todo, '(?m)^- \[ \] ')).Count | Should -Be $expectedItems.Count
    }

    It -Name 'Repository text does not contain forbidden template or fake-hash markers' -Test {
        $forbiddenMarkers = @(
            'OWNER' + '/REPO',
            '@' + 'OWNER',
            '[INSERT CONTACT ' + 'METHOD]',
            '[security contact ' + 'email]',
            'copilot' + '-repo-template',
            'copilot' + '_repo_template',
            'my' + '-new-project',
            'your' + '-repo-name',
            'sha256' + '-placeholder'
        )
        $excludedDirectoryPattern = '[\\/](\.git|node_modules|\.pre-commit-cache|\.npm-cache|\.pip-cache)[\\/]'

        foreach ($file in Get-ChildItem -LiteralPath $script:repoRoot -File -Recurse -Force) {
            if ($file.FullName -match $excludedDirectoryPattern) {
                continue
            }

            $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($null -eq $content) {
                continue
            }

            foreach ($forbiddenMarker in $forbiddenMarkers) {
                $content | Should -Not -Match ([regex]::Escape($forbiddenMarker)) -Because $file.FullName
            }
        }
    }
}

Describe -Name 'External blocker tracking guardrails' -Fixture {
    It -Name 'Next-steps file records every blocker required before release or deck closure' -Test {
        $nextStepsPath = Join-Path -Path $script:repoRoot -ChildPath 'DSCv3-14a-next-steps.md'
        $nextSteps = Get-Content -LiteralPath $nextStepsPath -Raw
        $requiredTerms = @(
            'It intentionally does not ship a pinned DSC runtime or claim production readiness.',
            'Release packaging, lab proof, public repository settings, and final deck screenshots remain blocked until the external actions below are completed.',
            '[Completion Audit](docs/completion-audit.md)',
            'The current prompt-to-artifact and `_init-instructions.md` Step 1 through Step 27 mapping is tracked in [docs/completion-audit.md](docs/completion-audit.md).',
            'Keep that audit synchronized when blockers are closed or the objective scope changes.',
            'NEXT-001',
            'Select the pinned DSC release and place the reviewed executable under `runtime/dsc/`.',
            'Version, source URL, source hash, observed bundle hash, and reviewer sign-off recorded in docs and manifest.',
            'NEXT-002',
            'Run a dry release through `tools/New-Package.ps1`.',
            '`ProStateKit-<version>.zip`, `bundle.manifest.json`, and `.sha256` produced in a disposable output directory and verified by `Test-Bundle.ps1`.',
            'NEXT-003',
            'Complete public flip tasks in [_TODO.md](_TODO.md).',
            'Public visibility, Private Vulnerability Reporting, branch protection, final security URL, final Code of Conduct contact, and Discussions link verified.',
            'NEXT-004',
            'Rehearse the local runbook twice from a clean reset.',
            'Two timestamped evidence directories with known-good Detect, drift Detect, Remediate, final Detect, and reset notes.',
            'NEXT-005',
            'Validate final pinned bundle through Intune Remediations.',
            'Detection exit/output, remediation exit/output, evidence path, and portal screenshots sanitized and archived.',
            'NEXT-006',
            'Validate final pinned bundle through ConfigMgr compliance settings.',
            'Discovery output type, remediation behavior, unknown/failure handling, evidence path, and console screenshots sanitized and archived.',
            'NEXT-007',
            'Reconcile [DSCv3-14-deck-spec.md](DSCv3-14-deck-spec.md) with real repo commands and evidence.',
            'Slide notes updated with actual file names, commands, screenshots, evidence fields, and any caveats that remain.',
            'NEXT-008',
            'Decide whether any real secret-flow sample belongs in the repository.',
            'Current default remains no real secrets in demo configs, logs, prompts, raw evidence, normalized evidence, or samples.',
            'NEXT-009',
            'Recheck latest DSC release one week before deck freeze.',
            'Keep v3.2.0 or select a later stable release only after lab validation and docs updates.',
            'Use `tools/Test-ReleaseReadiness.ps1` for a fail-closed readiness report',
            'On the preview scaffold it is expected to return non-zero.',
            '## Pinned Runtime Candidate Evidence',
            '### NEXT-001 Reviewer Sign-Off Checklist',
            '[.github/scripts/Save-DscRuntimeCandidate.ps1](.github/scripts/Save-DscRuntimeCandidate.ps1) can re-download the selected asset into a disposable temp directory',
            'Candidate helper verification: 2026-05-03',
            'from its default current-user temp working root',
            'This verification is not reviewer sign-off and does not close NEXT-001.',
            'Confirm `v3.2.0` remains the intended pinned release, or replace this candidate before placement.',
            'disposable temp review directory, optionally with `.github/scripts/Save-DscRuntimeCandidate.ps1`',
            'Recompute and compare the source artifact SHA-256 before extraction.',
            'keep the full reviewed archive payload with `dsc.exe` under `runtime/dsc/`',
            'Run `runtime/dsc/dsc.exe --version` on the Windows lab endpoint and record the observed version.',
            'Run `tools/New-Package.ps1` with a disposable output path and verify `tools/Test-Bundle.ps1` passes for the staged bundle.',
            'Record reviewer name or handle, review date, selected version, release URL, source artifact hash, extracted runtime hash, and observed bundle manifest hash before closing NEXT-001.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $nextSteps | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Release readiness helper fails closed until external evidence exists' -Test {
        $readinessPath = Join-Path -Path $script:repoRoot -ChildPath 'tools/Test-ReleaseReadiness.ps1'
        $pwshPath = (Get-Process -Id $PID).Path

        $output = & $pwshPath -NoProfile -File $readinessPath -RepositoryRoot $script:repoRoot -OutputFormat Json
        $LASTEXITCODE | Should -Be 1

        $report = $output | ConvertFrom-Json
        $report.ready | Should -BeFalse
        $checkNames = @($report.checks.name)
        foreach ($expectedCheckName in @(
                'reviewed-pinned-runtime',
                'runtime-reviewer-signoff',
                'dry-release-artifacts',
                'local-demo-rehearsals',
                'intune-lab-validation',
                'configmgr-lab-validation',
                'public-flip-tasks',
                'deck-reconciled-to-real-evidence',
                'final-dsc-release-recheck'
            )) {
            $checkNames | Should -Contain $expectedCheckName
        }
    }

    It -Name 'Release readiness helper passes with synthetic external evidence' -Test {
        $readinessPath = Join-Path -Path $script:repoRoot -ChildPath 'tools/Test-ReleaseReadiness.ps1'
        $pwshPath = (Get-Process -Id $PID).Path
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('release-ready-{0}' -f ([guid]::NewGuid().ToString('N')))
        $fakeRepoRoot = Join-Path -Path $tempRoot -ChildPath 'repo'
        $releaseOutput = Join-Path -Path $tempRoot -ChildPath 'release'
        $releaseBundleRoot = Join-Path -Path $releaseOutput -ChildPath 'ProStateKit-0.1.0'
        $labEvidence = Join-Path -Path $tempRoot -ChildPath 'lab'
        $intuneEvidence = Join-Path -Path $tempRoot -ChildPath 'intune'
        $configMgrEvidence = Join-Path -Path $tempRoot -ChildPath 'configmgr'

        try {
            foreach ($path in @(
                    (Join-Path -Path $fakeRepoRoot -ChildPath 'src/tools'),
                    (Join-Path -Path $fakeRepoRoot -ChildPath 'runtime/dsc/lib'),
                    $releaseOutput,
                    (Join-Path -Path $releaseBundleRoot -ChildPath 'src/tools'),
                    (Join-Path -Path $labEvidence -ChildPath 'run-1'),
                    (Join-Path -Path $labEvidence -ChildPath 'run-2'),
                    $intuneEvidence,
                    $configMgrEvidence
                )) {
                [void] (New-Item -Path $path -ItemType Directory -Force)
            }

            Copy-Item `
                -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Test-ReleaseReadiness.ps1') `
                -Destination (Join-Path -Path $fakeRepoRoot -ChildPath 'src/tools/Test-ReleaseReadiness.ps1') `
                -Force

            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'runtime/dsc/dsc.exe') -Value 'synthetic runtime' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'runtime/dsc/lib/support.txt') -Value 'synthetic support' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'DSCv3-14a-next-steps.md') -Value @'
# Synthetic Next Steps

NEXT-001 reviewer sign-off complete.
NEXT-009 final DSC release recheck complete.
'@ -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'DSCv3-14-deck-spec.md') -Value '# Synthetic reconciled deck spec' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseOutput -ChildPath 'ProStateKit-0.1.0.zip') -Value 'synthetic zip marker' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseOutput -ChildPath 'ProStateKit-0.1.0.zip.sha256') -Value 'sha256:synthetic' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseOutput -ChildPath 'bundle.manifest.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseBundleRoot -ChildPath 'bundle.manifest.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseBundleRoot -ChildPath 'src/tools/Test-Bundle.ps1') -Value @'
[CmdletBinding()]
param(
    [string] $BundleRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$null = $BundleRoot
exit 0
'@ -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $labEvidence -ChildPath 'run-1/wrapper.result.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $labEvidence -ChildPath 'run-2/preflight.report.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $intuneEvidence -ChildPath 'intune-evidence.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $configMgrEvidence -ChildPath 'configmgr-evidence.json') -Value '{}' -Encoding utf8

            $output = & $pwshPath `
                -NoProfile `
                -File $readinessPath `
                -RepositoryRoot $fakeRepoRoot `
                -ReleaseOutputPath $releaseOutput `
                -LabEvidenceRoot $labEvidence `
                -IntuneEvidencePath $intuneEvidence `
                -ConfigMgrEvidencePath $configMgrEvidence `
                -OutputFormat Json
            $LASTEXITCODE | Should -Be 0

            $report = $output | ConvertFrom-Json
            $report.ready | Should -BeTrue
            @($report.checks | Where-Object -FilterScript { -not $_.passed }) | Should -BeNullOrEmpty
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Release readiness helper reports failed staged bundle validation' -Test {
        $readinessPath = Join-Path -Path $script:repoRoot -ChildPath 'tools/Test-ReleaseReadiness.ps1'
        $pwshPath = (Get-Process -Id $PID).Path
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('release-blocked-{0}' -f ([guid]::NewGuid().ToString('N')))
        $fakeRepoRoot = Join-Path -Path $tempRoot -ChildPath 'repo'
        $releaseOutput = Join-Path -Path $tempRoot -ChildPath 'release'
        $releaseBundleRoot = Join-Path -Path $releaseOutput -ChildPath 'ProStateKit-0.1.0'
        $labEvidence = Join-Path -Path $tempRoot -ChildPath 'lab'
        $intuneEvidence = Join-Path -Path $tempRoot -ChildPath 'intune'
        $configMgrEvidence = Join-Path -Path $tempRoot -ChildPath 'configmgr'

        try {
            foreach ($path in @(
                    (Join-Path -Path $fakeRepoRoot -ChildPath 'src/tools'),
                    (Join-Path -Path $fakeRepoRoot -ChildPath 'runtime/dsc/lib'),
                    (Join-Path -Path $releaseBundleRoot -ChildPath 'src/tools'),
                    (Join-Path -Path $labEvidence -ChildPath 'run-1'),
                    (Join-Path -Path $labEvidence -ChildPath 'run-2'),
                    $intuneEvidence,
                    $configMgrEvidence
                )) {
                [void] (New-Item -Path $path -ItemType Directory -Force)
            }

            Copy-Item `
                -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Test-ReleaseReadiness.ps1') `
                -Destination (Join-Path -Path $fakeRepoRoot -ChildPath 'src/tools/Test-ReleaseReadiness.ps1') `
                -Force

            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'runtime/dsc/dsc.exe') -Value 'synthetic runtime' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'runtime/dsc/lib/support.txt') -Value 'synthetic support' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'DSCv3-14a-next-steps.md') -Value @'
# Synthetic Next Steps

NEXT-001 reviewer sign-off complete.
NEXT-009 final DSC release recheck complete.
'@ -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $fakeRepoRoot -ChildPath 'DSCv3-14-deck-spec.md') -Value '# Synthetic reconciled deck spec' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseOutput -ChildPath 'ProStateKit-0.1.0.zip') -Value 'synthetic zip marker' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseOutput -ChildPath 'ProStateKit-0.1.0.zip.sha256') -Value 'sha256:synthetic' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseOutput -ChildPath 'bundle.manifest.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseBundleRoot -ChildPath 'bundle.manifest.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $releaseBundleRoot -ChildPath 'src/tools/Test-Bundle.ps1') -Value @'
[CmdletBinding()]
param(
    [string] $BundleRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$null = $BundleRoot
throw [System.InvalidOperationException]::new('Synthetic staged bundle validation failure.')
'@ -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $labEvidence -ChildPath 'run-1/wrapper.result.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $labEvidence -ChildPath 'run-2/preflight.report.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $intuneEvidence -ChildPath 'intune-evidence.json') -Value '{}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path -Path $configMgrEvidence -ChildPath 'configmgr-evidence.json') -Value '{}' -Encoding utf8

            $output = & $pwshPath `
                -NoProfile `
                -File $readinessPath `
                -RepositoryRoot $fakeRepoRoot `
                -ReleaseOutputPath $releaseOutput `
                -LabEvidenceRoot $labEvidence `
                -IntuneEvidencePath $intuneEvidence `
                -ConfigMgrEvidencePath $configMgrEvidence `
                -OutputFormat Json
            $LASTEXITCODE | Should -Be 1

            $report = $output | ConvertFrom-Json
            $report.ready | Should -BeFalse
            $dryReleaseCheck = @($report.checks | Where-Object -FilterScript { $_.name -eq 'dry-release-artifacts' })[0]
            $dryReleaseCheck.passed | Should -BeFalse
            $dryReleaseCheck.detail | Should -Match 'Synthetic staged bundle validation failure'
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It -Name 'Runtime candidate helper stays reviewer-scoped and hash-gated' -Test {
        $helperPath = Join-Path -Path $script:repoRoot -ChildPath '.github/scripts/Save-DscRuntimeCandidate.ps1'
        $helper = Get-Content -LiteralPath $helperPath -Raw
        $requiredTerms = @(
            '[uri] $AssetUrl',
            '[string] $ExpectedSourceSha256',
            '[string] $ExpectedRuntimeSha256',
            'AssetUrl must use HTTPS.',
            'AssetUrl must point to a PowerShell/DSC GitHub release asset.',
            'WorkingRoot must not be a filesystem root.',
            'WorkingRoot must resolve under the current user temp directory.',
            'WorkingRoot must be a disposable ProStateKit candidate directory.',
            'Expected SHA-256 values must be 64 hex characters',
            'Invoke-WebRequest -Uri $AssetUrl -OutFile $assetPath',
            'Downloaded DSC runtime asset hash did not match ExpectedSourceSha256.',
            'Expand-Archive -LiteralPath $assetPath -DestinationPath $extractRoot -Force',
            'Extracted runtime executable hash did not match ExpectedRuntimeSha256.',
            'Review the extracted files, then copy the full reviewed archive payload into runtime/dsc/ only after reviewer sign-off.'
        )

        Test-Path -LiteralPath $helperPath -PathType Leaf | Should -BeTrue
        foreach ($requiredTerm in $requiredTerms) {
            $helper | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Runtime candidate helper rejects unsafe working roots before download' -Test {
        $helperPath = Join-Path -Path $script:repoRoot -ChildPath '.github/scripts/Save-DscRuntimeCandidate.ps1'
        $rootPath = [System.IO.Path]::GetPathRoot((Get-Location).Path)
        $message = ''
        try {
            & $helperPath `
                -AssetUrl 'https://github.com/PowerShell/DSC/releases/download/v3.2.0/DSC-3.2.0-x86_64-pc-windows-msvc.zip' `
                -ExpectedSourceSha256 '0000000000000000000000000000000000000000000000000000000000000000' `
                -WorkingRoot $rootPath `
                -Force
        } catch {
            $message = $_.Exception.Message
        }

        $message | Should -Match 'WorkingRoot must not be a filesystem root.'
    }

    It -Name 'Runtime candidate helper rejects non-temp working roots before download' -Test {
        $helperPath = Join-Path -Path $script:repoRoot -ChildPath '.github/scripts/Save-DscRuntimeCandidate.ps1'
        $workingRoot = Join-Path -Path $script:repoRoot -ChildPath 'prostatekit-dsc-runtime-candidate-non-temp'
        $message = ''
        try {
            & $helperPath `
                -AssetUrl 'https://github.com/PowerShell/DSC/releases/download/v3.2.0/DSC-3.2.0-x86_64-pc-windows-msvc.zip' `
                -ExpectedSourceSha256 '0000000000000000000000000000000000000000000000000000000000000000' `
                -WorkingRoot $workingRoot `
                -Force
        } catch {
            $message = $_.Exception.Message
        } finally {
            Remove-Item -LiteralPath $workingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        $message | Should -Match 'WorkingRoot must resolve under the current user temp directory.'
        Test-Path -LiteralPath $workingRoot | Should -BeFalse
    }

    It -Name 'Runtime candidate helper rejects non-DSC release URLs before download' -Test {
        $helperPath = Join-Path -Path $script:repoRoot -ChildPath '.github/scripts/Save-DscRuntimeCandidate.ps1'
        $workingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'prostatekit-dsc-runtime-candidate-host-test'
        $message = ''
        try {
            & $helperPath `
                -AssetUrl 'https://example.invalid/DSC.zip' `
                -ExpectedSourceSha256 '0000000000000000000000000000000000000000000000000000000000000000' `
                -WorkingRoot $workingRoot `
                -Force
        } catch {
            $message = $_.Exception.Message
        } finally {
            Remove-Item -LiteralPath $workingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        $message | Should -Match 'AssetUrl must point to a PowerShell/DSC GitHub release asset.'
        Test-Path -LiteralPath $workingRoot | Should -BeFalse
    }

    It -Name 'Runtime candidate helper is not packaged into endpoint bundles' -Test {
        $helperRelativePath = '.github/scripts/Save-DscRuntimeCandidate.ps1'
        $buildScriptPath = Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Build-Bundle.ps1'
        $testBundlePath = Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Test-Bundle.ps1'
        $buildScript = Get-Content -LiteralPath $buildScriptPath -Raw
        $testBundle = Get-Content -LiteralPath $testBundlePath -Raw
        $runtimeDistribution = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'docs/runtime-distribution.md') -Raw

        Test-Path -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath $helperRelativePath) -PathType Leaf |
            Should -BeTrue
        $buildScript | Should -Not -Match ([regex]::Escape($helperRelativePath))
        $testBundle | Should -Not -Match ([regex]::Escape($helperRelativePath))
        $runtimeDistribution | Should -Match ([regex]::Escape('This helper is for maintainer review only and is not part of the endpoint runtime bundle.'))
    }

    It -Name 'Next-steps file keeps open questions and deck reconciliation cautions explicit' -Test {
        $nextStepsPath = Join-Path -Path $script:repoRoot -ChildPath 'DSCv3-14a-next-steps.md'
        $nextSteps = Get-Content -LiteralPath $nextStepsPath -Raw
        $requiredTerms = @(
            'Is the LLMNR registry example stable and visible enough for the live demo',
            'What exact ConfigMgr compliance discovery output and remediation behavior should ProStateKit document after lab validation?',
            'Should first public release artifacts require Authenticode signatures in addition to SHA-256 hashes?',
            'Should reboot marker cleanup be implemented as a Runner behavior, a plane-owned cleanup behavior, or a runbook-only lab step for the first public version?',
            'Should YAML parsing remain Node-backed for preview validation, or should the project adopt a reviewed PowerShell-native YAML parser before release packaging?',
            'Replace all [REPO] placeholders with actual paths from this repository.',
            'Replace all [LAB] placeholders with sanitized evidence from the final pinned bundle.',
            'Replace all [REHEARSAL] placeholders with screenshots and timing from two clean rehearsals.',
            'Keep slides about Intune and ConfigMgr cautious until the matching lab validation artifacts exist.',
            'Keep the release/version slide tied to the selected pinned DSC runtime and manifest hashes.',
            'Do not present synthetic checked-in evidence as live endpoint proof.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $nextSteps | Should -Match ([regex]::Escape($requiredTerm))
        }
    }
}

Describe -Name 'Issue template guardrails' -Fixture {
    It -Name 'Issue forms keep triage labels and ProStateKit component options' -Test {
        $issueTemplateRoot = Join-Path -Path $script:repoRoot -ChildPath '.github/ISSUE_TEMPLATE'
        $componentOptions = @(
            'Runner',
            'Intune wrapper',
            'ConfigMgr wrapper',
            'DSC configuration',
            'Evidence schema',
            'Exit codes',
            'Reboots',
            'Secrets',
            'Packaging',
            'Validation / CI',
            'Documentation',
            'Other'
        )

        foreach ($templateName in @('bug_report.yml', 'feature_request.yml', 'documentation_issue.yml')) {
            $templatePath = Join-Path -Path $issueTemplateRoot -ChildPath $templateName
            $template = Get-Content -LiteralPath $templatePath -Raw

            $template | Should -Match '(?m)^\s+- triage\s*$'
            foreach ($componentOption in $componentOptions) {
                $template | Should -Match ('(?m)^\s+- {0}\s*$' -f [regex]::Escape($componentOption))
            }
        }
    }

    It -Name 'Bug report template asks for redacted evidence and blocks sensitive content' -Test {
        $bugTemplatePath = Join-Path -Path $script:repoRoot -ChildPath '.github/ISSUE_TEMPLATE/bug_report.yml'
        $bugTemplate = Get-Content -LiteralPath $bugTemplatePath -Raw
        $requiredTerms = @(
            'Do not paste secrets',
            'tenant identifiers',
            'customer data',
            'private logs',
            'unredacted transcripts',
            'full evidence bundles',
            'summary.txt excerpt:',
            'wrapper.result.json excerpt:',
            'dsc.raw.json excerpt:',
            'Exit code:',
            'Execution plane:',
            'reboot.marker existed: yes / no',
            'ProStateKit version:',
            'DSC version:',
            'PowerShell version:',
            'Windows version:',
            'Run mode: Detect / Remediate'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $bugTemplate | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Issue contact links stay on private-staging security and fork-safe support targets' -Test {
        $configPath = Join-Path -Path $script:repoRoot -ChildPath '.github/ISSUE_TEMPLATE/config.yml'
        $config = Get-Content -LiteralPath $configPath -Raw

        $config | Should -Match ([regex]::Escape('https://github.com/franklesniak/ProStateKit/security'))
        $config | Should -Not -Match ([regex]::Escape('https://github.com/franklesniak/ProStateKit/security/advisories/new'))
        $config | Should -Match ([regex]::Escape('https://github.com/franklesniak/ProStateKit/discussions'))
        $config | Should -Match ([regex]::Escape('https://github.com/franklesniak/ProStateKit#support'))
    }
}

Describe -Name 'Contribution instruction guardrails' -Fixture {
    It -Name 'Pull request template requires validation and ProStateKit contract checks' -Test {
        $templatePath = Join-Path -Path $script:repoRoot -ChildPath '.github/pull_request_template.md'
        $template = Get-Content -LiteralPath $templatePath -Raw
        $requiredTerms = @(
            '[contributing guidelines](https://github.com/franklesniak/ProStateKit/blob/HEAD/CONTRIBUTING.md)',
            'I have run `pre-commit run --all-files` locally or verified equivalent CI/pre-commit checks passed',
            'I have reviewed and committed all auto-fixes made by pre-commit hooks',
            'Detect behavior still maps to `dsc config test`',
            'Remediate behavior still verifies state after set',
            'Raw DSC output is preserved before normalization',
            'Normalized evidence schema is updated if result shape changed',
            'Partial convergence fails closed',
            'Missing or unparseable proof fails closed',
            'No secrets are written to configs, logs, transcripts, stdout, or evidence',
            'Reboot behavior remains durable and re-entrant where applicable',
            'README/docs updated for user-facing behavior changes',
            'Exit-code docs updated if exit semantics changed',
            'Evidence schema docs updated if evidence changed',
            'Reboot/secrets docs updated if relevant'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $template | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Agent entry points preserve shared ProStateKit safety and execution rules' -Test {
        $agentContracts = @(
            @{
                Path = 'AGENTS.md'
                Terms = @(
                    '# Agent Instructions for OpenAI Codex CLI',
                    '`.github/copilot-instructions.md`',
                    'No secrets in code or repo; never hardcode API keys, tokens, credentials, or connection strings.',
                    'Treat all external input as untrusted.',
                    'Respect allowlisted file access boundaries; reject path traversal and symlink escapes.',
                    'Run `pre-commit run --all-files` before every commit.',
                    'Invoke-Pester -Path tests/ -Output Detailed'
                )
            }
            @{
                Path = 'CLAUDE.md'
                Terms = @(
                    '# Agent Instructions for Claude Code',
                    '`.github/copilot-instructions.md`',
                    'No secrets in code or repo; never hardcode API keys, tokens, credentials, or connection strings.',
                    'Treat all external input as untrusted.',
                    'Respect allowlisted file access boundaries; reject path traversal and symlink escapes.',
                    'Run `pre-commit run --all-files` before every commit.',
                    'Invoke-Pester -Path tests/ -Output Detailed'
                )
            }
            @{
                Path = 'GEMINI.md'
                Terms = @(
                    '# Agent Instructions for Gemini Code Assist',
                    '`.github/copilot-instructions.md`',
                    'No secrets in code or repo; never hardcode API keys, tokens, credentials, or connection strings.',
                    'Treat all external input as untrusted.',
                    'Respect allowlisted file access boundaries; reject path traversal and symlink escapes.',
                    'Run `pre-commit run --all-files` before every commit.',
                    'Invoke-Pester -Path tests/ -Output Detailed'
                )
            }
            @{
                Path = '.github/copilot-instructions.md'
                Terms = @(
                    '# Repository Copilot Instructions (Repo-Wide Constitution)',
                    'Non-negotiable Safety and Security Rules',
                    '**No secrets in code or repo**',
                    '**Treat all external input as untrusted**',
                    '**Allowlisted file access only**',
                    'Refuse path traversal and symlink escapes.',
                    'Pre-commit Discipline',
                    '`pre-commit run --all-files`'
                )
            }
        )

        foreach ($agentContract in $agentContracts) {
            $content = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath $agentContract.Path) -Raw

            foreach ($requiredTerm in $agentContract.Terms) {
                $content | Should -Match ([regex]::Escape($requiredTerm)) -Because $agentContract.Path
            }
        }
    }

    It -Name 'Modular PowerShell and documentation instructions retain core contribution policies' -Test {
        $powershellInstructions = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/instructions/powershell.instructions.md') -Raw
        $docsInstructions = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/instructions/docs.instructions.md') -Raw
        $requiredPowerShellTerms = @(
            'applyTo:',
            '"**/*.ps1"',
            '# PowerShell Writing Style',
            'Code **MUST** use 4 spaces for indentation, never tabs',
            'Opening braces **MUST** be placed on same line (OTBS)',
            'Source `.ps1` files **MUST** be UTF-8 without BOM by default',
            'Functions **MUST** follow Verb-Noun pattern with approved verbs',
            'Aliases **MUST NOT** be used in code',
            'Public identifiers (functions, parameters, properties) **MUST** use PascalCase'
        )
        $requiredDocsTerms = @(
            'applyTo: "**/*.md"',
            '# Documentation Writing Style',
            'Documentation in this repository is treated as a **first-class engineering artifact**',
            '**Contract-first:** State behavior precisely.',
            '**Drift-resistant:** Docs evolve with code',
            '**Explain "why," not just "what":**',
            'Last Updated'
        )

        foreach ($requiredTerm in $requiredPowerShellTerms) {
            $powershellInstructions | Should -Match ([regex]::Escape($requiredTerm))
        }

        foreach ($requiredTerm in $requiredDocsTerms) {
            $docsInstructions | Should -Match ([regex]::Escape($requiredTerm))
        }
    }
}

Describe -Name 'Data and Git attribute instruction guardrails' -Fixture {
    It -Name 'JSON and YAML modular instructions retain schema data and workflow safety rules' -Test {
        $jsonInstructions = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/instructions/json.instructions.md') -Raw
        $yamlInstructions = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/instructions/yaml.instructions.md') -Raw
        $requiredJsonTerms = @(
            'applyTo: "**/*.json,**/*.jsonc"',
            '`.json` files **MUST** be strict JSON',
            '**MUST** use 2-space indentation; **MUST NOT** use tabs.',
            'Keys and string values **MUST** be double-quoted.',
            '**MUST NOT** commit secrets; example values **MUST** be obviously fake.',
            'Production or load-bearing JSON files **MUST** have schema validation',
            'Untrusted JSON **MUST** be validated before use and **MUST NOT** be evaluated as executable code.'
        )
        $requiredYamlTerms = @(
            'applyTo: "**/*.yml,**/*.yaml"',
            '**MUST** use 2-space indentation; **MUST NOT** use tabs.',
            '**MUST** use block style by default',
            'lowercase `true`, `false`, and `null`',
            '**MUST** quote version pins',
            '**MUST NOT** commit secrets in YAML.',
            '**MUST** apply least-privilege `permissions:` on GitHub Actions workflows.'
        )

        foreach ($requiredTerm in $requiredJsonTerms) {
            $jsonInstructions | Should -Match ([regex]::Escape($requiredTerm))
        }

        foreach ($requiredTerm in $requiredYamlTerms) {
            $yamlInstructions | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Git attributes instructions and repo defaults preserve byte-exact fixture behavior' -Test {
        $instructions = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/instructions/gitattributes.instructions.md') -Raw
        $attributes = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.gitattributes') -Raw
        $requiredInstructionTerms = @(
            'Any committed text file whose identity is its exact byte sequence **MUST** be pinned to LF line endings in `.gitattributes`',
            'The pattern **MUST** be expressed using standard `.gitattributes` syntax with both the `text` and `eol=lf` attributes.',
            'A blanket rule such as `* text=auto` **MUST NOT** be treated as a substitute for per-path `eol=lf` pinning.',
            'If a project stores binary assets (for example, `.png` screenshots or `.zip` archives) inside a directory that is pinned to `text eol=lf`, those binaries **MUST** be declassified explicitly',
            'Hashing and signing tools **SHOULD** operate on raw bytes and **MUST NOT** depend on on-disk text normalization.'
        )
        $requiredAttributeTerms = @(
            'tests/**/golden/**            text eol=lf',
            'tests/**/goldens/**           text eol=lf',
            'tests/**/snapshots/**         text eol=lf',
            'tests/**/__snapshots__/**     text eol=lf',
            'tests/**/fixtures/**          text eol=lf',
            'testdata/**                   text eol=lf',
            '*.png                         binary',
            '*.zip                         binary',
            '*.exe                         binary',
            '*.dll                         binary',
            '*.woff2                       binary'
        )

        foreach ($requiredTerm in $requiredInstructionTerms) {
            $instructions | Should -Match ([regex]::Escape($requiredTerm))
        }

        foreach ($requiredTerm in $requiredAttributeTerms) {
            $attributes | Should -Match ([regex]::Escape($requiredTerm))
        }

        $attributes | Should -Not -Match ([regex]::Escape(('customizing this ' + 'template')))
    }
}

Describe -Name 'Project policy document guardrails' -Fixture {
    It -Name 'Security policy stays private-staging and sensitive-data safe' -Test {
        $securityPath = Join-Path -Path $script:repoRoot -ChildPath 'SECURITY.md'
        $security = Get-Content -LiteralPath $securityPath -Raw
        $requiredTerms = @(
            'Security reporting and handling guidance for the private-staging ProStateKit repository.',
            'Preview staging; security fixes are handled before public release.',
            'Do not report security vulnerabilities through public GitHub issues.',
            'During private staging, security reports are handled through maintainer-only repository access.',
            'Before public release, this repository will enable GitHub Private Vulnerability Reporting',
            'Redact evidence before sharing it.',
            'Do not include secrets, tenant identifiers, customer data, private logs, unredacted transcripts, full raw evidence bundles, or sensitive endpoint inventory.',
            'SYSTEM context behavior and file-system access boundaries.',
            'Scheduled-task fallback used as a reboot continuation strategy.',
            'Runtime retrieval and secret-helper behavior.',
            'Evidence redaction for raw DSC output, transcripts, summaries, and normalized results.',
            'Bundle integrity, manifest validation, and SHA-256 checksums.',
            'Supply-chain pinning for DSC, PowerShell, resources, modules, and scripts.',
            'Public disclosure workflow will be documented after the public flip and Private Vulnerability Reporting setup are complete.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $security | Should -Match ([regex]::Escape($requiredTerm))
        }

        $security | Should -Not -Match ([regex]::Escape('/security/advisories/new'))
    }

    It -Name 'Code of Conduct keeps private-staging reporting and public-contact TODO posture' -Test {
        $codeOfConductPath = Join-Path -Path $script:repoRoot -ChildPath 'CODE_OF_CONDUCT.md'
        $codeOfConduct = Get-Content -LiteralPath $codeOfConductPath -Raw
        $requiredTerms = @(
            'Contributor Covenant 3.0 Code of Conduct',
            'Violating confidentiality.',
            'To report a possible violation before public release, contact the maintainers through private repository channels.',
            'A public reporting contact will be configured before this repository is made public.',
            'Community Moderators will keep investigation and enforcement actions as transparent as possible while prioritizing safety and confidentiality.',
            'This Code of Conduct applies within all community spaces',
            'This Code of Conduct is adapted from the Contributor Covenant, version 3.0'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $codeOfConduct | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Contributing guide anchors validation, contracts, and sanitized evidence expectations' -Test {
        $contributingPath = Join-Path -Path $script:repoRoot -ChildPath 'CONTRIBUTING.md'
        $contributing = Get-Content -LiteralPath $contributingPath -Raw
        $requiredTerms = @(
            'ProStateKit is a preview starter kit',
            'Do not include secrets in examples, tests, configs, logs, transcripts, prompts, or evidence.',
            'Runner behavior changes require Pester tests.',
            'Schema changes must update schema files, valid examples, invalid examples, tests, and docs together.',
            'Exit-code changes must update [docs/exit-codes.md](docs/exit-codes.md).',
            'Evidence changes must update [docs/evidence-schema.md](docs/evidence-schema.md).',
            'Reboot behavior changes must update [docs/reboots.md](docs/reboots.md).',
            'Secrets behavior changes must update [docs/secrets.md](docs/secrets.md).',
            'pre-commit run --all-files',
            'npm run lint:md',
            'Invoke-Pester -Path tests/ -Output Detailed',
            'Pre-commit auto-fixes must be reviewed and included with the related change.',
            'Read the relevant instruction file before changing matching files:',
            'PowerShell code must use strict error handling, avoid secret leakage, and fail closed when proof is missing.',
            'Include sanitized evidence examples only when they are synthetic and reviewed.',
            'By contributing, you agree that your contributions are licensed under the MIT License used by this repository.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $contributing | Should -Match ([regex]::Escape($requiredTerm))
        }
    }
}

Describe -Name 'Documentation and prompt guardrails' -Fixture {
    It -Name 'Technical spec preserves goals non-goals and decision records' -Test {
        $specPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/spec/ProStateKit.md'
        $spec = Get-Content -LiteralPath $specPath -Raw
        $requiredTerms = @(
            'PSK-G-001',
            'Produce a runnable DSC v3 endpoint-state starter kit.',
            'PSK-G-002',
            'Prevent false green by design.',
            'PSK-G-003',
            'Make evidence durable and inspectable.',
            'PSK-G-004',
            'Keep runtime distribution explicit.',
            'PSK-G-005',
            'Support Intune and ConfigMgr without duplicating payload state.',
            'PSK-G-006',
            'Support a latest-runtime test mode.',
            'PSK-G-007',
            'Enable agentic closed-loop development.',
            'PSK-G-008',
            'Produce a demo runbook.',
            'ProStateKit MUST NOT silently download DSC, resources, packages, or schemas during production endpoint execution.',
            'ProStateKit MUST NOT include real secrets, secret placeholders that resemble real values, telemetry, or external logging services.',
            'ProStateKit MUST NOT depend on a human manually interpreting raw DSC output to decide whether the run succeeded.',
            'ProStateKit MUST NOT allow path traversal, symlink escapes, or config paths outside approved bundle roots.',
            '### Decision 001 - Repository Shape',
            '### Decision 002 - Wrapper Implementation Language',
            '### Decision 003 - DSC Runtime Distribution',
            '### Decision 004 - Wrapper Entry Point Model',
            '### Decision 005 - Evidence Model',
            '### Decision 006 - Intune Distribution Pattern',
            '### Decision 007 - ConfigMgr Pattern',
            '### Decision 008 - YAML and JSON Source Strategy',
            '### Decision 009 - Agentic Development Loop',
            '### Decision 010 - Reboot Handling',
            '### Decision 011 - Secrets Handling',
            '### Decision 012 - Demo Baseline Resources',
            'A common runner MUST own validation, DSC invocation, parsing, evidence, redaction, and normalized result output.',
            'Plane-specific shims MUST remain thin and own only parameter defaults, platform summary formatting, and exit/output translation.',
            'Raw DSC outputs are required for forensic and version-drift review.',
            'The first release MUST avoid real secret flow in the demo and MUST include redaction tests.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $spec | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Technical spec keeps milestones open questions and acceptance criteria explicit' -Test {
        $specPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/spec/ProStateKit.md'
        $spec = Get-Content -LiteralPath $specPath -Raw
        $requiredTerms = @(
            'M1 - Skeleton',
            'M2 - Runtime and manifest',
            'M3 - Wrapper core',
            'M4 - Configs and resources',
            'M5 - Plane shims',
            'M6 - Agentic CI',
            'M7 - Demo runbook',
            'M8 - Deck reconciliation',
            'Validate whether the LLMNR registry example is stable and visible enough for the conference demo.',
            'Confirm the exact ConfigMgr compliance discovery/remediation output contract',
            'Decide whether any real secret-flow sample belongs in the repository after redaction tests exist.',
            'Decide whether release artifacts require Authenticode signing in addition to hashes for the first public version.',
            'Recheck DSC latest release one week before deck freeze',
            'ProStateKit is ready to drive the deck only when:',
            'A clean checkout passes validation.',
            'A bundle can be built with a pinned DSC runtime and manifest.',
            'The local demo runbook succeeds twice from a clean reset.',
            'Evidence files match the schema in this spec.',
            'Intune behavior is lab-validated or marked as explicitly unproven.',
            'ConfigMgr behavior is lab-validated or marked as explicitly unproven.',
            'The deck has been reconciled to actual file names, commands, screenshots, and evidence fields.',
            'Open questions are either resolved or explicitly tracked in the next-step document.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $spec | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'README keeps preview posture and core execution contract visible' -Test {
        $readmePath = Join-Path -Path $script:repoRoot -ChildPath 'README.md'
        $readme = Get-Content -LiteralPath $readmePath -Raw
        $requiredTerms = @(
            'It is a starter kit teams can fork and standardize, not a finished product.',
            'Built and validated against `dsc.exe` version: TBD (to be pinned before MMSMOA 2026).',
            'ProStateKit is a preview starter kit for endpoint engineers',
            'It is not production-ready, does not ship a pinned DSC runtime yet, and must not be treated as a finished management agent.',
            'Use native CSPs, Settings Catalog, ConfigMgr Compliance Baselines, or another platform-native feature when they fully meet the requirement.',
            'Detect mode maps to `dsc config test`.',
            'Remediate mode maps to `dsc config set`, followed by a verification `dsc config test`.',
            'Packaging fails closed until a reviewed DSC runtime exists under `runtime/dsc/`.',
            'Every run MUST preserve raw DSC output before normalization.',
            'The stable automation contract is `wrapper.result.json`',
            'Detect exits `0` for compliant, `1` for non-compliant, `2` for runtime failure, and `3` for parse failure or proof missing.',
            'Remediate exits `0` only after verification proves compliance.',
            'The execution plane owns reboot orchestration.',
            'Do not put secrets in configuration documents, examples, logs, transcripts, stdout, normalized evidence, or raw evidence.',
            'npm run validate',
            'pre-commit run --all-files',
            'Release publishing automation is not enabled yet because packaging intentionally fails closed until the pinned runtime is present.',
            'pwsh -File tools/Test-ReleaseReadiness.ps1',
            'Expected preview result: non-zero exit with a report of missing runtime, dry release, rehearsal, lab, public-flip, deck, and final DSC recheck evidence.',
            'Do not paste secrets, tenant identifiers, customer data, private logs, unredacted transcripts, or full evidence bundles into issues.',
            'Security reports must not be filed as public issues.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $readme | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Required documentation and sample evidence scaffolds exist' -Test {
        $requiredPaths = @(
            'docs/contract.md',
            'docs/completion-audit.md',
            'docs/evidence-schema.md',
            'docs/exit-codes.md',
            'docs/reboots.md',
            'docs/secrets.md',
            'docs/troubleshooting.md',
            'docs/resource-gaps.md',
            'docs/packaging.md',
            'docs/runbooks/demo-runbook.md',
            'docs/runbooks/reset-lab.md',
            'docs/runbooks/windows-11-quickstart.md',
            'evidence/sample/compliant-detect/dsc.raw.json',
            'evidence/sample/compliant-detect/wrapper.result.json',
            'evidence/sample/compliant-detect/summary.txt',
            'evidence/sample/noncompliant-detect/dsc.raw.json',
            'evidence/sample/noncompliant-detect/wrapper.result.json',
            'evidence/sample/noncompliant-detect/summary.txt',
            'evidence/sample/successful-remediate/dsc.raw.json',
            'evidence/sample/successful-remediate/wrapper.result.json',
            'evidence/sample/successful-remediate/summary.txt',
            'evidence/sample/partial-failure/dsc.raw.json',
            'evidence/sample/partial-failure/wrapper.result.json',
            'evidence/sample/partial-failure/summary.txt',
            'evidence/sample/parse-failure/dsc.raw.txt',
            'evidence/sample/parse-failure/wrapper.result.json',
            'evidence/sample/parse-failure/summary.txt'
        )

        foreach ($requiredPath in $requiredPaths) {
            Test-Path -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath $requiredPath) -PathType Leaf |
                Should -BeTrue -Because $requiredPath
        }
    }

    It -Name 'Completion audit maps objective to artifacts and blockers' -Test {
        $auditPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/completion-audit.md'
        $audit = Get-Content -LiteralPath $auditPath -Raw
        $requiredTerms = @(
            'The active objective has two deliverables:',
            'Complete the repository initialization from the starter template instructions.',
            'Build ProStateKit per the technical specification.',
            '## Prompt-To-Artifact Checklist',
            'Post-public-flip tasks are deferred, not performed.',
            'Template placeholders and generic Python/Terraform example content are removed.',
            'Common Runner exists and fails closed when proof is missing.',
            'Detect maps to `dsc config test`; Remediate maps to `dsc config set` followed by `dsc config test`.',
            'Bundle tooling builds source plus bundle ZIP, root `bundle.manifest.json`, and `.sha256` only when a reviewed runtime is present.',
            'src/tools/Test-ReleaseReadiness.ps1',
            'Latest local validation: `npm run validate` passed, including 99 Pester tests and both pre-commit passes; `git diff --check` was clean.',
            '## Init Step Mapping',
            'Step 1',
            'Create `_TODO.md` with private-to-public deferred work.',
            'Step 5',
            'Remove unused Python and Terraform support while keeping validation hooks.',
            'Step 13',
            'Configure pre-commit, workflows, and Dependabot.',
            'Step 18',
            'Add fail-closed PowerShell runner and wrappers.',
            'release-readiness',
            'Step 24',
            'Keep release workflow manual and fail-closed.',
            'Step 27',
            'Preserve no-false-completion guardrails.',
            'Final self-check',
            'Complete for preview scaffold; not release-complete.',
            '## Open Blockers',
            'Reviewed pinned DSC runtime is selected and placed.',
            'Real dry release is run.',
            'Local demo runbook is rehearsed twice.',
            'Intune behavior is lab-validated.',
            'ConfigMgr behavior is lab-validated.',
            'Public flip tasks are completed by repository owner.',
            'Deck is reconciled to real repo output.',
            'Final DSC release recheck is performed.',
            'Do not mark the active objective complete until those blockers are closed'
        )

        Test-Path -LiteralPath $auditPath -PathType Leaf | Should -BeTrue
        foreach ($requiredTerm in $requiredTerms) {
            $audit | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Runtime distribution docs preserve reviewed placement workflow' -Test {
        $runtimeDistributionPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/runtime-distribution.md'
        $runtimeDistribution = Get-Content -LiteralPath $runtimeDistributionPath -Raw
        $requiredTerms = @(
            '## Review And Placement Workflow',
            'A candidate becomes the pinned runtime only after the reviewer records the selected version, release URL, source artifact hash, extracted runtime hash, and sign-off',
            'extract the full archive into `runtime/dsc/`',
            'do not copy only the executable',
            '[.github/scripts/Save-DscRuntimeCandidate.ps1](../.github/scripts/Save-DscRuntimeCandidate.ps1)',
            'disposable temp review directory',
            'verify the source hash, extract the archive, and report the extracted runtime hash',
            'This helper is for maintainer review only and is not part of the endpoint runtime bundle.',
            'run `tools/New-Package.ps1` with a disposable output path',
            'run `tools/Test-Bundle.ps1` against the staged bundle',
            'Do not commit generated ZIP files, `.sha256` files, root `bundle.manifest.json`, or lab evidence generated during review.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $runtimeDistribution | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Demo runbook keeps commands expected outcomes fallback evidence and timing explicit' -Test {
        $runbookPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/runbooks/demo-runbook.md'
        $runbook = Get-Content -LiteralPath $runbookPath -Raw
        $requiredTerms = @(
            'Commands are preview-stage and fail closed until pinned DSC runtime integration is completed.',
            'Windows lab endpoint with permission to test DSC v3 resources.',
            'Pinned `dsc.exe` version for the checked-in config: `3.2.0`.',
            'Resource paths exercised by the checked-in config:',
            '`Microsoft.Windows/Registry` `=1.0.0` and `Microsoft.Windows/WindowsPowerShell` `=0.1.0`.',
            'The Windows PowerShell adapter contains the nested `PSDesiredStateConfiguration/Group`',
            '## DSC Configuration Under Test',
            '$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json',
            'directives.version: ''=3.2.0''',
            'DSC treats a missing `$schema` as a configuration validation failure.',
            'pwsh -File .\tools\Build-Bundle.ps1',
            'Expected preview result without a pinned runtime: non-zero failure stating that the pinned DSC runtime is required, with no partial release artifact.',
            'Set-Location -LiteralPath ''C:\ProgramData\ProStateKit\Bundle''',
            '& ''.\planes\local\Invoke-LocalPreflight.ps1'' -BundleRoot . -RuntimeMode PinnedBundle',
            'Expected preview result on a clean checkout without `bundle.manifest.json` and `runtime/dsc/dsc.exe`: exit `1`',
            'pwsh -File .\src\Invoke-ProStateKit.ps1 -Mode Detect -Plane Local -ConfigPath .\configs\baseline.dsc.yaml -RuntimeMode PinnedBundle -BundleRoot .',
            '`wrapper.result.json` records Runner exit decision `2`',
            'Use synthetic fallback evidence until real lab evidence exists:',
            'evidence/sample/compliant-detect/summary.txt',
            'evidence/sample/noncompliant-detect/wrapper.result.json',
            'evidence/sample/successful-remediate/wrapper.result.json',
            'evidence/sample/partial-failure/wrapper.result.json',
            'evidence/sample/parse-failure/summary.txt',
            'pwsh -File .\src\tools\New-DemoDrift.ps1',
            'Registry and local-group drift steps remain lab debt until reset behavior is rehearsed on the pinned runtime.',
            'pwsh -File .\src\Invoke-ProStateKit.ps1 -Mode Remediate -Plane Local -ConfigPath .\configs\baseline.dsc.yaml -RuntimeMode PinnedBundle -BundleRoot .',
            'Expected lab result after runtime pinning: exit `0` only after post-set verification proves compliance.',
            'Use the same command as Known-Good Detect.',
            'pwsh -File .\src\tools\Reset-DemoDrift.ps1',
            'Do not present synthetic output as live endpoint proof.',
            'Parser or schema failure triage:',
            'Confirm the YAML file contains the top-level `$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json`.',
            'Confirm `directives.version` matches the pinned `dsc.exe` version selected for the rehearsal.',
            'Re-run `pwsh -File .\tools\Convert-ConfigYamlToJson.ps1` and inspect the generated JSON mirror.',
            'Explain operating model',
            'Open evidence and explain false-green prevention',
            'TODO: replace targets with measured timings after two clean rehearsals.',
            '## Release Readiness Gate',
            'pwsh -File .\tools\Test-ReleaseReadiness.ps1',
            'Expected preview result before those external actions are complete: exit `1` with a fail-closed readiness report.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $runbook | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Reset runbook keeps remaining lab reset debt explicit' -Test {
        $resetPath = Join-Path -Path $script:repoRoot -ChildPath 'docs/runbooks/reset-lab.md'
        $resetRunbook = Get-Content -LiteralPath $resetPath -Raw
        $requiredTerms = @(
            'Preview reset automation is implemented for the demo-owned marker file through [Reset-DemoDrift.ps1](../../src/tools/Reset-DemoDrift.ps1).',
            'Local group and registry reset remain lab debt until the exact DSC resource versions are pinned and rehearsed on the Windows lab endpoint.',
            'Remove or restore the controlled local group `Baseline-ControlledLocal`.',
            'Restore the LLMNR demo registry value to the chosen pre-demo state.',
            'Remove or restore `C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt`.',
            'Clear generated runtime evidence outside committed synthetic samples.',
            'Confirm no reboot marker remains unless intentionally testing reboot behavior.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $resetRunbook | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'Prompt guidance keeps AI review and sensitive-data disclaimer out of runtime paths' -Test {
        $promptPath = Join-Path -Path $script:repoRoot -ChildPath 'prompts/README.md'
        $prompt = Get-Content -LiteralPath $promptPath -Raw

        $prompt | Should -Match ([regex]::Escape('AI-generated output must be reviewed before use.'))
        $prompt | Should -Match ([regex]::Escape('Do not paste secrets, tenant data, customer data, private logs, unredacted transcripts, or unredacted evidence into prompts.'))
        $prompt | Should -Match ([regex]::Escape('AI is not used live in the demo.'))
        $prompt | Should -Match ([regex]::Escape('Runtime scripts must not import files from this directory.'))

        foreach ($runtimeRoot in @('src', 'planes', 'tools')) {
            foreach ($scriptPath in Get-ChildItem -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath $runtimeRoot) -Include '*.ps1', '*.psm1' -Recurse -File) {
                $content = Get-Content -LiteralPath $scriptPath.FullName -Raw
                $content | Should -Not -Match ([regex]::Escape('prompts/')) -Because $scriptPath.FullName
                $content | Should -Not -Match ([regex]::Escape('prompts\')) -Because $scriptPath.FullName
            }
        }
    }

    It -Name 'Secret helper remains fail-closed and documents no-leakage rules' -Test {
        $secretHelperPath = Join-Path -Path $script:repoRoot -ChildPath 'src/tools/SecretHelper.ps1'
        $secretHelper = Get-Content -LiteralPath $secretHelperPath -Raw
        $requiredTerms = @(
            'Secret retrieval is not implemented.',
            'Sensitive values must never be written to transcripts, stdout, logs, evidence files',
            'dsc.raw.json, wrapper.result.json, summary.txt',
            'Any surfaced error message must be redacted',
            'vault name and item name, never value material',
            'Microsoft.PowerShell.SecretManagement',
            'throw [System.NotImplementedException]::new'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $secretHelper | Should -Match ([regex]::Escape($requiredTerm))
        }
    }
}

Describe -Name 'Validation command guardrails' -Fixture {
    It -Name 'package scripts expose the clean-checkout validation surface' -Test {
        $package = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'package.json') -Raw |
            ConvertFrom-Json

        $package.engines.node | Should -Be '>=20.0.0'
        $package.dependencies.'js-yaml' | Should -Be '^4.1.1'
        $package.scripts.'lint:md' |
            Should -Be 'markdownlint-cli2 "**/*.md" "#node_modules" "#.pre-commit-cache" "#.npm-cache" "#.pip-cache"'
        $package.scripts.'lint:md:nested' |
            Should -Be 'node .github/scripts/lint-nested-markdown.js'
        $package.scripts.'lint:md:links' |
            Should -Be 'node .github/scripts/lint-markdown-links.js'
        $package.scripts.validate |
            Should -Be 'pwsh -NoProfile -File tools/Invoke-Validation.ps1'
    }

    It -Name 'validation wrapper runs markdown schema PowerShell analyzer Pester and pre-commit gates' -Test {
        $validationPath = Join-Path -Path $script:repoRoot -ChildPath 'tools/Invoke-Validation.ps1'
        $validation = Get-Content -LiteralPath $validationPath -Raw
        $requiredTerms = @(
            '$ErrorActionPreference = ''Stop''',
            'Set-StrictMode -Version Latest',
            'Push-Location -LiteralPath $RepositoryRoot',
            '& npm run lint:md',
            '& npm run lint:md:nested',
            '& npm run lint:md:links',
            '& pwsh -NoProfile -File ''src/tools/Invoke-SchemaLint.ps1''',
            '[System.Management.Automation.Language.Parser]::ParseFile',
            '& pwsh -NoProfile -File ''src/tools/Invoke-PSScriptAnalyzer.ps1''',
            'Invoke-Pester -Path ''tests/PowerShell'' -Output Detailed -PassThru',
            'if ($pesterResult.FailedCount -gt 0)',
            'if (-not $SkipPreCommit.IsPresent -and (Get-Command -Name pre-commit -ErrorAction SilentlyContinue))',
            '& pre-commit run --all-files',
            '& git ls-files --modified --others --exclude-standard',
            '& pre-commit run --files @changedFiles',
            'pre-commit failed for changed or untracked files.',
            'Write-Warning ''pre-commit is not available; skipping pre-commit run.''',
            'Pop-Location'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $validation | Should -Match ([regex]::Escape($requiredTerm))
        }
    }

    It -Name 'PSScriptAnalyzer wrapper analyzes files individually and reports failing paths' -Test {
        $analyzerPath = Join-Path -Path $script:repoRoot -ChildPath 'src/tools/Invoke-PSScriptAnalyzer.ps1'
        $analyzer = Get-Content -LiteralPath $analyzerPath -Raw
        $requiredTerms = @(
            'foreach ($path in @(''.github/scripts'', ''src'', ''planes'', ''tests'', ''tools''))',
            'Get-ChildItem -LiteralPath $analysisPath -Include ''*.ps1'', ''*.psm1'' -Recurse -File',
            'Path = $scriptPath.FullName',
            'PSScriptAnalyzer failed while analyzing {0}: {1}',
            'PSScriptAnalyzer found violations in {0}.'
        )

        foreach ($requiredTerm in $requiredTerms) {
            $analyzer | Should -Match ([regex]::Escape($requiredTerm))
        }
    }
}

Describe -Name 'Repository metadata guardrails' -Fixture {
    It -Name 'Project identity metadata matches ProStateKit preview settings' -Test {
        $package = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'package.json') -Raw |
            ConvertFrom-Json
        $vscodeSettings = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.vscode/settings.json') -Raw |
            ConvertFrom-Json
        $license = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'LICENSE') -Raw
        $requiredKeywords = @(
            'dsc',
            'dsc-v3',
            'powershell',
            'intune',
            'configmgr',
            'endpoint-state',
            'endpoint-management',
            'desired-state-configuration',
            'automation',
            'remediation',
            'compliance',
            'evidence'
        )

        $package.name | Should -Be 'prostatekit'
        $package.version | Should -Be '0.1.0'
        $package.private | Should -BeTrue
        $package.author | Should -Be 'Frank Lesniak and Blake Cherry'
        $package.description | Should -Be 'Starter kit for reliable endpoint state with DSC v3 execution templates, evidence, validation, and management-plane wrappers.'
        foreach ($keyword in $requiredKeywords) {
            @($package.keywords) | Should -Contain $keyword
        }
        $vscodeSettings.'window.title' | Should -Be 'ProStateKit'
        $license | Should -Match ([regex]::Escape('MIT License'))
        $license | Should -Match ([regex]::Escape('Copyright (c) 2026 Frank Lesniak and Blake Cherry'))
    }

    It -Name 'CODEOWNERS assigns every owned path to both maintainers' -Test {
        $codeownersPath = Join-Path -Path $script:repoRoot -ChildPath '.github/CODEOWNERS'
        $codeownersLines = Get-Content -LiteralPath $codeownersPath

        foreach ($line in $codeownersLines) {
            if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
                continue
            }

            $line | Should -Match ([regex]::Escape('@franklesniak'))
            $line | Should -Match ([regex]::Escape('@blakelishly'))
        }
    }

    It -Name 'Template Python Terraform and template-internal files remain removed' -Test {
        $removedPaths = @(
            'pyproject.toml',
            '.github/workflows/python-ci.yml',
            '.github/workflows/terraform-ci.yml',
            '.github/instructions/python.instructions.md',
            '.github/instructions/terraform.instructions.md',
            '.github/TEMPLATE_DESIGN_DECISIONS.md',
            '.tflint.hcl',
            'FUNDING.yml',
            'GETTING_STARTED_EXISTING_REPO.md',
            'GETTING_STARTED_NEW_REPO.md',
            'OPTIONAL_CONFIGURATIONS.md',
            'TEMPLATE_MAINTENANCE.md',
            ('src/{0}' -f ('copilot' + '_repo' + '_template')),
            'templates/python',
            'templates/terraform',
            'docs/terraform'
        )

        foreach ($removedPath in $removedPaths) {
            Test-Path -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath $removedPath) |
                Should -BeFalse -Because $removedPath
        }

        $unexpectedFiles = @(
            Get-ChildItem -LiteralPath $script:repoRoot -File -Recurse -Force -Include '*.tf', '*.tfvars', '*.py' |
                Where-Object -FilterScript {
                    $_.FullName -notmatch '[\\/](\.git|node_modules|\.pre-commit-cache|\.npm-cache|\.pip-cache)[\\/]'
                }
        )
        $unexpectedFiles | Should -BeNullOrEmpty
    }

    It -Name 'Validation dependency configuration keeps required hooks and omits pip ecosystem updates' -Test {
        $preCommitConfig = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.pre-commit-config.yaml') -Raw
        $dependabotConfig = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/dependabot.yml') -Raw
        $requiredHookText = @(
            'check-jsonschema',
            'check-metaschema',
            'yamllint',
            'actionlint',
            'markdownlint-cli2',
            'markdownlint local links'
        )

        foreach ($hookText in $requiredHookText) {
            $preCommitConfig | Should -Match ([regex]::Escape($hookText))
        }

        $dependabotConfig | Should -Match 'package-ecosystem: "npm"'
        $dependabotConfig | Should -Match 'package-ecosystem: "github-actions"'
        $dependabotConfig | Should -Match 'package-ecosystem: "pre-commit"'
        $dependabotConfig | Should -Not -Match 'package-ecosystem: "pip"'
    }
}
