function Get-ProStateKitEvidenceRunPath {
    param(
        [Parameter(Mandatory)]
        [string] $EvidenceRoot,

        [Parameter(Mandatory)]
        [string] $OperationId
    )

    return Join-Path -Path $EvidenceRoot -ChildPath (Join-Path -Path 'Runs' -ChildPath $OperationId)
}

Export-ModuleMember -Function 'Get-ProStateKitEvidenceRunPath'
