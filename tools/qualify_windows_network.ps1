[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Executable,
    [string]$Report = "windows-network-qualification.json",
    [ValidateRange(10, 600)]
    [int]$TimeoutSeconds = 90,
    [ValidateRange(0, 65535)]
    [int]$Port = 0,
    [ValidateSet("Pair", "Server", "Client")]
    [string]$Role = "Pair",
    [string]$ServerAddress = "127.0.0.1"
)

$ErrorActionPreference = "Stop"
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "Native Windows networking qualification must run on Windows."
}
if ($Role -ne "Pair" -and $Port -eq 0) {
    throw "-Port is required for -Role $Role so the other machine can reach the session."
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

$resolvedReport = [IO.Path]::GetFullPath($Report)
$reportDirectory = Split-Path -Parent $resolvedReport
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$reportStem = [IO.Path]::GetFileNameWithoutExtension($resolvedReport)
$serverOut = Join-Path $reportDirectory ("{0}.server.stdout.log" -f $reportStem)
$serverErr = Join-Path $reportDirectory ("{0}.server.stderr.log" -f $reportStem)
$clientOut = Join-Path $reportDirectory ("{0}.client.stdout.log" -f $reportStem)
$clientErr = Join-Path $reportDirectory ("{0}.client.stderr.log" -f $reportStem)
Remove-Item -LiteralPath $serverOut, $serverErr, $clientOut, $clientErr -Force -ErrorAction SilentlyContinue
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

function Wait-ServerReady([System.Diagnostics.Process]$Process, [string]$OutputPath, [string]$ErrorPath, [int]$ExpectedPort, [int]$Timeout) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($Process.HasExited) {
            throw "Native Windows network server exited before readiness. stderr: $(Get-Content $ErrorPath -Raw -ErrorAction SilentlyContinue)"
        }
        if (Select-String -LiteralPath $OutputPath -Pattern ("^MODUS_WINDOWS_NETWORK_READY={0}$" -f $ExpectedPort)) {
            return
        }
        Start-Sleep -Milliseconds 250
    }
    throw "Native Windows network server did not become ready within ${Timeout}s"
}

try {
    if ($Role -eq "Pair" -or $Role -eq "Server") {
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
        Wait-ServerReady $server $serverOut $serverErr $Port $TimeoutSeconds
    }

    if ($Role -eq "Pair" -or $Role -eq "Client") {
        $client = Start-Process -FilePath $resolvedExecutable `
            -ArgumentList @(
                "--headless",
                "--windows-qualification-network-client",
                "--windows-qualification-network-address",
                $ServerAddress,
                "--windows-qualification-network-port",
                "$Port"
            ) `
            -RedirectStandardOutput $clientOut `
            -RedirectStandardError $clientErr `
            -PassThru
    }

    if ($null -ne $client -and -not $client.WaitForExit($TimeoutSeconds * 1000)) {
        throw "Native Windows network client exceeded ${TimeoutSeconds}s"
    }
    if ($null -ne $server -and -not $server.WaitForExit($TimeoutSeconds * 1000)) {
        throw "Native Windows network server did not finish within ${TimeoutSeconds}s"
    }
    if ($null -ne $client) {
        $client.Refresh()
        if ($client.ExitCode -ne 0) {
            throw "Native Windows network client exited with code $($client.ExitCode). stderr: $(Get-Content $clientErr -Raw -ErrorAction SilentlyContinue)"
        }
    }
    if ($null -ne $server) {
        $server.Refresh()
        if ($server.ExitCode -ne 0) {
            throw "Native Windows network server exited with code $($server.ExitCode). stderr: $(Get-Content $serverErr -Raw -ErrorAction SilentlyContinue)"
        }
    }

    $serverReport = if ($null -ne $server) { Read-NetworkReport $serverOut } else { $null }
    $clientReport = if ($null -ne $client) { Read-NetworkReport $clientOut } else { $null }
    if ($Role -eq "Pair" -and ($null -eq $serverReport -or $null -eq $clientReport)) {
        throw "Native Windows network reports were not emitted. server stderr: $(Get-Content $serverErr -Raw -ErrorAction SilentlyContinue); client stderr: $(Get-Content $clientErr -Raw -ErrorAction SilentlyContinue)"
    }
    if ($Role -eq "Server" -and $null -eq $serverReport) {
        throw "Native Windows network server report was not emitted. stderr: $(Get-Content $serverErr -Raw -ErrorAction SilentlyContinue)"
    }
    if ($Role -eq "Client" -and $null -eq $clientReport) {
        throw "Native Windows network client report was not emitted. stderr: $(Get-Content $clientErr -Raw -ErrorAction SilentlyContinue)"
    }

    $status = if ($Role -eq "Pair") {
        $serverReport.status -eq "pass" -and $serverReport.listening -and $clientReport.status -eq "pass" -and $clientReport.connected
    } elseif ($Role -eq "Server") {
        $serverReport.status -eq "pass" -and $serverReport.listening
    } else {
        $clientReport.status -eq "pass" -and $clientReport.connected
    }
    $reportObject = [ordered]@{
        client = $clientReport
        logs = [ordered]@{
            client_stderr = [IO.Path]::GetFileName($clientErr)
            client_stdout = [IO.Path]::GetFileName($clientOut)
            server_stderr = [IO.Path]::GetFileName($serverErr)
            server_stdout = [IO.Path]::GetFileName($serverOut)
        }
        mode = $Role
        port = $Port
        schema = "modus.windows-native-network-qualification/v1"
        server = $serverReport
        server_address = $ServerAddress
        status = if ($status) { "pass" } else { "fail" }
        transport = "ENet native multi-process"
    }
    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReport -Encoding UTF8
    if ($reportObject.status -ne "pass") {
        throw "Native Windows network qualification failed; report: $Report"
    }
    Write-Output "PASS: native Windows network report $Report"
}
finally {
    foreach ($process in @($client, $server)) {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
