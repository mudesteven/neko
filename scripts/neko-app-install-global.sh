#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SRC_DOCKER="$SCRIPT_DIR/neko-app"
SRC_HOST="$SCRIPT_DIR/neko-app-host"
DST_DOCKER="/usr/local/bin/neko-app"
DST_HOST="/usr/local/bin/neko-app-host"

for src in "$SRC_DOCKER" "$SRC_HOST"; do
  if [[ ! -f "$src" ]]; then
    echo "ERROR: source script not found: $src" >&2
    exit 1
  fi
done

echo "Installing global commands:"
echo "  $DST_DOCKER"
echo "  $DST_HOST"
install -m 0755 "$SRC_DOCKER" "$DST_DOCKER"
install -m 0755 "$SRC_HOST" "$DST_HOST"

echo "Done. Verify with:"
echo "  neko-app --help"
echo "  neko-app-host --help"
