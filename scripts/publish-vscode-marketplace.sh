#!/usr/bin/env bash
set -euo pipefail

# Publishes one or more platform-specific VSIXs. They go up in a single call
# because a marketplace version that exists for one platform and not another
# leaves the rest of the users on the previous release with no indication why.

if [ "$#" -eq 0 ]; then
  echo "usage: scripts/publish-vscode-marketplace.sh PATH.vsix [PATH.vsix ...]" >&2
  exit 2
fi

paths=()
for vsix in "$@"; do
  if [ ! -f "$vsix" ]; then
    echo "::error::no such VSIX: $vsix" >&2
    exit 1
  fi
  paths+=(--packagePath "$(realpath "$vsix")")
done

case "${VSCE_AUTH_MODE:-pat}" in
  pat)
    if [ -z "${VSCE_PAT:-}" ]; then
      echo "::error::VSCE_PAT is required when VSCE_AUTH_MODE=pat" >&2
      exit 1
    fi
    npx --yes @vscode/vsce@3.9.2 publish "${paths[@]}" -p "$VSCE_PAT"
    ;;
  azure)
    npx --yes @vscode/vsce@3.9.2 publish "${paths[@]}" --azure-credential
    ;;
  *)
    echo "::error::unsupported VSCE_AUTH_MODE: ${VSCE_AUTH_MODE:-}" >&2
    exit 1
    ;;
esac
