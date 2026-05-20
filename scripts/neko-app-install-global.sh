#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/neko-app"
DST="/usr/local/bin/neko-app"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source script not found: $SRC" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -sSL https://get.docker.com/ | CHANNEL=stable bash
fi

echo "Installing global command: $DST"
install -m 0755 "$SRC" "$DST"

echo "Done. Verify with: neko-app --help"
