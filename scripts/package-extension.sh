#!/usr/bin/env bash
set -euo pipefail

# Build the VSIX. The version is passed in so a tag, a workflow input and the
# manifest cannot disagree silently.

VERSION="${1:-}"
TARGET="${2:-}"
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

if [ -z "$VERSION" ]; then
  VERSION="$(node -p "require('./package.json').version")"
fi

MANIFEST_VERSION="$(node -p "require('./package.json').version")"
if [ "$VERSION" != "$MANIFEST_VERSION" ]; then
  echo "::error::package.json says $MANIFEST_VERSION, the build was asked for $VERSION" >&2
  exit 1
fi

sh scripts/vendor-server.sh

mkdir -p dist

# server/generated/semantic-bridge.node is compiled for the machine that built
# it. A VSIX with no target declared installs everywhere, and on any other
# platform the server loads nothing and answers every request with null — no
# error, no fallback label, just an extension that appears to do nothing. So
# each build is stamped with the platform it was built on, and VS Code only
# offers it to that platform.
if [ -n "$TARGET" ]; then
  OUT="dist/kofun-language-bootstrap-${TARGET}-v${VERSION}.vsix"
  npx --yes @vscode/vsce@3.9.2 package \
    --no-dependencies --target "$TARGET" --out "$OUT"
else
  OUT="dist/kofun-language-bootstrap-v${VERSION}.vsix"
  npx --yes @vscode/vsce@3.9.2 package --no-dependencies --out "$OUT"
fi

echo "packaged $OUT"
