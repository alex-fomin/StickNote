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
    # generate_appcast applies one URL prefix to every archive and keeps only the newest few versions,
    # so generate into a temp feed and merge just this version's item into the committed appcast.
    TMP_APPCAST="$(mktemp -d)/appcast.xml"
    rm -f "$ROOT/dist/appcast.xml"
    echo "Using generate_appcast from: $BIN"
    echo "Download URL prefix: $PREFIX"
    "$BIN/generate_appcast" \
      -o "$TMP_APPCAST" \
      --download-url-prefix "$PREFIX" \
      "$ROOT/dist"
    python3 - "$TMP_APPCAST" "$APPCAST_SRC" "$VERSION" <<'PY'
import re, sys
generated_path, appcast_path, version = sys.argv[1:]
item_re = r'[ \t]*<item>\s*<title>{}</title>.*?</item>\n?'
generated = open(generated_path).read()
match = re.search(item_re.format(re.escape(version)), generated, re.S)
if not match:
    sys.exit(f"generate_appcast produced no item for {version}")
appcast = open(appcast_path).read()
appcast = re.sub(item_re.format(re.escape(version)), "", appcast, flags=re.S)
anchor = "<language>en</language>\n"
if anchor not in appcast:
    sys.exit(f"{appcast_path}: missing {anchor.strip()}")
open(appcast_path, "w").write(appcast.replace(anchor, anchor + match.group(0), 1))
PY
    echo "Wrote $APPCAST_SRC"
    echo "Next: create/publish GitHub Release $TAG with assets StickNote-${VERSION}.dmg and dist/StickNote${VERSION}-*.delta at the URL above, then git add/commit packaging/appcast.xml."
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
