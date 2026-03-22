#!/usr/bin/env bash
# scripts/release.sh — tag, attach DMG, and publish a GitHub Release
#
# Usage:
#   ./scripts/release.sh 1.0b
#   ./scripts/release.sh 1.1 --draft     # publish as draft
#
# Prerequisites:
#   - gh CLI installed and authenticated  (brew install gh && gh auth login)
#   - DMG already built at build/wthrr-<version>.dmg
#   - Release notes at release-notes/<version>.md

set -euo pipefail

VERSION="${1:-}"
DRAFT_FLAG=""

# Parse optional flags
for arg in "${@:2}"; do
  case "$arg" in
    --draft) DRAFT_FLAG="--draft" ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [--draft]"
  echo "  e.g. $0 1.0b"
  echo "  e.g. $0 1.1 --draft"
  exit 1
fi

TAG="v${VERSION}"
DMG="build/wthrr-${VERSION}.dmg"
NOTES="release-notes/${VERSION}.md"

# --- Validate prerequisites ---
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install with: brew install gh"
  exit 1
fi

if [[ ! -f "$DMG" ]]; then
  echo "Error: DMG not found at $DMG"
  echo "Build the app first, then re-run."
  exit 1
fi

if [[ ! -f "$NOTES" ]]; then
  echo "Error: Release notes not found at $NOTES"
  echo "Create $NOTES before releasing."
  exit 1
fi

# --- Check for uncommitted changes ---
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Warning: You have uncommitted changes."
  read -r -p "Continue anyway? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

# --- Create and push tag ---
if git rev-parse "$TAG" &>/dev/null; then
  echo "Tag $TAG already exists locally — reusing."
else
  git tag -a "$TAG" -m "Release $TAG"
  echo "Created tag $TAG"
fi

echo "Pushing tag $TAG to origin..."
git push origin "$TAG"

# --- Create GitHub Release and upload DMG ---
echo "Creating GitHub Release $TAG..."
# shellcheck disable=SC2086
gh release create "$TAG" \
  $DRAFT_FLAG \
  --title "wthrr $TAG" \
  --notes-file "$NOTES" \
  "${DMG}#wthrr-${VERSION}.dmg"

echo ""
echo "Done! Release $TAG published."
echo "  $(gh release view "$TAG" --json url -q .url)"
