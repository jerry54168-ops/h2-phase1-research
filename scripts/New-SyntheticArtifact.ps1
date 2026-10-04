[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputDirectory) { throw 'HOLD: output exists' }
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$bytes = [Text.Encoding]::ASCII.GetBytes("WB-GH-PHASE1-SYNTHETIC`n")
$member = Join-Path $OutputDirectory 'synthetic.txt'
[IO.File]::WriteAllBytes($member,$bytes)
$inputHash = (Get-FileHash -LiteralPath $member -Algorithm SHA256).Hash.ToLowerInvariant()
$zipPath = Join-Path $OutputDirectory 'synthetic.zip'
$stream = [IO.File]::Open($zipPath,[IO.FileMode]::CreateNew)
try {
    $archive = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        $entry = $archive.CreateEntry('synthetic.txt',[IO.Compression.CompressionLevel]::NoCompression)
        $entry.LastWriteTime = [DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
        $memberStream = $entry.Open()
        try { $memberStream.Write($bytes,0,$bytes.Length) } finally { $memberStream.Dispose() }
    } finally { $archive.Dispose() }
} finally { $stream.Dispose() }
$receipt = [ordered]@{
    receipt_kind = 'SYNTHETIC_ARTIFACT'
    result = 'SYNTHETIC_ARTIFACT_CREATED'
    logical_context = 'Builder-context'
    input_encoding = 'ASCII'
    input_hex = [Convert]::ToHexString($bytes).ToLowerInvariant()
    input_bytes = $bytes.Length
    input_sha256 = $inputHash
    member_name = 'synthetic.txt'
    member_sha256 = $inputHash
    outer_sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    outer_bytes = (Get-Item -LiteralPath $zipPath).Length
}
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'artifact-receipt.json'), ($receipt | ConvertTo-Json) + "`n", [Text.UTF8Encoding]::new($false))
