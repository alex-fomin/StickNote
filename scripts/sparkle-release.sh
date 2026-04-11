#!/usr/bin/env bash
# Automate Sparkle steps for StickNote: locate CLI tools, sign DMG, regenerate appcast for GitHub Releases.
# Requires: Xcode-resolved Sparkle artifacts or SPARKLE_ROOT; Ed25519 private key in login keychain (from generate_keys).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PBX="StickNote.xcodeproj/project.pbxproj"

read_marketing_version() {
  local v
  v="$(grep -m1 'MARKETING_VERSION' "$PBX" | sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' | tr -d ' ')"
  if [[ -z "$v" ]]; then
    echo "Could not read MARKETING_VERSION from $PBX" >&2
    exit 1
  fi
  echo "$v"
}

sparkle_bin_dir() {
  if [[ -n "${SPARKLE_ROOT:-}" ]]; then
    if [[ ! -x "${SPARKLE_ROOT%/}/sign_update" ]]; then
      echo "SPARKLE_ROOT must point to a directory containing sign_update and generate_appcast." >&2
      exit 1
    fi
    echo "${SPARKLE_ROOT%/}"
    return
  fi
  local base="$ROOT/.build/SourcePackages/artifacts/sparkle/Sparkle/bin"
  if [[ -x "$base/sign_update" ]]; then
    echo "$base"
    return
  fi
  echo "Sparkle tools not found. Run an Xcode build once (e.g. xcodebuild ... build) or set SPARKLE_ROOT to Sparkle's bin/ (e.g. ~/Developer/Sparkle-2.9.1/bin)." >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  scripts/sparkle-release.sh build [minor|major]
      Wrapper for scripts/publish-dmg.sh — Release DMG at dist/StickNote-<version>.dmg

  scripts/sparkle-release.sh sign
      Run sign_update on dist/StickNote-<MARKETING_VERSION>.dmg (signature from keychain).

  scripts/sparkle-release.sh appcast <git-tag>
      Regenerate packaging/appcast.xml from dist/ using generate_appcast and a GitHub Release download URL prefix.
      Example tag: v1.3.0  →  .../releases/download/v1.3.0/StickNote-1.3.0.dmg

Environment:
  GITHUB_REPO   default: alex-fomin/StickNote  (owner/repo, no https)
  SPARKLE_ROOT  optional: path to Sparkle bin/ if not using .build/SourcePackages/artifacts/...

After appcast:
  Upload dist/StickNote-<version>.dmg to the GitHub Release for <git-tag>, then commit and push packaging/appcast.xml.
EOF
}

case "${1:-}" in
  build)
    shift
    exec "$ROOT/scripts/publish-dmg.sh" "$@"
    ;;
  sign)
    VERSION="$(read_marketing_version)"
    DMG="$ROOT/dist/StickNote-${VERSION}.dmg"
    if [[ ! -f "$DMG" ]]; then
      echo "Missing $DMG — run scripts/sparkle-release.sh build first." >&2
      exit 1
    fi
    BIN="$(sparkle_bin_dir)"
    echo "Using: $BIN/sign_update"
    exec "$BIN/sign_update" "$DMG"
    ;;
  appcast)
    TAG="${2:-}"
    if [[ -z "$TAG" ]]; then
      usage >&2
      exit 1
    fi
    VERSION="$(read_marketing_version)"
    DMG="$ROOT/dist/StickNote-${VERSION}.dmg"
    if [[ ! -f "$DMG" ]]; then
      echo "Missing $DMG — run scripts/sparkle-release.sh build first." >&2
      exit 1
    fi
    REPO="${GITHUB_REPO:-alex-fomin/StickNote}"
    PREFIX="https://github.com/${REPO}/releases/download/${TAG}/"
    BIN="$(sparkle_bin_dir)"
    APPCAST_SRC="$ROOT/packaging/appcast.xml"
    # generate_appcast merges with an existing appcast in the archives directory when present
    if [[ -f "$APPCAST_SRC" ]]; then
      cp "$APPCAST_SRC" "$ROOT/dist/appcast.xml"
    fi
    echo "Using generate_appcast from: $BIN"
    echo "Download URL prefix: $PREFIX"
    "$BIN/generate_appcast" \
      -o "$APPCAST_SRC" \
      --download-url-prefix "$PREFIX" \
      "$ROOT/dist"
    echo "Wrote $APPCAST_SRC"
    echo "Next: create/publish GitHub Release $TAG with asset StickNote-${VERSION}.dmg at the URL above, then git add/commit packaging/appcast.xml."
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
