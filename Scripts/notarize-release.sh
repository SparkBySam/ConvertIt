#!/bin/bash
# Export, verify, notarize, and staple a Convert It release build.
#
# Prerequisites:
#   1. Developer ID Application certificate in Keychain (not just Apple Development)
#   2. Notary credentials — either:
#        export NOTARY_KEYCHAIN_PROFILE="ConvertIt-Notary"
#      (stored via: xcrun notarytool store-credentials ...)
#      or:
#        export NOTARY_APPLE_ID="you@example.com"
#        export NOTARY_TEAM_ID="ULS58DAH92"
#        export NOTARY_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # app-specific password
#
# Usage:
#   ./notarize-release.sh export  ~/Library/.../Convert\ It.xcarchive
#   ./notarize-release.sh verify  ~/Desktop/ConvertIt-export/Convert\ It.app
#   ./notarize-release.sh notarize ~/Desktop/ConvertIt-export/Convert\ It.app
#   ./notarize-release.sh release ~/Library/.../Convert\ It.xcarchive
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_OPTIONS="${SCRIPT_DIR}/ExportOptions.plist"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify-app-bundle.sh"
TEAM_ID="${NOTARY_TEAM_ID:-ULS58DAH92}"

usage() {
  sed -n '1,20p' "$0" | tail -n +2
}

require_notary_auth() {
  if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    NOTARY_ARGS=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE}")
    return
  fi
  if [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]]; then
    NOTARY_ARGS=(--apple-id "${NOTARY_APPLE_ID}" --team-id "${TEAM_ID}" --password "${NOTARY_PASSWORD}")
    return
  fi
  cat <<'EOF'
error: Notary credentials missing.

Option A — keychain profile (recommended):
  xcrun notarytool store-credentials "ConvertIt-Notary" \
    --apple-id "you@example.com" \
    --team-id "ULS58DAH92" \
    --password "xxxx-xxxx-xxxx-xxxx"
  export NOTARY_KEYCHAIN_PROFILE="ConvertIt-Notary"

Option B — environment variables:
  export NOTARY_APPLE_ID="you@example.com"
  export NOTARY_TEAM_ID="ULS58DAH92"
  export NOTARY_PASSWORD="xxxx-xxxx-xxxx-xxxx"
EOF
  exit 1
}

cmd_export() {
  local archive="$1"
  local export_dir="${2:-${HOME}/Desktop/ConvertIt-export}"

  if [[ ! -d "${archive}" ]]; then
    echo "error: Archive not found: ${archive}"
    exit 1
  fi

  if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    cat <<'EOF'
error: No "Developer ID Application" certificate found.

Create one in Xcode:
  Settings → Accounts → [Your Team] → Manage Certificates → + → Developer ID Application

Or at developer.apple.com → Certificates → + → Developer ID Application.
EOF
    exit 1
  fi

  rm -rf "${export_dir}"
  mkdir -p "${export_dir}"

  echo "Exporting Developer ID build to ${export_dir} ..."
  xcodebuild -exportArchive \
    -archivePath "${archive}" \
    -exportPath "${export_dir}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}"

  local app="${export_dir}/Convert It.app"
  bash "${VERIFY_SCRIPT}" "${app}"
  echo ""
  echo "Export complete: ${app}"
}

cmd_verify() {
  bash "${VERIFY_SCRIPT}" "$1"
}

cmd_notarize() {
  local app="$1"
  local zip_path="${2:-${TMPDIR:-/tmp}/ConvertIt-notarize.zip}"

  bash "${VERIFY_SCRIPT}" "${app}"
  require_notary_auth

  echo "Creating notarization zip ..."
  ditto -c -k --keepParent "${app}" "${zip_path}"

  echo "Submitting to Apple notary service (this can take several minutes) ..."
  xcrun notarytool submit "${zip_path}" "${NOTARY_ARGS[@]}" --wait

  echo "Stapling ticket to app ..."
  xcrun stapler staple "${app}"
  xcrun stapler validate "${app}"

  echo ""
  echo "Notarization complete: ${app}"
  echo "Optional: create a DMG with create-dmg or hdiutil, then notarize the DMG separately."
}

cmd_release() {
  local archive="$1"
  local export_dir="${2:-${HOME}/Desktop/ConvertIt-export}"
  cmd_export "${archive}" "${export_dir}"
  cmd_notarize "${export_dir}/Convert It.app"
}

case "${1:-}" in
  export)   cmd_export "$2" "${3:-}" ;;
  verify)   cmd_verify "$2" ;;
  notarize) cmd_notarize "$2" "${3:-}" ;;
  release)  cmd_release "$2" "${3:-}" ;;
  -h|--help|"") usage ;;
  *)
    echo "error: Unknown command: ${1}"
    usage
    exit 1
    ;;
esac
