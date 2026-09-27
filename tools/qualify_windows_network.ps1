[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Executable,
    [string]$Report = "windows-network-qualification.json",
    [ValidateRange(10, 600)]
    [int]$TimeoutSeconds = 90,
    [ValidateRange(0, 65535)]
    [int]$Port = 0
)

$ErrorActionPreference = "Stop"
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "Native Windows networking qualification must run on Windows."
}

$resolvedExecutable = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $resolvedExecutable -PathType Leaf)) {
    throw "Windows client executable is not a regular file: $resolvedExecutable"
}

if ($Port -eq 0) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $Port = $listener.LocalEndpoint.Port
    $listener.Stop()
}

$serverOut = Join-Path ([IO.Path]::GetTempPath()) ("modus-windows-network-{0}.server.out" -f [Guid]::NewGuid())
$serverErr = Join-Path ([IO.Path]::GetTempPath()) ("modus-windows-network-{0}.server.err" -f [Guid]::NewGuid())
$clientOut = Join-Path ([IO.Path]::GetTempPath()) ("modus-windows-network-{0}.client.out" -f [Guid]::NewGuid())
$clientErr = Join-Path ([IO.Path]::GetTempPath()) ("modus-windows-network-{0}.client.err" -f [Guid]::NewGuid())
$server = $null
$client = $null

function Read-NetworkReport([string]$Path) {
    $match = Select-String -LiteralPath $Path `
        -Pattern '^MODUS_WINDOWS_NETWORK_JSON=(.+)$' |
        Select-Object -Last 1
    if ($null -eq $match) {
        return $null
    }
    return $match.Matches[0].Groups[1].Value | ConvertFrom-Json
}

try {
    $server = Start-Process -FilePath $resolvedExecutable `
        -ArgumentList @(
            "--headless",
            "--windows-qualification-network-server",
            "--windows-qualification-network-port",
            "$Port"
        ) `
        -RedirectStandardOutput $serverOut `
        -RedirectStandardError $serverErr `
        -PassThru

    $ready = $false
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($server.HasExited) {
            throw "Native Windows network server exited before readiness. stderr: $(Get-Content $serverErr -Raw -ErrorAction SilentlyContinue)"
        }
        if (Select-String -LiteralPath $serverOut -Pattern ("^MODUS_WINDOWS_NETWORK_READY={0}$" -f $Port)) {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $ready) {
        throw "Native Windows network server did not become ready within ${TimeoutSeconds}s"
    }

    $client = Start-Process -FilePath $resolvedExecutable `
        -ArgumentList @(
            "--headless",
            "--windows-qualification-network-client",
            "--windows-qualification-network-port",
            "$Port"
        ) `
        -RedirectStandardOutput $clientOut `
        -RedirectStandardError $clientErr `
        -PassThru

    if (-not $client.WaitForExit($TimeoutSeconds * 1000)) {
        throw "Native Windows network client exceeded ${TimeoutSeconds}s"
    }
    $client.Refresh()
    if (-not $server.WaitForExit($TimeoutSeconds * 1000)) {
        throw "Native Windows network server did not finish within ${TimeoutSeconds}s"
    }
    $server.Refresh()

    $serverReport = Read-NetworkReport $serverOut
    $clientReport = Read-NetworkReport $clientOut
    if ($null -eq $serverReport -or $null -eq $clientReport) {
        throw "Native Windows network reports were not emitted. server stderr: $(Get-Content $serverErr -Raw -ErrorAction SilentlyContinue); client stderr: $(Get-Content $clientErr -Raw -ErrorAction SilentlyContinue)"
    }

    $reportObject = [ordered]@{
        client = $clientReport
        port = $Port
        schema = "modus.windows-native-network-qualification/v1"
        server = $serverReport
        status = if ($serverReport.status -eq "pass" -and $serverReport.listening -and $clientReport.status -eq "pass" -and $clientReport.connected) { "pass" } else { "fail" }
        transport = "ENet native multi-process loopback"
    }
    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Report -Encoding UTF8
    if ($reportObject.status -ne "pass") {
        throw "Native Windows network qualification failed; report: $Report"
    }
    Write-Output "PASS: native Windows multi-process network report $Report"
}
finally {
    foreach ($process in @($client, $server)) {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $serverOut, $serverErr, $clientOut, $clientErr -Force -ErrorAction SilentlyContinue
}
