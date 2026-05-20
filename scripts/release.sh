#!/bin/sh
# Cut a GitHub release with the prebuilt Flow.app.zip attached.
# Usage:  bash scripts/release.sh v0.1.0  ["Release notes here"]
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/release.sh <version-tag> [notes]"
  echo "Example: bash scripts/release.sh v0.1.0"
  exit 1
fi

TAG="$1"
NOTES="${2:-Flow $TAG — menu bar productivity tracker for macOS.}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
ZIP="$BUILD/Flow.app.zip"

# Build & package
echo "==> Building $TAG"
bash "$ROOT/scripts/build.sh"

if [ ! -f "$ZIP" ]; then
  echo "ERROR: expected $ZIP after build"
  exit 1
fi

# Tag if not already present locally
if ! git -C "$ROOT" rev-parse "$TAG" >/dev/null 2>&1; then
  echo "==> Tagging $TAG"
  git -C "$ROOT" tag -a "$TAG" -m "Flow $TAG"
  git -C "$ROOT" push origin "$TAG"
fi

# Default install instructions appended to the body
BODY=$(cat <<EOF
$NOTES

## Install

1. Download **Flow.app.zip** below.
2. Unzip and drag **Flow.app** to your Applications folder.
3. **Right-click → Open** the first time (one-time Gatekeeper bypass for unsigned builds).
4. Look for the little brush-stroke circle in your menu bar. Click it to start tracking a task.

Flow auto-launches at login after the first run.
EOF
)

# Create the release (or update if it already exists)
if gh release view "$TAG" -R peterquads/flow >/dev/null 2>&1; then
  echo "==> Release $TAG already exists — updating asset"
  gh release upload "$TAG" "$ZIP" -R peterquads/flow --clobber
else
  echo "==> Creating release $TAG"
  gh release create "$TAG" "$ZIP" \
    -R peterquads/flow \
    --title "Flow $TAG" \
    --notes "$BODY"
fi

URL=$(gh release view "$TAG" -R peterquads/flow --json url -q .url)
echo ""
echo "✔ Released: $URL"
