[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRootFull = [System.IO.Path]::GetFullPath($RepositoryRoot)
$wrapperSchemaPath = Join-Path -Path $repositoryRootFull -ChildPath 'schemas/wrapper-result.schema.json'
$manifestSchemaPath = Join-Path -Path $repositoryRootFull -ChildPath 'schemas/bundle-manifest.schema.json'
$readinessSchemaPath = Join-Path -Path $repositoryRootFull -ChildPath 'schemas/release-readiness.schema.json'
$wrapperSchema = Get-Content -LiteralPath $wrapperSchemaPath -Raw
$manifestSchema = Get-Content -LiteralPath $manifestSchemaPath -Raw
$readinessSchema = Get-Content -LiteralPath $readinessSchemaPath -Raw

foreach ($jsonPath in Get-ChildItem -LiteralPath $repositoryRootFull -Filter '*.json' -Recurse -File) {
    if ($jsonPath.FullName -match '[\\/](node_modules|\.pre-commit-cache|\.npm-cache|\.pip-cache)[\\/]') {
        continue
    }

    $null = Get-Content -LiteralPath $jsonPath.FullName -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
}

foreach ($yamlPath in Get-ChildItem -LiteralPath $repositoryRootFull -Include '*.yaml', '*.yml' -Recurse -File) {
    if ($yamlPath.FullName -match '[\\/](node_modules|\.pre-commit-cache|\.npm-cache|\.pip-cache)[\\/]') {
        continue
    }

    $nodeScript = @'
const fs = require('fs');
const yaml = require('js-yaml');
const path = process.argv[1];
yaml.load(fs.readFileSync(path, 'utf8'), { filename: path });
'@
    & node -e $nodeScript $yamlPath.FullName
    if ($LASTEXITCODE -ne 0) {
        throw [System.FormatException]::new('YAML parse failed: {0}' -f $yamlPath.FullName)
    }
}

foreach ($fixturePath in Get-ChildItem -LiteralPath (Join-Path -Path $repositoryRootFull -ChildPath 'schemas/examples') -Filter 'wrapper-result.valid.json' -Recurse -File) {
    $fixture = Get-Content -LiteralPath $fixturePath.FullName -Raw
    if (-not (Test-Json -Json $fixture -Schema $wrapperSchema)) {
        throw [System.FormatException]::new('Wrapper fixture failed schema validation: {0}' -f $fixturePath.FullName)
    }
}

foreach ($fixturePath in Get-ChildItem -LiteralPath (Join-Path -Path $repositoryRootFull -ChildPath 'evidence/sample') -Filter 'wrapper.result.json' -Recurse -File) {
    $fixture = Get-Content -LiteralPath $fixturePath.FullName -Raw
    if (-not (Test-Json -Json $fixture -Schema $wrapperSchema)) {
        throw [System.FormatException]::new('Evidence fixture failed schema validation: {0}' -f $fixturePath.FullName)
    }
}

$manifestFixture = Get-Content -LiteralPath (Join-Path -Path $repositoryRootFull -ChildPath 'schemas/examples/bundle-manifest.valid.json') -Raw
if (-not (Test-Json -Json $manifestFixture -Schema $manifestSchema)) {
    throw [System.FormatException]::new('Bundle manifest fixture failed schema validation.')
}

$readinessFixture = Get-Content -LiteralPath (Join-Path -Path $repositoryRootFull -ChildPath 'schemas/examples/release-readiness.valid.json') -Raw
if (-not (Test-Json -Json $readinessFixture -Schema $readinessSchema)) {
    throw [System.FormatException]::new('Release readiness fixture failed schema validation.')
}

Write-Output 'Schema lint completed successfully.'
