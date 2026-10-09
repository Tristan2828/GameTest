# Runs all GUT unit tests headless.
# Fails if any test fails OR any script has errors. GUT on its own silently skips
# test files that don't parse and still reports "All tests passed", so we check.
#
# Usage:  pwsh tools/run_tests.ps1
# Set $env:GODOT to override the Godot console executable path.

$godot = if ($env:GODOT) { $env:GODOT } else { "C:\Code Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" }
$project = Split-Path -Parent $PSScriptRoot

# Refresh Godot's cache first: new `class_name` scripts aren't known until an import runs.
& $godot --headless --path $project --import 2>&1 | Out-Null

$output = & $godot --headless --path $project -s addons/gut/gut_cmdln.gd 2>&1 | ForEach-Object { "$_" }
$exitCode = $LASTEXITCODE
$output | Write-Output

if ($output | Select-String -Pattern "SCRIPT ERROR|Parse Error|Failed to load script") {
	Write-Host "FAILED: script errors found (see above)." -ForegroundColor Red
	exit 1
}
if ($exitCode -ne 0) {
	Write-Host "FAILED: GUT reported failing tests." -ForegroundColor Red
	exit $exitCode
}
Write-Host "OK: all tests passed with no script errors." -ForegroundColor Green
