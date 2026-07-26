---
name: "publish"
description: "Publish Scamp Micro Deck by requiring a clean worktree, running the version bump skill, running mise push, then running mise publish. Use when the user asks to publish, release, upload, or ship Scamp Micro Deck."
---

# Publish

Use this skill when the user wants to publish Scamp Micro Deck.

`mise publish` archives, uploads and submits the macOS version to App Review,
signs for Developer ID, notarizes, and publishes the notarized zip to Codeberg
and GitHub Releases.

Requires these environment variables in `.env`:
- `CODEBERG_TOKEN` — Codeberg personal access token
- `GITHUB_TOKEN` — GitHub personal access token
- `APPLE_KEY_ID` — App Store Connect API key ID
- `APPLE_KEY_P8_BASE64` — Base64-encoded .p8 private key
- `APPLE_ISSUER_ID` — App Store Connect API issuer ID

## Workflow

1. Verify there are no uncommitted changes before doing anything else:
   - Run `git status --porcelain`.
   - If there is any output, stop. Tell the user the worktree must be clean before publishing and summarize the dirty files.
2. Capture the current local state so the final summary can say what got pushed:
   - Record the current branch and `HEAD`.
   - Record recent commits that are not on the configured remotes when that information is available.
3. Run the `version bump` skill exactly as written.
   - If the version bump skill stops or fails, do not publish.
4. After the version bump commit succeeds, run `mise push`.
   - If `mise push` fails, report the failure and do not publish.
5. After `mise push` succeeds, run `mise publish`.
   - Do not manually reimplement the publish script.
   - It preserves the existing App Store release timing and submits the uploaded
     macOS build with `Bug fixes.` in every localization.
   - If `mise publish` fails, report the failure and where it stopped.
6. When done, summarize:
   - Old version and new version.
   - The version bump reasoning.
   - The commits that got pushed, including the `Version` commit.
   - Whether the App Store Connect upload and App Review submission succeeded.
   - Whether the GitHub and Codeberg releases were created.

## Guidance

- Keep the clean-worktree check strict. Do not stash, commit, or discard unrelated changes unless the user explicitly asks.
- Prefer `mise publish` output as the source of truth for what uploaded.
- Mention that `mise push` ran before archiving, so the summary should identify the pushed branch and remotes when available.
