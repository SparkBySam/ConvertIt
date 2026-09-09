#!/bin/bash
# Builds a drag-to-Applications DMG for ConvertIt (requires create-dmg).
#
# One-time setup:
#   brew install create-dmg
#
# Usage:
#   ./create-release-dmg.sh                          # latest Xcode archive
#   ./create-release-dmg.sh /path/to/Convert\ It.app
#   ./create-release-dmg.sh /path/to/Convert\ It.app ~/Desktop ConvertIt-1.0.dmg
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify-app-bundle.sh"

APP_NAME="Convert It.app"
VOL_NAME="ConvertIt"

usage() {
  cat <<EOF
Usage: $(basename "$0") [app-path] [output-dir] [output-name.dmg]

Creates a DMG with the app on the left and an Applications folder link on the right.

Examples:
  $(basename "$0")
  $(basename "$0") "\$HOME/Library/.../Convert It.app"
  $(basename "$0") "\$HOME/Library/.../Convert It.app" ~/Desktop ConvertIt-1.0.dmg
EOF
}

require_create_dmg() {
  if command -v create-dmg >/dev/null 2>&1; then
    return
  fi
  cat <<'EOF'
error: create-dmg is not installed.

Install it once:
  brew install create-dmg

Then run this script again.
EOF
  exit 1
}

find_latest_archive_app() {
  find "${HOME}/Library/Developer/Xcode/Archives" \
    -name "${APP_NAME}" \
    -path "*/Products/Applications/*" 2>/dev/null \
    | sort \
    | tail -1
}

read_version() {
  local app="$1"
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "${app}/Contents/Info.plist" 2>/dev/null || echo "1.0"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_create_dmg

APP="${1:-$(find_latest_archive_app)}"
OUT_DIR="${2:-${HOME}/Desktop}"
OUT_NAME="${3:-}"

if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  echo "error: Could not find ${APP_NAME}."
  echo ""
  echo "Archive in Xcode first, or pass the .app path:"
  usage
  exit 1
fi

if [[ "$(basename "${APP}")" != "${APP_NAME}" ]]; then
  echo "error: Expected bundle named \"${APP_NAME}\", got \"$(basename "${APP}")\""
  exit 1
fi

VERSION="$(read_version "${APP}")"
if [[ -z "${OUT_NAME}" ]]; then
  OUT_NAME="ConvertIt-${VERSION}.dmg"
fi

mkdir -p "${OUT_DIR}"
DMG_PATH="${OUT_DIR}/${OUT_NAME}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/convertit-dmg.XXXXXX")"

cleanup() {
  rm -rf "${STAGE}"
}
trap cleanup EXIT

echo "Verifying app bundle ..."
bash "${VERIFY_SCRIPT}" "${APP}"

echo "Staging ${APP_NAME} ..."
cp -R "${APP}" "${STAGE}/${APP_NAME}"

# Remove old DMG if present (create-dmg fails on existing file without --skip-jenkins).
rm -f "${DMG_PATH}"

echo "Creating DMG: ${DMG_PATH}"
create-dmg \
  --volname "${VOL_NAME}" \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}" 150 200 \
  --hide-extension "${APP_NAME}" \
  --app-drop-link 450 200 \
  "${DMG_PATH}" \
  "${STAGE}/${APP_NAME}"

echo ""
echo "Done: ${DMG_PATH}"
echo ""
echo "Share this DMG with testers. First launch: right-click Convert It → Open (Gatekeeper without notarization)."
