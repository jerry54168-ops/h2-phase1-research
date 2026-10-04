[CmdletBinding()]
param([Parameter(Mandatory)][string]$ZipPath,
      [Parameter(Mandatory)][string]$BuilderReceiptPath,
      [Parameter(Mandatory)][string]$OutputPath,
      [Parameter(Mandatory)][ValidateSet('Reviewer-context','Validator-context')][string]$LogicalContext)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expected = Get-Content -LiteralPath $BuilderReceiptPath -Raw | ConvertFrom-Json
$fixedBytes = [Text.Encoding]::ASCII.GetBytes("WB-GH-PHASE1-SYNTHETIC`n")
$fixedSha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($fixedBytes)).ToLowerInvariant()
$actualOuter = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$actualMember = $null
$accepted = $false
$reason = 'HASH_OR_MEMBER_MISMATCH'
try {
    if ($expected.receipt_kind -cne 'SYNTHETIC_ARTIFACT' -or $expected.input_sha256 -cne $fixedSha -or
        $expected.member_sha256 -cne $fixedSha -or $expected.member_name -cne 'synthetic.txt' -or
        $expected.input_encoding -cne 'ASCII' -or
        $expected.input_hex -cne [Convert]::ToHexString($fixedBytes).ToLowerInvariant() -or
        $expected.input_bytes -ne $fixedBytes.Length) { throw 'Unbound synthetic receipt' }
    if ($actualOuter -cne $expected.outer_sha256 -or (Get-Item -LiteralPath $ZipPath).Length -ne $expected.outer_bytes) {
        throw 'Outer hash or byte count mismatch'
    }
    $fileStream = [IO.File]::OpenRead($ZipPath)
    try {
        $archive = [IO.Compression.ZipArchive]::new($fileStream,[IO.Compression.ZipArchiveMode]::Read,$true)
        try {
            if ($archive.Entries.Count -ne 1 -or $archive.Entries[0].FullName -cne 'synthetic.txt' -or
                $archive.Entries[0].Length -ne $fixedBytes.Length) { throw 'Member set mismatch' }
            $memberStream = $archive.Entries[0].Open()
            $buffer = [IO.MemoryStream]::new()
            try { $memberStream.CopyTo($buffer); $actualBytes = $buffer.ToArray() }
            finally { $memberStream.Dispose(); $buffer.Dispose() }
            $actualMember = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($actualBytes)).ToLowerInvariant()
            $accepted = ($actualMember -ceq $fixedSha -and
                [Convert]::ToHexString($actualBytes) -ceq [Convert]::ToHexString($fixedBytes))
            if ($accepted) { $reason = 'EXACT_OUTER_AND_SYNTHETIC_MEMBER_MATCH' }
        } finally { $archive.Dispose() }
    } finally { $fileStream.Dispose() }
} catch { $reason = $_.Exception.Message; $accepted = $false }
$receipt = [ordered]@{
    receipt_kind = 'ARTIFACT_VERIFICATION'
    logical_context = $LogicalContext
    result = $(if ($accepted) { 'ARTIFACT_INTEGRITY_ONLY_PASS' } else { 'REJECTED' })
    accepted = $accepted
    reason = $reason
    expected_outer_sha256 = $expected.outer_sha256
    observed_outer_sha256 = $actualOuter
    expected_member_sha256 = $fixedSha
    observed_member_sha256 = $actualMember
}
[IO.File]::WriteAllText($OutputPath, ($receipt | ConvertTo-Json) + "`n", [Text.UTF8Encoding]::new($false))
# Typed return; no exit that terminates the tamper controller.
[pscustomobject]$receipt
