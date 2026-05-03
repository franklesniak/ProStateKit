[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $MarkerPath = 'C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT -and $MarkerPath -like 'C:\*') {
    throw [System.PlatformNotSupportedException]::new('Default demo reset path is Windows-only. Pass -MarkerPath for non-Windows tests.')
}

if ($PSCmdlet.ShouldProcess($MarkerPath, 'Create demo marker file')) {
    [void] (New-Item -Path (Split-Path -Path $MarkerPath -Parent) -ItemType Directory -Force)
    Set-Content -LiteralPath $MarkerPath -Value 'ProStateKit demo baseline marker' -Encoding utf8
}
