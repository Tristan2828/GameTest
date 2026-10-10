# Builds the Windows game: a single GameTest.exe (game data embedded) plus a zip
# that's ready to send to friends.
#
# Usage:  pwsh tools/build.ps1
# Output: builds/windows/GameTest.exe and builds/GameTest-<version>-windows.zip
# Needs the Godot 4.7.2 export templates installed (Editor > Manage Export Templates).
# Set $env:GODOT to override the Godot console executable path.

$godot = if ($env:GODOT) { $env:GODOT } else { "C:\Code Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" }
$project = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $project "builds\windows"
$exe = Join-Path $outDir "GameTest.exe"

$versionLine = Select-String -Path (Join-Path $project "project.godot") -Pattern '^config/version="(.+)"' | Select-Object -First 1
$version = if ($versionLine) { $versionLine.Matches[0].Groups[1].Value } else { "dev" }

# Stamp which build this is (shown on the title screen). Not committed.
# In-game feedback posts to a Discord webhook. The link is a secret: it lives in
# the git-ignored feedback_webhook.txt (or $env:GAMETEST_FEEDBACK_WEBHOOK) and only
# goes into the exported game. Without it, the feedback screen copies to the clipboard.
$webhook = $env:GAMETEST_FEEDBACK_WEBHOOK
$webhookFile = Join-Path $project "feedback_webhook.txt"
if (-not $webhook -and (Test-Path $webhookFile)) { $webhook = (Get-Content -Raw $webhookFile).Trim() }
if ($webhook -and $webhook -notmatch '^https://(discord|discordapp)\.com/api/webhooks/') {
	Write-Host "WARNING: feedback_webhook.txt doesn't look like a Discord webhook link; ignoring it." -ForegroundColor Yellow
	$webhook = ""
}
if (-not $webhook) {
	Write-Host "Note: no feedback webhook (feedback_webhook.txt); in-game feedback will copy to the clipboard." -ForegroundColor Yellow
}

$commit = (git -C $project rev-parse --short HEAD 2>$null)
if (-not $commit) { $commit = "unknown" }
$dirty = if (git -C $project status --porcelain 2>$null) { "+changes" } else { "" }
@(
	"[build]",
	"version=""$version""",
	"commit=""$commit$dirty""",
	"date=""$(Get-Date -Format 'yyyy-MM-dd HH:mm')""",
	"",
	"[feedback]",
	"webhook=""$webhook"""
) | Set-Content -Encoding utf8 (Join-Path $project "build_info.cfg")

if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Force $outDir | Out-Null

& $godot --headless --path $project --import 2>&1 | Out-Null
# The exe's icon, drawn from the game's pixel art (export_presets.cfg points at it).
# With the version, name and description it fills in the exe's Properties > Details.
$icon = Join-Path $project "builds\icon.ico"
if (Test-Path $icon) { Remove-Item $icon }
& $godot --headless --path $project -s tools/make_icon.gd -- $icon 2>&1 | Out-Null
if (-not (Test-Path $icon)) {
	Write-Host "FAILED: could not draw the exe icon (tools/make_icon.gd)." -ForegroundColor Red
	exit 1
}
$output = & $godot --headless --path $project --export-release "Windows Desktop" $exe 2>&1 | ForEach-Object { "$_" }
$exitCode = $LASTEXITCODE
$output | Write-Output
if ($exitCode -ne 0 -or -not (Test-Path $exe) -or ($output | Select-String -Pattern "SCRIPT ERROR|ERROR:")) {
	Write-Host "FAILED: export did not complete cleanly (see above)." -ForegroundColor Red
	exit 1
}

Copy-Item (Join-Path $PSScriptRoot "README-friends.txt") (Join-Path $outDir "README.txt")
$zip = Join-Path $project "builds\GameTest-$version-windows.zip"
Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $zip -Force
Write-Host "OK: built $exe" -ForegroundColor Green
Write-Host "    zip for friends: $zip" -ForegroundColor Green
