#!/usr/bin/env bash
set -euo pipefail

# Fail before packaging rather than after, and never print a secret's value.
# Modelled on hjosugi/sql-dialect-fmt's script of the same name.

usage() {
  cat >&2 <<'EOF'
usage: scripts/check-publishing-credentials.sh vscode

Checks that the environment holds the credentials the target needs.
Secret values are never printed.
EOF
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "::error::$name is required for $target publishing" >&2
    missing=true
  fi
}

target="${1:-}"
missing=false

case "$target" in
  vscode)
    case "${VSCE_AUTH_MODE:-pat}" in
      pat)
        require_env VSCE_PAT
        ;;
      azure)
        require_env AZURE_CLIENT_ID
        require_env AZURE_TENANT_ID
        ;;
      *)
        echo "::error::unsupported VSCE_AUTH_MODE: ${VSCE_AUTH_MODE}" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [ "$missing" = true ]; then
  exit 1
fi

echo "$target publishing credentials are present"
