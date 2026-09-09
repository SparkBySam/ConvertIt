#!/bin/bash
# Ensures an LGPL-compliant FFmpeg binary exists before Xcode bundles the app.
# Does NOT download GPL builds (e.g. evermeet.cx). Build once with build-ffmpeg-lgpl.sh.
set -euo pipefail

SRCROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
RESOURCES_DIR="${SRCROOT}/Convert It/Resources"
FFMPEG="${SRCROOT}/BundledBinaries/ffmpeg"
BUILD_SCRIPT="${SRCROOT}/Scripts/build-ffmpeg-lgpl.sh"

mkdir -p "${RESOURCES_DIR}" "$(dirname "${FFMPEG}")"

if [[ -x "${FFMPEG}" ]]; then
  if "${FFMPEG}" -version 2>&1 | grep -qiE 'configuration:.*--enable-gpl'; then
    echo "error: Bundled FFmpeg was built with --enable-gpl (not LGPL-compliant for distribution)."
    echo "Remove ${FFMPEG} and run: ${BUILD_SCRIPT}"
    exit 1
  fi
  if "${FFMPEG}" -version 2>&1 | grep -qiE 'configuration:.*--enable-nonfree'; then
    echo "error: Bundled FFmpeg was built with --enable-nonfree."
    echo "Remove ${FFMPEG} and run: ${BUILD_SCRIPT}"
    exit 1
  fi
  echo "LGPL-compliant ffmpeg already present at ${FFMPEG}"
  exit 0
fi

cat <<EOF
error: No FFmpeg binary found at ${FFMPEG}

ConvertIt bundles FFmpeg for video/audio conversion and must comply with LGPLv2.1.
Do not drop in a GPL build (libx264, evermeet.cx snapshots, etc.).

Build an LGPL-compliant binary once:

  ${BUILD_SCRIPT}

Then rebuild the app in Xcode.

See ThirdParty/FFmpeg/COMPLIANCE.md for the full distributor checklist.
EOF
exit 1
