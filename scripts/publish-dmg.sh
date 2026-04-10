#!/usr/bin/env bash
# Build Release, pack StickNote.app into dist/StickNote-<version>.dmg, open the DMG.
# Version bump (MARKETING_VERSION + matching CURRENT_PROJECT_VERSION) only when
# you pass "minor" or "major".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PBX="StickNote.xcodeproj/project.pbxproj"
BUMP_KIND="${1:-}"

if [[ -n "$BUMP_KIND" && "$BUMP_KIND" != "minor" && "$BUMP_KIND" != "major" ]]; then
  echo "Usage: $0 [minor|major]" >&2
  echo "  (no args)  Build and DMG using current MARKETING_VERSION — no project edits" >&2
  echo "  minor      Bump minor semver, then build and DMG (e.g. 1.2.3 -> 1.3.0)" >&2
  echo "  major      Bump major semver, then build and DMG (e.g. 1.2.3 -> 2.0.0)" >&2
  exit 1
fi

CURRENT="$(grep -m1 'MARKETING_VERSION' "$PBX" | sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' | tr -d ' ')"
if [[ -z "$CURRENT" ]]; then
  echo "Could not read MARKETING_VERSION from $PBX" >&2
  exit 1
fi

VERSION_LABEL="$CURRENT"

if [[ -n "$BUMP_KIND" ]]; then
  IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$CURRENT"
  V_MAJOR="${V_MAJOR:-0}"
  V_MINOR="${V_MINOR:-0}"
  V_PATCH="${V_PATCH:-0}"

  if [[ "$BUMP_KIND" == "major" ]]; then
    V_MAJOR=$((V_MAJOR + 1))
    V_MINOR=0
    V_PATCH=0
  else
    V_MINOR=$((V_MINOR + 1))
    V_PATCH=0
  fi

  NEW="${V_MAJOR}.${V_MINOR}.${V_PATCH}"
  echo "Version bump: $CURRENT -> $NEW ($BUMP_KIND)"

  perl -pi -e "s/MARKETING_VERSION = \\Q$CURRENT\\E/MARKETING_VERSION = $NEW/g" "$PBX"
  perl -pi -e "s/CURRENT_PROJECT_VERSION = \\Q$CURRENT\\E/CURRENT_PROJECT_VERSION = $NEW/g" "$PBX"
  VERSION_LABEL="$NEW"
else
  echo "No version bump; packaging as $VERSION_LABEL"
fi

killall StickNote 2>/dev/null || true

xcodebuild \
  -project StickNote.xcodeproj \
  -scheme StickNote \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  build

APP=".build/Build/Products/Release/StickNote.app"
if [[ ! -d "$APP" ]]; then
  echo "Build output not found: $APP" >&2
  exit 1
fi

mkdir -p dist
DMG="dist/StickNote-${VERSION_LABEL}.dmg"
rm -f "$DMG"

# Staging folder: create-dmg expects a directory containing the .app (not the .app alone).
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/sticknote-dmg.XXXXXX")"
trap 'rm -rf "${STAGE:-}"' EXIT
cp -R "$APP" "$STAGE/StickNote.app"

CREATE_DMG="$(command -v create-dmg || true)"
BG="$ROOT/packaging/dmg/installer_background.png"
if [[ -z "$CREATE_DMG" || ! -f "$BG" ]]; then
  echo "Missing DMG tooling: install create-dmg (brew install create-dmg) and ensure packaging/dmg/installer_background.png exists." >&2
  exit 1
fi

# Standard layout: background with arrow (800×400), app icon left, Applications drop right.
"$CREATE_DMG" \
  --volname "StickNote" \
  --background "$BG" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "StickNote.app" 175 120 \
  --hide-extension "StickNote.app" \
  --app-drop-link 600 120 \
  "$DMG" \
  "$STAGE"

echo "Created $DMG"
open "$DMG"
