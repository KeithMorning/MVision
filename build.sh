#!/bin/bash
# MVision Build Script
# Usage: ./build.sh [macos|windows|all] [release|debug|profile]

set -e

# --- Environment ---
export PATH="$HOME/development/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# --- Config ---
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLIENT_DIR="$PROJECT_DIR/apps/client"
PLATFORM="${1:-macos}"
MODE="${2:-release}"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Pre-checks ---
command -v flutter >/dev/null 2>&1 || error "Flutter not found. Install at ~/development/flutter"

info "Flutter: $(flutter --version | head -1)"
info "Platform: $PLATFORM | Mode: $MODE"
info "Project: $CLIENT_DIR"
echo ""

# --- Pub Get ---
info "Resolving dependencies..."
cd "$CLIENT_DIR"
flutter pub get --no-example > /dev/null 2>&1 || error "pub get failed"

# --- Build ---
build_macos() {
  info "Building macOS ($MODE)..."
  flutter build macos --$MODE 2>&1 | tail -3
  local mode_cap=$(echo "$MODE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
  local app="$CLIENT_DIR/build/macos/Build/Products/${mode_cap}/mvision_client.app"
  if [ -d "$app" ]; then
    local size=$(du -sh "$app" | cut -f1)
    info "✓ macOS build complete: $app ($size)"
  else
    error "macOS build output not found"
  fi
}

build_windows() {
  info "Building Windows ($MODE)..."
  flutter build windows --$MODE 2>&1 | tail -3
  info "✓ Windows build complete"
}

case "$PLATFORM" in
  macos)
    build_macos
    ;;
  windows)
    build_windows
    ;;
  all)
    build_macos
    echo ""
    build_windows
    ;;
  *)
    error "Unknown platform: $PLATFORM (use: macos, windows, all)"
    ;;
esac

echo ""
info "Done!"
