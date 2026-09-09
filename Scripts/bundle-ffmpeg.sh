#!/bin/bash
# Copies the LGPL FFmpeg binary into the app bundle Resources folder.
# Required because ffmpeg is gitignored and Xcode's synchronized folder skips it.
set -euo pipefail

SRCROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
FFMPEG_SRC="${SRCROOT}/BundledBinaries/ffmpeg"
RESOURCES_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
FRAMEWORKS_DEST="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Frameworks"
DYLIB_SCRIPT="${SRCROOT}/Scripts/bundle-ffmpeg-dylibs.sh"

if [[ ! -x "${FFMPEG_SRC}" ]]; then
  echo "error: FFmpeg binary missing at ${FFMPEG_SRC}"
  echo "Run: ${SRCROOT}/Scripts/build-ffmpeg-lgpl.sh"
  exit 1
fi

mkdir -p "${RESOURCES_DEST}"
cp -f "${FFMPEG_SRC}" "${RESOURCES_DEST}/ffmpeg"
chmod +x "${RESOURCES_DEST}/ffmpeg"
xattr -cr "${RESOURCES_DEST}/ffmpeg" 2>/dev/null || true

for resource in ffmpeg-build-info.txt FFmpeg-NOTICE.txt; do
  src="${SRCROOT}/Convert It/Resources/${resource}"
  if [[ -f "${src}" ]]; then
    cp -f "${src}" "${RESOURCES_DEST}/"
  fi
done

# Rewrite /opt/homebrew dylib paths to bundled Frameworks (sandbox-safe).
source "${DYLIB_SCRIPT}"
bundle_ffmpeg_dylibs "${RESOURCES_DEST}/ffmpeg" "${FRAMEWORKS_DEST}" "@executable_path/../Frameworks"

sign_if_needed() {
  local target="$1"
  if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]]; then
    codesign --force --options runtime --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp "${target}" 2>/dev/null || \
      codesign --force --options runtime --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "${target}"
  else
    ad_hoc_sign "${target}"
  fi
}

sign_if_needed "${RESOURCES_DEST}/ffmpeg"
for lib in "${FRAMEWORKS_DEST}"/*.dylib; do
  [[ -e "${lib}" ]] || continue
  sign_if_needed "${lib}"
done

if otool -L "${RESOURCES_DEST}/ffmpeg" | grep -qE '/opt/homebrew|/usr/local'; then
  echo "error: FFmpeg still references external Homebrew paths after bundling dylibs."
  otool -L "${RESOURCES_DEST}/ffmpeg" | grep -E '/opt/homebrew|/usr/local' || true
  exit 1
fi

if ! "${RESOURCES_DEST}/ffmpeg" -version >/dev/null 2>&1; then
  echo "error: Bundled FFmpeg failed smoke test after dylib rewrite/signing."
  "${RESOURCES_DEST}/ffmpeg" -version 2>&1 | head -5 || true
  exit 1
fi

echo "Bundled FFmpeg into ${RESOURCES_DEST}/ffmpeg"
if compgen -G "${FRAMEWORKS_DEST}/*.dylib" >/dev/null; then
  echo "Bundled $(ls "${FRAMEWORKS_DEST}"/*.dylib | wc -l | tr -d ' ') dylibs into ${FRAMEWORKS_DEST}"
fi
