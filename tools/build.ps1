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

if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Force $outDir | Out-Null

& $godot --headless --path $project --import 2>&1 | Out-Null
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
