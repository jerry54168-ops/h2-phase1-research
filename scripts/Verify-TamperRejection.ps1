[CmdletBinding()]
param([Parameter(Mandatory)][string]$OriginalZipPath,
      [Parameter(Mandatory)][string]$BuilderReceiptPath,
      [Parameter(Mandatory)][string]$CopyPath,
      [Parameter(Mandatory)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([IO.Path]::GetFullPath($OriginalZipPath) -eq [IO.Path]::GetFullPath($CopyPath) -or
    (Test-Path -LiteralPath $CopyPath)) { throw 'HOLD: copy must be a fresh distinct path' }
$before = (Get-FileHash -LiteralPath $OriginalZipPath -Algorithm SHA256).Hash
$original = & (Join-Path $PSScriptRoot 'Verify-SyntheticArtifact.ps1') -ZipPath $OriginalZipPath -BuilderReceiptPath $BuilderReceiptPath -OutputPath ($OutputPath + '.original.json') -LogicalContext 'Validator-context'
if (-not $original.accepted) { throw 'HOLD: original is not valid' }
Copy-Item -LiteralPath $OriginalZipPath -Destination $CopyPath
$stream = [IO.File]::Open($CopyPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite)
try {
    $first = $stream.ReadByte()
    if ($first -lt 0) { throw 'HOLD: empty copied artifact' }
    $stream.Position = 0
    $stream.WriteByte([byte]($first -bxor 1))
} finally { $stream.Dispose() }
$tampered = & (Join-Path $PSScriptRoot 'Verify-SyntheticArtifact.ps1') -ZipPath $CopyPath -BuilderReceiptPath $BuilderReceiptPath -OutputPath ($OutputPath + '.altered.json') -LogicalContext 'Validator-context'
$after = (Get-FileHash -LiteralPath $OriginalZipPath -Algorithm SHA256).Hash
$copyHash = (Get-FileHash -LiteralPath $CopyPath -Algorithm SHA256).Hash
$rejected = (-not $tampered.accepted -and $tampered.result -ceq 'REJECTED' -and $before -ceq $after -and $copyHash -cne $before)
$receipt = [ordered]@{
    receipt_kind = 'TAMPER_REJECTION'
    logical_context = 'Validator-context'
    result = $(if ($rejected) { 'TAMPER_REJECTION_ONLY_PASS' } else { 'HOLD' })
    TAMPER_REJECTED = $(if ($rejected) { 'YES' } else { 'NO' })
    original_before_sha256 = $before.ToLowerInvariant()
    original_after_sha256 = $after.ToLowerInvariant()
    altered_copy_sha256 = $copyHash.ToLowerInvariant()
}
[IO.File]::WriteAllText($OutputPath, ($receipt | ConvertTo-Json) + "`n", [Text.UTF8Encoding]::new($false))
if (-not $rejected) { throw 'HOLD: tamper was not rejected or original changed' }
