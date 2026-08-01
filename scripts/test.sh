#!/bin/sh
set -eu

# The extension's own tests. The language server's tests live in
# hjosugi/kofun, because that is where the server and the typed-sidecar
# sources it must match byte for byte both live.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# The smoke test launches the packaged server, so vendor it first unless a
# previous run already did.
test -f "$ROOT/server/server.js" || sh "$ROOT/scripts/vendor-server.sh"

node --check "$ROOT/extension.js"
node --check "$ROOT/tests/extension_manifest_test.mjs"
node --check "$ROOT/tests/vscode_smoke_test.js"

node "$ROOT/tests/extension_manifest_test.mjs" "$ROOT"
NODE_PATH="$ROOT/tests/vscode-mock" \
    node "$ROOT/tests/vscode_smoke_test.js" "$ROOT"
