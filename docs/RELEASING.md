# Releasing playtest builds

Builds are published as **GitHub Releases** on the public repo
[Tristan2828/GameTest](https://github.com/Tristan2828/GameTest/releases) and announced
automatically in the playtest **Discord**. No bots: only Discord webhooks.

## Every release

1. Bump `config/version` in `project.godot` (e.g. `0.12.0` -> `0.13.0`). Friends can only play
   together on the same version, so every build you send needs a new number.
2. Optional: write `docs/releases/v<version>.md` with highlights and "what to test".
   It becomes the top of the release notes; the commits since the last release are listed under it.
3. Commit and push `main`.
4. Preview, then publish:
   ```powershell
   pwsh tools/release.ps1 -DryRun   # checks + shows the notes, publishes nothing
   pwsh tools/release.ps1           # builds, creates release v<version> with the zip
   ```
5. About a minute later, the release appears in Discord `#builds`.
6. Players on an older version see "Version X is out!" with an **Update now** button on the
   title screen (in every version after v0.14.0). It downloads the zip from this release, swaps `GameTest.exe`
   and restarts. So keep the asset name `GameTest-<version>-windows.zip` with `GameTest.exe`
   at its root, and never publish a release with a lower version than the last one.

`release.ps1` refuses to run unless you are on `main`, have no uncommitted changes, are pushed
to GitHub, and the version's tag doesn't exist yet.

## How it works

- `tools/release.ps1` runs `tools/build.ps1`, then `gh release create v<version>` with the zip.
- Publishing a release triggers `.github/workflows/discord-release.yml` (GitHub Actions), which
  posts the notes and download link to the `#builds` webhook.
- The webhook URL is the repo secret `DISCORD_BUILDS_WEBHOOK`. Only GitHub Actions can read it;
  it is never stored on your PC or in the code.
- Commits use the GitHub noreply email (set in this repo's git config) so your real email stays private.

## Discord server layout

| Category | Channels |
|---|---|
| INFO | `#welcome`, `#announcements` (read-only) |
| BUILDS | `#builds` (read-only; release announcements via webhook) |
| DEV | `#dev-log` (read-only; GitHub commit/release feed via webhook) |
| PLAYTEST | `#feedback`, `#bug-reports` (forum), `#clips-and-screenshots` |
| SOCIAL | `#general`, `#lfg`, Play Session (voice) |

**Read-only channel:** Edit Channel (gear) -> Permissions -> `@everyone` -> **Send Messages** = red X.
Set it on a category to apply to all its synced channels. Webhooks ignore these permissions.

## One-time setup (already done unless noted)

- **`#builds` webhook secret:** in Discord, `#builds` gear -> Integrations -> Webhooks -> New Webhook -> Copy URL, then
  `gh secret set DISCORD_BUILDS_WEBHOOK --repo Tristan2828/GameTest` and paste it.
  To replace a leaked or deleted webhook, make a new one and run the same command.
- **`#dev-log` feed:** GitHub repo -> Settings -> Webhooks -> Add webhook:
  - Payload URL: the `#dev-log` webhook URL with `/github` added on the end
  - Content type: `application/json`
  - Events: "Let me select individual events" -> **Pushes** and **Releases** only
  
  Discord understands GitHub's format at that `/github` address, so no code is needed.
- **In-game feedback webhook (v0.16.0, not done yet):** the game's "Send feedback" screen posts to a Discord channel.
  In Discord, `#feedback` gear -> Integrations -> Webhooks -> New Webhook (name it "GameTest feedback") -> Copy URL.
  Paste the link alone into `feedback_webhook.txt` in the repo folder (git-ignored: it is **never** committed).
  `tools/build.ps1` (and so `release.ps1`) bakes it into the exported game; without it the screen copies messages to
  the clipboard instead. Anyone determined could dig the link out of the exe and post to that one channel: if that
  ever happens, delete the webhook in Discord, make a new one, update the file and release again.

## Troubleshooting

- **"Sending isn't set up in this build"** on the feedback screen: `feedback_webhook.txt` was missing or not a
  Discord webhook link when the build was made (build.ps1 prints a note). Fix the file and rebuild.

- **No post in `#builds`:** open the repo's **Actions** tab -> "Announce release in Discord".
  A red run shows the error (usually the secret is missing or the webhook was deleted). After fixing,
  re-send with **Run workflow** and the tag (e.g. `v0.12.0`); no new release needed.
- **`#dev-log` silent:** repo Settings -> Webhooks -> the webhook -> **Recent Deliveries** shows each
  attempt and Discord's reply; **Redeliver** retries one.
- **Wrong release:** delete it on GitHub (Releases -> the release -> Delete) and delete its tag
  (`git push origin :refs/tags/v<version>` then `git tag -d v<version>`), fix, and run the script again.
  The Discord post has to be deleted by hand.
