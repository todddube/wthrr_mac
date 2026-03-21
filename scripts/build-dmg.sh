#!/usr/bin/env bash
# build-dmg.sh — build wthrr and package it as a styled DMG
#
# Usage:
#   ./scripts/build-dmg.sh
#
# Requirements (install via Homebrew):
#   brew install create-dmg
#
# Distributes via direct download (no App Store, no notarization).
# Users right-click → Open on first launch to pass Gatekeeper.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="wthrr"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="wthrr"
BG_SCRIPT="$PROJECT_ROOT/scripts/create_dmg_bg.py"
BG_IMAGE="$PROJECT_ROOT/scripts/dmg-background.png"

# Read version from Xcode build settings
VERSION=$(xcodebuild -project "$PROJECT_ROOT/wthrr.xcodeproj" \
    -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk '/MARKETING_VERSION/{print $3; exit}')
VERSION="${VERSION:-1.0}"

DMG_OUT="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"

# ── Helpers ───────────────────────────────────────────────────────────────────
header()  { echo; echo "▸ $*"; }
success() { echo "  ✓ $*"; }

# ── Preflight ─────────────────────────────────────────────────────────────────
header "Preflight"
if ! command -v create-dmg &>/dev/null; then
    echo; echo "  create-dmg not found. Install it:"; echo "    brew install create-dmg"; echo; exit 1
fi
success "create-dmg found"

# ── Step 1 — DMG background ───────────────────────────────────────────────────
header "Generating DMG background"
python3 "$BG_SCRIPT"
success "dmg-background.png ready"

# ── Step 2 — Clean ────────────────────────────────────────────────────────────
header "Cleaning build/"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
success "Clean"

# ── Step 3 — Build ────────────────────────────────────────────────────────────
header "Building $SCHEME (Release)..."
xcodebuild build \
    -project       "$PROJECT_ROOT/wthrr.xcodeproj" \
    -scheme        "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "^(Build|error:|warning:|CompileSwift|Ld )" || true
echo
success "Build complete"

# Locate the built .app
APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -maxdepth 6 | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Could not find $APP_NAME.app in DerivedData"; exit 1
fi
success "App → $APP_PATH"

# Stage the .app for DMG
STAGE_DIR="$BUILD_DIR/stage"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"

# ── Step 4 — Build DMG ────────────────────────────────────────────────────────
header "Packaging DMG: ${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_OUT"

#  Window 700×420, icon size 128
#  App icon:         x=185  y=210  (left, centered)
#  Applications link: x=515  y=210  (right, centered)

create-dmg \
    --volname           "$APP_NAME" \
    --volicon           "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --background        "$BG_IMAGE" \
    --window-pos        200 100 \
    --window-size       700 420 \
    --icon-size         128 \
    --icon              "$APP_NAME.app" 185 210 \
    --hide-extension    "$APP_NAME.app" \
    --app-drop-link     515 210 \
    --no-internet-enable \
    "$DMG_OUT" \
    "$STAGE_DIR/"

success "DMG → $DMG_OUT"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " wthrr $VERSION  •  $(du -sh "$DMG_OUT" | cut -f1)"
echo " $DMG_OUT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Upload this file to your website."
echo " First-launch: right-click → Open to pass Gatekeeper."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
