#!/usr/bin/env bash
# install.sh — build wthrr (Release), sign it, and install it into /Applications
#
# Usage:
#   ./scripts/install.sh               # test + build + sign + install + relaunch
#   ./scripts/install.sh --skip-tests  # skip the unit tests
#   ./scripts/install.sh --no-launch   # install but don't relaunch
#   ./scripts/install.sh --dest DIR    # install somewhere other than /Applications
#
# The running copy of wthrr is quit before the old bundle is replaced, then the
# new build is launched. Signing matches build-dmg.sh: Developer ID when a cert is
# available, otherwise ad-hoc. Ad-hoc signatures change on every build, so macOS
# may ask again for Location access after an install.
#
# Exit codes: 0 success · 1 bad flag / no Xcode · 2 tests failed · 3 build failed
#             4 install failed

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="wthrr"
APP_NAME="wthrr"
DERIVED="$PROJECT_ROOT/build/InstallDerivedData"
LOG_DIR="$PROJECT_ROOT/build/logs"
DEST="/Applications"
RUN_TESTS=true
LAUNCH=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-tests) RUN_TESTS=false ;;
        --no-launch)  LAUNCH=false ;;
        --dest)       DEST="${2:?--dest needs a directory}"; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
    shift
done

header()  { echo; echo "▸ $*"; }
success() { echo "  ✓ $*"; }
info()    { echo "  · $*"; }
fail()    { echo "  ✗ $*"; }

# ── Preflight: find a full Xcode ─────────────────────────────────────────────
# xcodebuild refuses to run when xcode-select points at the Command Line Tools,
# so fall back to the first Xcode in /Applications (release or beta).
header "Preflight"
if ! xcodebuild -version &>/dev/null; then
    XCODE_APP=$(ls -d /Applications/Xcode*.app 2>/dev/null | head -1 || true)
    if [[ -z "$XCODE_APP" ]]; then
        fail "No Xcode found. Install Xcode or run: sudo xcode-select -s /Applications/Xcode.app"
        exit 1
    fi
    export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
fi
success "$(xcodebuild -version | head -1)"
mkdir -p "$LOG_DIR"

# ── Tests ─────────────────────────────────────────────────────────────────────
if $RUN_TESTS; then
    header "Running unit tests"
    if xcodebuild test \
        -project "$PROJECT_ROOT/wthrr.xcodeproj" \
        -scheme "$SCHEME" \
        -derivedDataPath "$DERIVED" \
        -only-testing:wthrrTests \
        CODE_SIGNING_ALLOWED=NO \
        > "$LOG_DIR/test.log" 2>&1; then
        success "$(grep -E 'Test run with' "$LOG_DIR/test.log" | tail -1 | sed 's/^[^A-Za-z]*//')"
    else
        fail "Tests failed — see $LOG_DIR/test.log"
        grep -E "error:|✘|failed" "$LOG_DIR/test.log" | head -20 || true
        exit 2
    fi
fi

# ── Build ─────────────────────────────────────────────────────────────────────
header "Building $SCHEME (Release)"
if xcodebuild build \
    -project "$PROJECT_ROOT/wthrr.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    > "$LOG_DIR/build.log" 2>&1; then
    WARNINGS=$(grep -c "warning:" "$LOG_DIR/build.log" || true)
    success "Build succeeded ($WARNINGS warning lines)"
else
    fail "Build failed — see $LOG_DIR/build.log"
    grep -E "error:" "$LOG_DIR/build.log" | sort -u | head -30 || true
    exit 3
fi

APP_PATH="$DERIVED/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || { fail "Built app not found at $APP_PATH"; exit 3; }

VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")
BUILD_NUM=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "?")
info "wthrr $VERSION (build $BUILD_NUM)"

# ── Sign ──────────────────────────────────────────────────────────────────────
# Stage outside the repo so iCloud/File Provider can't re-add extended attributes
# between the xattr strip and codesign (same reasoning as build-dmg.sh).
header "Signing"
STAGE_DIR=$(mktemp -d -t wthrr-install)
trap 'rm -rf "$STAGE_DIR"' EXIT
ditto "$APP_PATH" "$STAGE_DIR/$APP_NAME.app"
STAGED="$STAGE_DIR/$APP_NAME.app"
xattr -cr "$STAGED"

DEV_ID_LINE=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" | head -1 || true)
if [[ -n "$DEV_ID_LINE" ]]; then
    DEV_ID=$(echo "$DEV_ID_LINE" | sed 's/.*"\(.*\)".*/\1/')
    codesign --force --deep --sign "$DEV_ID" --options runtime \
        --entitlements "$PROJECT_ROOT/wthrr/wthrr.entitlements" --timestamp "$STAGED" \
        > "$LOG_DIR/sign.log" 2>&1
    success "Signed with Developer ID"
else
    codesign --force --deep --sign "-" "$STAGED" > "$LOG_DIR/sign.log" 2>&1
    success "Ad-hoc signed"
fi
codesign --verify --deep --strict "$STAGED" && success "Signature verified"

# ── Install ───────────────────────────────────────────────────────────────────
header "Installing to $DEST"
if pgrep -x "$APP_NAME" >/dev/null; then
    info "Quitting running $APP_NAME"
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    for _ in {1..20}; do pgrep -x "$APP_NAME" >/dev/null || break; sleep 0.25; done
    pkill -x "$APP_NAME" 2>/dev/null || true
fi

TARGET="$DEST/$APP_NAME.app"
if ! { rm -rf "$TARGET" && ditto "$STAGED" "$TARGET"; }; then
    fail "Could not write $TARGET (permissions?)"
    exit 4
fi
success "Installed $TARGET"

# ── Launch ────────────────────────────────────────────────────────────────────
if $LAUNCH; then
    open "$TARGET"
    success "Launched"
fi

echo
echo "Done — wthrr $VERSION (build $BUILD_NUM) installed at $TARGET"
