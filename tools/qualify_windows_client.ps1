[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Executable,
    [string]$Report = "windows-client-qualification.json",
    [ValidateRange(10, 600)]
    [int]$TimeoutSeconds = 90,
    [switch]$RequirePhysicalInput,
    [switch]$RequireContentWorkflow
)
$ErrorActionPreference = "Stop"
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "Native Windows qualification must run on Windows; Wine and cross-export are supplementary only."
}

$resolvedExecutable = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $resolvedExecutable -PathType Leaf)) {
    throw "Windows client executable is not a regular file: $resolvedExecutable"
}

$resolvedReport = [IO.Path]::GetFullPath($Report)
$reportDirectory = Split-Path -Parent $resolvedReport
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$reportStem = [IO.Path]::GetFileNameWithoutExtension($resolvedReport)
$stdoutPath = Join-Path $reportDirectory ("{0}.stdout.log" -f $reportStem)
$stderrPath = Join-Path $reportDirectory ("{0}.stderr.log" -f $reportStem)
Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
$process = $null
$arguments = @("--windows-qualification")
if ($RequirePhysicalInput) {
    Write-Output "Press W, E, or Space in the MODUS client window when prompted."
    $arguments += "--windows-qualification-physical-input"
}
if ($RequireContentWorkflow) {
    $arguments += "--windows-qualification-content"
}
try {
    $process = Start-Process -FilePath $resolvedExecutable `
        -ArgumentList $arguments `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force
        throw "Windows client qualification exceeded ${TimeoutSeconds}s"
    }
    $process.Refresh()

    $match = Select-String -LiteralPath $stdoutPath `
        -Pattern '^MODUS_WINDOWS_QUALIFICATION_JSON=(.+)$' |
        Select-Object -Last 1
    if ($null -eq $match) {
        $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
        throw "Qualification report was not emitted. stderr: $stderr"
    }
    $reportObject = $match.Matches[0].Groups[1].Value | ConvertFrom-Json

    $reportObject | Add-Member -NotePropertyName logs -NotePropertyValue ([ordered]@{
        stdout = [IO.Path]::GetFileName($stdoutPath)
        stderr = [IO.Path]::GetFileName($stderrPath)
    }) -Force
    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReport -Encoding UTF8
    if ($process.ExitCode -ne 0 -or $reportObject.status -ne "pass") {
        throw "Windows client qualification failed; report: $Report"
    }

    foreach ($check in @("platform", "renderer", "input", "save", "network", "content_workflow")) {
        if ($reportObject.checks.$check.status -ne "pass") {
            throw "Windows client qualification check failed: $check"
        }
    }
    Write-Output "PASS: native Windows client qualification report $Report"
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}
