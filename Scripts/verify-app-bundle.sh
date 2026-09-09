#!/bin/bash
# Sanity-check a built Convert It.app before export/notarization.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: verify-app-bundle.sh /path/to/Convert It.app

Checks bundled FFmpeg, dylibs, LGPL configuration, and a local smoke test.
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

APP="$1"
FFMPEG="${APP}/Contents/Resources/ffmpeg"
FRAMEWORKS="${APP}/Contents/Frameworks"

if [[ ! -d "${APP}" ]]; then
  echo "error: App bundle not found: ${APP}"
  exit 1
fi

if [[ ! -x "${FFMPEG}" ]]; then
  echo "error: Missing bundled ffmpeg at ${FFMPEG}"
  exit 1
fi

echo "== Convert It bundle check =="
echo "App: ${APP}"
echo ""

fail=0
pass() { echo "  OK  $*"; }
warn() { echo "  WARN  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }

if otool -L "${FFMPEG}" | grep -qE '/opt/homebrew|/usr/local'; then
  bad "ffmpeg still references Homebrew paths"
  otool -L "${FFMPEG}" | grep -E '/opt/homebrew|/usr/local' || true
else
  pass "ffmpeg has no Homebrew dylib paths"
fi

if [[ ! -d "${FRAMEWORKS}" ]] || ! compgen -G "${FRAMEWORKS}/*.dylib" >/dev/null; then
  bad "Contents/Frameworks dylibs missing"
else
  pass "Frameworks dylibs present ($(ls "${FRAMEWORKS}"/*.dylib | wc -l | tr -d ' ') libs)"
fi

if [[ -f "${FRAMEWORKS}/libwebp.7.dylib" ]]; then
  if otool -L "${FRAMEWORKS}/libwebp.7.dylib" | grep -q '@rpath/libsharpyuv'; then
    bad "libwebp still uses @rpath for libsharpyuv (re-archive after bundle-ffmpeg-dylibs fix)"
  else
    pass "libwebp sharpyuv path rewritten"
  fi
fi

config="$("${FFMPEG}" -version 2>&1 | grep '^configuration:' || true)"
if [[ -z "${config}" ]]; then
  bad "ffmpeg -version failed (dyld or signing issue)"
elif grep -qiE 'enable-gpl|enable-nonfree|enable-libx264' <<<"${config}"; then
  bad "ffmpeg configuration is not LGPL-safe"
  echo "       ${config}"
else
  pass "ffmpeg configuration is LGPL-safe"
fi

if "${FFMPEG}" -version >/dev/null 2>&1; then
  pass "ffmpeg smoke test (-version)"
else
  bad "ffmpeg smoke test failed"
  "${FFMPEG}" -version 2>&1 | head -5 || true
fi

if "${FFMPEG}" -encoders 2>/dev/null | grep -q 'libwebp'; then
  pass "libwebp encoder available"
else
  warn "libwebp encoder not listed (ImageIO WebP still works)"
fi

echo ""
if (( fail )); then
  echo "Bundle verification failed."
  exit 1
fi

echo "Bundle verification passed."
