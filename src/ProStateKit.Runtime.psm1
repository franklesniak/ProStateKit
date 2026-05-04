Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ProStateKit.Common.psm1') -Force

function Resolve-ProStateKitRuntime {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PinnedBundle', 'InstalledPath', 'LabLatest')]
        [string] $RuntimeMode,

        [Parameter(Mandatory)]
        [ValidateSet('Local', 'Intune', 'ConfigMgr', 'CI')]
        [string] $Plane,

        [Parameter(Mandatory)]
        [string] $BundleRoot,

        [string] $RuntimePath,

        [switch] $AllowLabLatest
    )

    if ($RuntimeMode -eq 'LabLatest' -and $Plane -in @('Intune', 'ConfigMgr')) {
        throw [System.InvalidOperationException]::new('LabLatest runtime mode is blocked for Intune and ConfigMgr.')
    }
    if ($RuntimeMode -eq 'LabLatest' -and -not $AllowLabLatest.IsPresent) {
        throw [System.InvalidOperationException]::new('LabLatest runtime mode requires -AllowLabLatest.')
    }

    $source = 'BundleRoot'
    $candidatePath = $RuntimePath
    if ($RuntimeMode -eq 'PinnedBundle') {
        $exeName = 'dsc'
        if (Test-ProStateKitWindows) {
            $exeName = 'dsc.exe'
        }
        $candidatePath = Join-Path -Path $BundleRoot -ChildPath (Join-Path -Path 'runtime/dsc' -ChildPath $exeName)
    } elseif ([string]::IsNullOrWhiteSpace($candidatePath)) {
        $command = Get-Command -Name 'dsc' -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            $candidatePath = $command.Source
            $source = 'PATH'
        }
    } else {
        $source = $RuntimeMode
    }

    if ([string]::IsNullOrWhiteSpace($candidatePath) -or -not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new('DSC runtime was not found.', $candidatePath)
    }

    if ($RuntimeMode -eq 'PinnedBundle' -and (Test-ProStateKitPathHasLink -CandidatePath $candidatePath -RootPath $BundleRoot)) {
        throw [System.UnauthorizedAccessException]::new('Pinned runtime path must not contain symlink or reparse-point components.')
    }

    $version = 'TBD'
    $versionOutput = & $candidatePath --version 2>&1 |
        Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($versionOutput)) {
        $version = ([string] $versionOutput).Trim()
    }

    return [pscustomobject]@{
        mode = $RuntimeMode
        path = [System.IO.Path]::GetFullPath($candidatePath)
        version = $version
        source = $source
        expectedHash = 'TBD'
        observedHash = Get-ProStateKitSha256 -Path $candidatePath
    }
}

Export-ModuleMember -Function 'Resolve-ProStateKitRuntime'
