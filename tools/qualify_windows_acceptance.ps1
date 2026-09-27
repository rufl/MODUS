[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Executable,
    [string]$EvidenceDirectory = "windows-acceptance-evidence",
    [ValidateRange(10, 600)]
    [int]$TimeoutSeconds = 90,
    [switch]$RequirePhysicalInput,
    [ValidateSet("Pair", "Server", "Client", "Skip")]
    [string]$NetworkMode = "Pair",
    [ValidateRange(0, 65535)]
    [int]$NetworkPort = 0,
    [string]$ServerAddress = "127.0.0.1",
    [ValidateRange(0, 600)]
    [int]$NetworkSoakSeconds = 0,
    [switch]$RequireReconnect,
    [switch]$RequireHostLoss,
    [string]$Manifest = "",
    [string]$Hashes = ""
)

$ErrorActionPreference = "Stop"
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "Native Windows acceptance must run on Windows."
}
if ($NetworkMode -ne "Pair" -and $NetworkMode -ne "Skip" -and $NetworkPort -eq 0) {
    throw "-NetworkPort is required for -NetworkMode $NetworkMode."
}
if ($RequireHostLoss -and $NetworkMode -eq "Server") {
    throw "-RequireHostLoss requires a paired or client network mode."
}
if ($RequireHostLoss -and $NetworkSoakSeconds -gt 0) {
    throw "-RequireHostLoss cannot be combined with -NetworkSoakSeconds."
}
if ($RequireHostLoss -and $RequireReconnect) {
    throw "-RequireHostLoss cannot be combined with -RequireReconnect."
}

$resolvedExecutable = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $resolvedExecutable -PathType Leaf)) {
    throw "Windows executable is not a regular file: $resolvedExecutable"
}

$resolvedEvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $resolvedEvidenceDirectory -Force | Out-Null
$clientReportPath = Join-Path $resolvedEvidenceDirectory "windows-client-qualification.json"
$networkReportPath = Join-Path $resolvedEvidenceDirectory "windows-network-qualification.json"
$acceptanceReportPath = Join-Path $resolvedEvidenceDirectory "native-windows-acceptance.json"
$metadataPath = Join-Path $resolvedEvidenceDirectory "build-metadata.json"
$clientScript = Join-Path $PSScriptRoot "qualify_windows_client.ps1"
$networkScript = Join-Path $PSScriptRoot "qualify_windows_network.ps1"

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Resolve-OptionalFile([string]$ExplicitPath, [string[]]$Candidates) {
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return (Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop).Path
    }
    foreach ($candidate in $Candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

$executableDirectory = Split-Path -Parent $resolvedExecutable
$manifestSource = Resolve-OptionalFile $Manifest @(
    (Join-Path $executableDirectory "manifest.json"),
    (Join-Path (Split-Path -Parent $executableDirectory) "manifest.json")
)
$hashesSource = Resolve-OptionalFile $Hashes @(
    (Join-Path $executableDirectory "SHA256SUMS"),
    (Join-Path (Split-Path -Parent $executableDirectory) "SHA256SUMS")
)
$manifestObject = if ($null -ne $manifestSource) { Read-JsonFile $manifestSource } else { $null }
$executableHash = (Get-FileHash -LiteralPath $resolvedExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
if ($null -ne $manifestObject -and $null -ne $manifestObject.artifacts) {
    $artifactName = [IO.Path]::GetFileName($resolvedExecutable)
    $manifestHashProperty = $manifestObject.artifacts.PSObject.Properties[$artifactName]
    if ($null -ne $manifestHashProperty -and $manifestHashProperty.Value.ToLowerInvariant() -ne $executableHash) {
        throw "Executable hash does not match build manifest: $artifactName"
    }
}
if ($null -ne $manifestSource) {
    Copy-Item -LiteralPath $manifestSource -Destination (Join-Path $resolvedEvidenceDirectory "build-manifest.json") -Force
}
if ($null -ne $hashesSource) {
    Copy-Item -LiteralPath $hashesSource -Destination (Join-Path $resolvedEvidenceDirectory "SHA256SUMS") -Force
}
function Get-NativeGpuMetadata {
    try {
        return @(
            Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
                ForEach-Object {
                    [ordered]@{
                        driver_date = [string]$_.DriverDate
                        driver_version = [string]$_.DriverVersion
                        name = [string]$_.Name
                    }
                }
        )
    } catch {
        return @()
    }
}

$gpuMetadata = @(Get-NativeGpuMetadata)

$metadata = [ordered]@{
    commit = if ($null -ne $manifestObject) { $manifestObject.commit } else { $null }
    executable = [IO.Path]::GetFileName($resolvedExecutable)
    executable_sha256 = $executableHash
    generated_utc = [DateTime]::UtcNow.ToString("o")
    godot_version = if ($null -ne $manifestObject) { $manifestObject.godot_version } else { $null }
    manifest = if ($null -ne $manifestSource) { "build-manifest.json" } else { $null }
    hashes = if ($null -ne $hashesSource) { "SHA256SUMS" } else { $null }
    os = [Environment]::OSVersion.VersionString
    preset = if ($null -ne $manifestObject) { $manifestObject.preset } else { $null }
    runtime = [Environment]::Version.ToString()
    gpu = $gpuMetadata
}
$metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

$clientRun = [ordered]@{ status = "not_run"; error = $null }
$clientReport = $null
try {
    $clientArguments = @{
        Executable = $resolvedExecutable
        Report = $clientReportPath
        TimeoutSeconds = $TimeoutSeconds
        RequireContentWorkflow = $true
    }
    if ($RequirePhysicalInput) {
        $clientArguments.RequirePhysicalInput = $true
    }
    & $clientScript @clientArguments
    $clientRun.status = "pass"
} catch {
    $clientRun.status = "fail"
    $clientRun.error = $_.Exception.Message
}
$clientReport = Read-JsonFile $clientReportPath

$networkRun = [ordered]@{ status = "not_run"; error = $null }
$networkReport = $null
if ($NetworkMode -ne "Skip") {
    try {
        $networkArguments = @{
            Executable = $resolvedExecutable
            Report = $networkReportPath
            TimeoutSeconds = $TimeoutSeconds
            Port = $NetworkPort
            Role = $NetworkMode
            ServerAddress = $ServerAddress
            SoakSeconds = $NetworkSoakSeconds
        }
        if ($RequireReconnect) {
            $networkArguments.RequireReconnect = $true
        }
        if ($RequireHostLoss) {
            $networkArguments.RequireHostLoss = $true
        }
        & $networkScript @networkArguments
        $networkRun.status = "pass"
    } catch {
        $networkRun.status = "fail"
        $networkRun.error = $_.Exception.Message
    }
    $networkReport = Read-JsonFile $networkReportPath
}

$clientPassed = $clientRun.status -eq "pass" -and $null -ne $clientReport -and $clientReport.status -eq "pass"
$networkPassed = (
    ($NetworkMode -eq "Skip") -or
    ($networkRun.status -eq "pass" -and $null -ne $networkReport -and $networkReport.status -eq "pass")
)
$remaining = [System.Collections.Generic.List[string]]::new()
if (-not $RequirePhysicalInput) {
    $remaining.Add("native-physical-input")
}
if ($NetworkMode -eq "Skip") {
    $remaining.Add("local-enet-multi-process")
} elseif ($NetworkMode -ne "Pair") {
    $remaining.Add("complete-local-enet-peer-pair")
}
$remaining.Add("direct-enet-wan-soak-reconnect-host-loss")
$remaining.Add("steam-relay-p2p-two-account-session")

$report = [ordered]@{
    client = $clientReport
    client_launcher = $clientRun
    closure_eligible = $false
    generated_utc = [DateTime]::UtcNow.ToString("o")
    metadata = "build-metadata.json"
    network = $networkReport
    network_launcher = $networkRun
    network_mode = $NetworkMode
    host_loss_required = [bool]$RequireHostLoss
    remaining_gates = $remaining
    schema = "modus.windows-native-acceptance/v1"
    status = if ($clientPassed -and $networkPassed) { "pass" } else { "fail" }
}
$report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $acceptanceReportPath -Encoding UTF8

if ($report.status -ne "pass") {
    throw "Native Windows acceptance execution failed; report: $acceptanceReportPath"
}
Write-Output "PASS: native Windows acceptance evidence $resolvedEvidenceDirectory"
