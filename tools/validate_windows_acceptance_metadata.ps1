[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EvidenceDirectory
)

$ErrorActionPreference = "Stop"
$resolvedEvidenceDirectory = (Resolve-Path -LiteralPath $EvidenceDirectory -ErrorAction Stop).Path
$metadataPath = Join-Path $resolvedEvidenceDirectory "build-metadata.json"
$reportPath = Join-Path $resolvedEvidenceDirectory "native-windows-acceptance.json"
$lockPath = Join-Path $resolvedEvidenceDirectory "toolchain.lock.json"
$buildManifestPath = Join-Path $resolvedEvidenceDirectory "build-manifest.json"
foreach ($path in @($metadataPath, $reportPath, $lockPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Native acceptance evidence is missing required file: $path"
    }
}

$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$lockHash = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash.ToLowerInvariant()
$buildManifest = $null
if (Test-Path -LiteralPath $buildManifestPath -PathType Leaf) {
    $buildManifest = Get-Content -LiteralPath $buildManifestPath -Raw | ConvertFrom-Json
}

if ($metadata.toolchain_lock -ne "toolchain.lock.json") {
    throw "Build metadata does not name the copied toolchain lock."
}
if ($metadata.toolchain_lock_sha256 -ne $lockHash) {
    throw "Build metadata toolchain lock hash does not match the copied lock."
}
if ($report.toolchain_lock -ne "toolchain.lock.json") {
    throw "Acceptance report does not name the copied toolchain lock."
}
if ($report.toolchain_lock_sha256 -ne $lockHash) {
    throw "Acceptance report toolchain lock hash does not match the copied lock."
}
if ($report.metadata -ne "build-metadata.json") {
    throw "Acceptance report does not reference build metadata."
}
if ($null -ne $buildManifest) {
    if ($buildManifest.toolchain_lock_sha256 -ne $lockHash) {
        throw "Build manifest toolchain lock hash does not match the copied lock."
    }
}

Write-Output "PASS: native acceptance metadata binds to toolchain lock $lockHash"
