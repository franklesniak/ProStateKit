[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient',

    [string] $ValueName = 'EnableMulticast',

    [int] $CompliantValue = 0,

    [string] $MarkerPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not [string]::IsNullOrWhiteSpace($MarkerPath)) {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT -and $MarkerPath -like 'C:\*') {
        throw [System.PlatformNotSupportedException]::new('Default demo reset path is Windows-only. Pass -MarkerPath for non-Windows tests.')
    }

    if ($PSCmdlet.ShouldProcess($MarkerPath, 'Create demo marker file')) {
        [void] (New-Item -Path (Split-Path -Path $MarkerPath -Parent) -ItemType Directory -Force)
        Set-Content -LiteralPath $MarkerPath -Value 'ProStateKit demo baseline marker' -Encoding utf8
    }
    return
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw [System.PlatformNotSupportedException]::new('Default demo reset registry path is Windows-only. Pass -MarkerPath for non-Windows tests.')
}

$target = '{0}\{1}' -f $RegistryPath, $ValueName
if ($PSCmdlet.ShouldProcess($target, 'Set LLMNR demo registry value to the compliant value')) {
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        [void] (New-Item -Path $RegistryPath -Force)
    }
    [void] (New-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -PropertyType DWord -Value $CompliantValue -Force)
}
