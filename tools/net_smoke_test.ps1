# Online smoke test: starts a headless host and a headless client on this PC, both
# on autopilot (moving, dashing, shooting enemies), then prints their reports.
#
# Passes when:
#   - the client connected,
#   - the host credited damage to the client's peer id (client input -> host sim works),
#   - neither process logged a script error.
#
# Usage:  pwsh tools/net_smoke_test.ps1 [-Port 7810] [-Seconds 6] [-ClientCharacter 0-3]
# The client plays the Wanderer by default: the Gravekeeper's short-range shotgun
# often hits nothing in a short run. -ClientCharacter -1 lets autopilot pick at random.
# Set $env:GODOT to override the Godot console executable path.

param(
	[int]$Port = 7810,
	[double]$Seconds = 12,
	[int]$ClientCharacter = 0
)

$godot = if ($env:GODOT) { $env:GODOT } else { "C:\Code Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" }
$project = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path ([System.IO.Path]::GetTempPath()) "gametest_smoke"
New-Item -ItemType Directory -Force $logDir | Out-Null

function Start-Peer([string]$name, [string[]]$gameArgs) {
	$arguments = @("--headless", "--path", "`"$project`"", "--") + $gameArgs
	return Start-Process -FilePath $godot -ArgumentList $arguments -PassThru -NoNewWindow `
		-RedirectStandardOutput (Join-Path $logDir "$name.out.log") `
		-RedirectStandardError (Join-Path $logDir "$name.err.log")
}

# Refresh Godot's cache first: new `class_name` scripts aren't known until an import runs.
& $godot --headless --path $project --import 2>&1 | Out-Null

$hostProcess = Start-Peer "host" @("--host", "--port=$Port", "--local-only", "--autopilot", "--run-for=$($Seconds + 3)")
Start-Sleep -Seconds 1
$clientArgs = @("--join=127.0.0.1", "--port=$Port", "--autopilot", "--run-for=$Seconds")
if ($ClientCharacter -ge 0) { $clientArgs += "--character=$ClientCharacter" }
$clientProcess = Start-Peer "client" $clientArgs
# If a peer crashes before it can quit, don't wait forever.
$timeoutMs = [int](($Seconds + 15) * 1000)
foreach ($process in @($clientProcess, $hostProcess)) {
	if (-not $process.WaitForExit($timeoutMs)) {
		$process.Kill()
		$timedOut = $true
	}
}

$hostLog = (Get-Content (Join-Path $logDir "host.out.log"), (Join-Path $logDir "host.err.log")) -join "`n"
$clientLog = (Get-Content (Join-Path $logDir "client.out.log"), (Join-Path $logDir "client.err.log")) -join "`n"
Write-Output "===== HOST =====" $hostLog "===== CLIENT =====" $clientLog

$failures = @()
if ($timedOut) { $failures += "a process hung and was killed" }
if ("$hostLog`n$clientLog" -match "SCRIPT ERROR|ERROR:") { $failures += "a process logged an error" }
if ($clientLog -match "Connected as peer (\d+)") {
	$clientId = $Matches[1]
	if ($hostLog -notmatch "damage by peer: .*\b$($clientId): \d+") { $failures += "host saw no damage from client $clientId" }
} else {
	$failures += "client never connected"
}

if ($failures.Count -gt 0) {
	Write-Host "FAILED: $($failures -join '; ')" -ForegroundColor Red
	exit 1
}
Write-Host "OK: client $clientId connected, moved, and its shots damaged enemies on the host." -ForegroundColor Green
