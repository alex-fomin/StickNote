---
name: sparkle-release
description: >-
  Automates StickNote Sparkle releases: build Release DMG, sign the DMG with
  Sparkle tools, regenerate packaging/appcast.xml for GitHub Release download
  URLs, and ship. Use when cutting a Sparkle-updated release, publishing DMGs to
  GitHub Releases, or refreshing the appcast after the publish-to-dmg workflow.
---

# Sparkle release automation (StickNote)

## When to use

- User wants to **ship an update** that Sparkle clients will pick up (`SUFeedURL` → [packaging/appcast.xml](packaging/appcast.xml)).
- Combining **DMG build** ([scripts/publish-dmg.sh](scripts/publish-dmg.sh)), **`sign_update` / `generate_appcast`**, and **GitHub Releases** asset URLs.

## Prerequisites

- **Ed25519 keypair**: private key in the **login keychain** (from `generate_keys`); **`SUPublicEDKey`** in [StickNote/Info.plist](StickNote/Info.plist) must match (see [packaging/SPARKLE_RELEASE.md](packaging/SPARKLE_RELEASE.md)).
- **Sparkle CLI**: do **not** use Homebrew’s deprecated `sparkle` formula. Either:
  - Set **`SPARKLE_ROOT`** to the `bin/` directory of an official [Sparkle release](https://github.com/sparkle-project/Sparkle/releases) tree (e.g. `~/Developer/Sparkle-2.9.1/bin`), **or**
  - Run **`xcodebuild`** once so tools exist at `.build/SourcePackages/artifacts/sparkle/Sparkle/bin/`.
- **`create-dmg`** and DMG background as in [publish-to-dmg](../publish-to-dmg/SKILL.md).

## Scripted workflow ([scripts/sparkle-release.sh](scripts/sparkle-release.sh))

From the repo root:

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `./scripts/sparkle-release.sh build` | Release build + `dist/StickNote-<version>.dmg` (optional: `minor` or `major` as second arg). |
| 2 | Notarize / staple | Same as your usual distribution workflow (not covered by the script). |
| 3 | GitHub Release | Create release tag (e.g. `v1.3.0`), upload **`StickNote-<version>.dmg`** as an asset. Name must match what the download URL will use. |
| 4 | `./scripts/sparkle-release.sh appcast v1.3.0` | Regenerates **`packaging/appcast.xml`** with **`generate_appcast`**, using prefix `https://github.com/<owner>/<repo>/releases/download/v1.3.0/`. Override repo with **`GITHUB_REPO=owner/repo`**. |
| 5 | Commit | `git add packaging/appcast.xml && git commit && git push` so the raw URL in Info.plist serves the new feed. |

**Signing only (debug):** `./scripts/sparkle-release.sh sign` runs **`sign_update`** on `dist/StickNote-<MARKETING_VERSION>.dmg` (prints signature/length for manual appcast editing).

## Version and URL alignment

- **`MARKETING_VERSION`** / **`CURRENT_PROJECT_VERSION`** in the Xcode project, **`dist/StickNote-x.y.z.dmg`**, **Git tag** passed to `appcast` (e.g. `v1.3.0`), and the **asset filename** on the release must stay consistent with Sparkle’s [versioning rules](https://sparkle-project.org/documentation/publishing/).
- Default download host: **`GITHUB_REPO=alex-fomin/StickNote`**. Change if the canonical repo differs.

## Agent behavior

1. Prefer **`./scripts/sparkle-release.sh`** over hand-rolled `sign_update` / `generate_appcast` invocations when the user wants a full release.
2. Do **not** bump semver unless the user asks (same rule as [publish-to-dmg](../publish-to-dmg/SKILL.md)).
3. After changing **`appcast.xml`**, remind to **push** so `SUFeedURL` updates.
4. Never commit or paste **private** Sparkle keys; only **`SUPublicEDKey`** belongs in the repo.

## See also

- [packaging/SPARKLE_RELEASE.md](packaging/SPARKLE_RELEASE.md) — keys, manual steps, and operational notes.
