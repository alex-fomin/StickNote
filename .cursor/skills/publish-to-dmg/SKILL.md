---
name: publish-to-dmg
description: >-
  Builds StickNote Release, creates a compressed DMG under dist/ named from the
  current MARKETING_VERSION, and opens the DMG. Optionally bumps semver (minor or
  major) only when the user explicitly asks. Use when publishing or shipping a
  DMG, release build outside the App Store, or the local DMG workflow.
---

# Publish to DMG (StickNote)

## When to use

- User wants a **release build** packaged as **DMG** for distribution outside the Mac App Store.
- **Do not bump version** unless the user clearly asks to bump **minor**, **major**, or “release version”.

## Workflow

1. **Version bump (optional, by request only)**
   - If the user asks to bump **minor**: run `./scripts/publish-dmg.sh minor` (e.g. `1.2.3` → `1.3.0`).
   - If they ask for **major**: run `./scripts/publish-dmg.sh major` (e.g. `1.2.3` → `2.0.0`).
   - Otherwise: run **`./scripts/publish-dmg.sh`** with **no arguments** — this **does not edit** `project.pbxproj`; it uses the current **`MARKETING_VERSION`** for the DMG filename.

2. **Stop the running app** (so the build can replace the binary): `killall StickNote 2>/dev/null || true`  
   (The script does this automatically.)

3. The script **builds Release** with `-derivedDataPath .build`, writes **`dist/StickNote-<version>.dmg`** (version = current or post-bump), then **`open`s that DMG**.

The DMG uses **`create-dmg` from Homebrew** (`brew install create-dmg`) with **`packaging/dmg/installer_background.png`**: light gradient plus a **left-to-right arrow** (StickNote icon and **Applications** alias are positioned by `create-dmg` on top of this background). The repo does not ship a vendored copy of `create-dmg`.

## Paths

| Artifact | Location |
|----------|----------|
| Release app | `.build/Build/Products/Release/StickNote.app` |
| DMG | `dist/StickNote-<MARKETING_VERSION>.dmg` |
| DMG background | `packaging/dmg/installer_background.png` |

## Notes

- Requires **Xcode**, **`create-dmg`** on `PATH` (Homebrew: `brew install create-dmg`), **`hdiutil`**, and **Finder/AppleScript** (used by `create-dmg` to set icon positions and background).
- **`dist/`** is gitignored.
- DMG packaging uses **Release**, not Debug.
- If `xcodebuild` fails, fix errors and re-run.
