#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/neko-app-install-all.sh [options]

Installs host dependencies, builds Neko (client+server), and installs:
  - neko-app        (Docker launcher)
  - neko-app-host   (Host-native launcher)

Options:
  --with-docker   Also install Docker engine + compose plugin if missing
  --local-only    Install commands only to ~/.local/bin (skip /usr/local/bin)
  --skip-build    Skip client/server build steps
  -h, --help      Show this help
EOF
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

WITH_DOCKER=0
LOCAL_ONLY=0
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-docker) WITH_DOCKER=1; shift ;;
    --local-only) LOCAL_ONLY=1; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$SCRIPT_DIR/neko-app" || ! -f "$SCRIPT_DIR/neko-app-host" ]]; then
  echo "ERROR: expected scripts/neko-app and scripts/neko-app-host in repo" >&2
  exit 1
fi

if ! have_cmd apt-get; then
  echo "ERROR: this installer currently supports apt-based systems only." >&2
  exit 1
fi

SUDO=""
if [[ $EUID -ne 0 ]]; then
  if have_cmd sudo; then
    SUDO="sudo"
  else
    echo "ERROR: need root or sudo for apt package install." >&2
    exit 1
  fi
fi

echo "==> Repairing any partial/broken apt state"
$SUDO dpkg --configure -a || true
$SUDO apt-get -y --fix-broken install || true

echo "==> Installing OS packages"
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  ca-certificates curl git jq unzip build-essential pkg-config \
  golang-go nodejs \
  xvfb openbox pulseaudio dbus-x11 xdotool xclip \
  libx11-dev libxrandr-dev libxtst-dev libgtk-3-dev libxcvt-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-pulseaudio

# Browser install (best effort)
if ! have_cmd firefox && ! have_cmd firefox-esr; then
  if apt-cache show firefox >/dev/null 2>&1; then
    $SUDO apt-get install -y firefox || true
  elif apt-cache show firefox-esr >/dev/null 2>&1; then
    $SUDO apt-get install -y firefox-esr || true
  fi
fi

if ! have_cmd chromium && ! have_cmd chromium-browser; then
  if apt-cache show chromium >/dev/null 2>&1; then
    $SUDO apt-get install -y chromium || true
  elif apt-cache show chromium-browser >/dev/null 2>&1; then
    $SUDO apt-get install -y chromium-browser || true
  fi
fi

if (( WITH_DOCKER == 1 )); then
  if ! have_cmd docker; then
    echo "==> Installing Docker"
    curl -fsSL https://get.docker.com/ | $SUDO sh
  fi
  $SUDO apt-get install -y docker-compose-plugin || true
fi

if (( SKIP_BUILD == 0 )); then
  if ! have_cmd npm; then
    cat >&2 <<'EOF'
ERROR: npm is not available after installing nodejs.
This usually means your current nodejs package conflicts with distro npm metadata.
Fix options:
  1) Install nodejs that bundles npm (e.g., NodeSource nodejs package), then rerun this script.
  2) Rerun with --skip-build if client/server are already built.
EOF
    exit 1
  fi

  echo "==> Building client"
  (
    cd "$REPO_ROOT/client"
    npm install
    npm run build
  )

  echo "==> Building server"
  (
    cd "$REPO_ROOT/server"
    ./build core
  )
fi

echo "==> Installing commands to ~/.local/bin"
mkdir -p "$HOME/.local/bin"
install -m 0755 "$SCRIPT_DIR/neko-app" "$HOME/.local/bin/neko-app"
install -m 0755 "$SCRIPT_DIR/neko-app-host" "$HOME/.local/bin/neko-app-host"

if (( LOCAL_ONLY == 0 )); then
  if [[ $EUID -eq 0 ]] || have_cmd sudo; then
    echo "==> Installing commands to /usr/local/bin"
    $SUDO install -m 0755 "$SCRIPT_DIR/neko-app" /usr/local/bin/neko-app
    $SUDO install -m 0755 "$SCRIPT_DIR/neko-app-host" /usr/local/bin/neko-app-host
  else
    echo "WARN: sudo not available, skipped /usr/local/bin install"
  fi
fi

echo
echo "Done. Verify:"
echo "  neko-app --help"
echo "  neko-app-host --help"
echo
echo "Host run example:"
echo "  neko-app-host firefox"
