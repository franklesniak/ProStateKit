function ConvertTo-ProStateKitRedactedText {
    param(
        [AllowNull()]
        [string] $Text
    )

    if ($null -eq $Text) {
        return $null
    }

    $redacted = $Text -replace '(?i)(password|secret|token|api[_-]?key|client[_-]?secret)(\s*[:=]\s*)\S+', '$1$2[REDACTED]'
    $redacted = $redacted -replace '(?i)bearer\s+[a-z0-9._~+/-]+=*', 'Bearer [REDACTED]'
    return $redacted
}

Export-ModuleMember -Function 'ConvertTo-ProStateKitRedactedText'
