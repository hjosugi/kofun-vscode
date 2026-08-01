#!/bin/sh
set -eu

# Copy the language server out of the pinned hjosugi/kofun checkout and build
# its semantic bundle, so `vsce package` has a `server/` to ship.
#
# The server is not vendored in git on purpose. `tests/lsp/check.sh` in
# hjosugi/kofun requires the bundle to equal that repository's
# `tooling/typed-sidecar/{from-stage2,codec}.mjs` byte for byte, and only a
# checkout that owns those files can prove it. Copying the built result here
# and calling it verified would be a claim this repository cannot make.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
KOFUN=${KOFUN_CHECKOUT:-"$ROOT/vendor/kofun"}
# hjosugi/kofun#861 moved the server from editor/vscode/server to tooling/lsp.
# Accept both so this repository works against a checkout from either side of
# that change, and say which one was used.
#
# Probe on build-semantic-bundle.sh, not server.js: before the move, tooling/lsp
# held a four-line server.js that only required the real one, so probing on that
# name picks the shim and then fails to find everything beside it.
SERVER=
for kofun_candidate in "$KOFUN/tooling/lsp" "$KOFUN/editor/vscode/server"; do
    if test -f "$kofun_candidate/build-semantic-bundle.sh"; then
        SERVER=$kofun_candidate
        break
    fi
done
OUT="$ROOT/server"

if ! test -d "$KOFUN/.git" && ! test -f "$KOFUN/.git"; then
    printf '%s\n' \
        "vendor-server: $KOFUN is not a checkout of hjosugi/kofun." \
        "  git submodule update --init vendor/kofun" \
        "or point KOFUN_CHECKOUT at one." >&2
    exit 2
fi

if test -z "$SERVER"; then
    printf '%s\n' \
        "vendor-server: no language server in $KOFUN." \
        "  Looked for build-semantic-bundle.sh in tooling/lsp/ and" \
        "  editor/vscode/server/ and found neither." >&2
    exit 2
fi

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$SERVER/server.js" "$SERVER/semantic-sidecar.mjs" "$SERVER/semantic-worker.mjs" \
    "$SERVER/kofun-lsp" "$OUT/"
mkdir -p "$OUT/native"
cp "$SERVER/native/semantic_bridge.c" "$OUT/native/"

# Run the submodule's own bundle script: it resolves the typed-sidecar sources
# relative to itself, and only needs to be told where to put the result.
KOFUN_LSP_BUNDLE_DIR="$OUT/generated" sh "$SERVER/build-semantic-bundle.sh"

printf '%s\n' \
    "vendor-server: server/ vendored from ${SERVER#"$KOFUN/"} at $(git -C "$KOFUN" rev-parse --short HEAD)"
