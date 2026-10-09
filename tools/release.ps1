# Publishes a playtest build: builds the game, then creates a GitHub Release
# (tag v<version>) with the zip attached. Publishing the release triggers
# .github/workflows/discord-release.yml, which announces it in Discord #builds.
#
# Usage:  pwsh tools/release.ps1           (build and publish)
#         pwsh tools/release.ps1 -DryRun   (check everything and show the notes; publish nothing)
#
# Before running: bump config/version in project.godot, optionally write
# docs/releases/v<version>.md (highlights / what to test), commit, and push main.

param([switch]$DryRun)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$repo = "Tristan2828/GameTest"

function Fail([string]$message) {
	Write-Host "FAILED: $message" -ForegroundColor Red
	exit 1
}

$versionLine = Select-String -Path (Join-Path $project "project.godot") -Pattern '^config/version="(.+)"' | Select-Object -First 1
if (-not $versionLine) { Fail "no config/version in project.godot" }
$version = $versionLine.Matches[0].Groups[1].Value
$tag = "v$version"

# Releases come from exactly what's on GitHub's main, so the tag matches the code.
if (git -C $project status --porcelain) { Fail "uncommitted changes. Commit (and push) them first." }
$branch = git -C $project rev-parse --abbrev-ref HEAD
if ($branch -ne "main") { Fail "on branch '$branch'. Release from main." }
git -C $project fetch --quiet --tags origin
$head = git -C $project rev-parse HEAD
$remoteHead = git -C $project rev-parse origin/main
if ($head -ne $remoteHead) { Fail "local main and origin/main differ. Push or pull first." }
if (git -C $project tag --list $tag) { Fail "$tag already exists. Bump config/version in project.godot." }

# Notes: the optional hand-written highlights, then the commits since the last release.
$notes = [System.Collections.Generic.List[string]]::new()
$highlights = Join-Path $project "docs\releases\$tag.md"
if (Test-Path $highlights) {
	$notes.AddRange([string[]](Get-Content $highlights))
	$notes.Add("")
} else {
	Write-Host "Note: no docs/releases/$tag.md, so the release only lists commits." -ForegroundColor Yellow
}
$previousTag = git -C $project describe --tags --abbrev=0 2>$null
if ($previousTag) {
	$notes.Add("### Changes since $previousTag")
	git -C $project log --format="- %s" "$previousTag..HEAD" | ForEach-Object { $notes.Add($_) }
	$notes.Add("")
}
$notes.Add("**Download** ``GameTest-$version-windows.zip`` below, unzip it, and run ``GameTest.exe``. Everyone in a game needs the same version.")
$notesFile = Join-Path ([System.IO.Path]::GetTempPath()) "GameTest-$tag-notes.md"
$notes | Set-Content -Encoding utf8 $notesFile

Write-Host "Release $tag from $($head.Substring(0, 7))" -ForegroundColor Cyan
Write-Host "----- release notes -----"
Get-Content $notesFile | Write-Host
Write-Host "-------------------------"
if ($DryRun) {
	Write-Host "Dry run: nothing built or published." -ForegroundColor Green
	exit 0
}

& (Join-Path $PSScriptRoot "build.ps1")
if ($LASTEXITCODE -ne 0) { Fail "build failed" }
$zip = Join-Path $project "builds\GameTest-$version-windows.zip"
if (-not (Test-Path $zip)) { Fail "missing $zip" }

# gh creates the tag on GitHub at this commit, uploads the zip, then publishes.
gh release create $tag $zip --repo $repo --target $head --title "GameTest $tag" --notes-file $notesFile
if ($LASTEXITCODE -ne 0) { Fail "gh release create failed" }
git -C $project fetch --quiet --tags origin
Write-Host "OK: https://github.com/$repo/releases/tag/$tag" -ForegroundColor Green
Write-Host "    Discord #builds gets the announcement from GitHub Actions in about a minute." -ForegroundColor Green
