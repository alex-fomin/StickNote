#!/usr/bin/env bash
# Build a Release StickNote.app suitable for copying to /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/build/DerivedData"
PRODUCT="$DERIVED/Build/Products/Release/StickNote.app"
OUT="$ROOT/build/StickNote.app"

cd "$ROOT"

if [[ "${1:-}" == "--clean" ]]; then
  rm -rf "$DERIVED"
fi

echo "Building Release (generic macOS)…"
xcodebuild \
  -scheme StickNote \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  build

if [[ ! -d "$PRODUCT" ]]; then
  echo "error: expected app not found at $PRODUCT" >&2
  exit 1
fi

rm -rf "$OUT"
ditto "$PRODUCT" "$OUT"

echo "Done: $OUT"
du -sh "$OUT"
