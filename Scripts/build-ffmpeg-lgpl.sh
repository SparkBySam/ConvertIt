#!/bin/bash
# Builds an LGPLv2.1-compliant FFmpeg binary for bundling with ConvertIt.
#
# Requirements: Xcode CLI tools, curl, git, nasm, pkg-config, and Homebrew libraries:
#   brew install nasm pkg-config lame libvorbis opus libvpx webp
#
# Output:
#   BundledBinaries/ffmpeg
#   Convert It/Resources/ffmpeg-build-info.txt
#   ThirdParty/FFmpeg/dist/convertit-ffmpeg-<version>-src.tar.gz  (for hosting)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES_DIR="${ROOT}/Convert It/Resources"
BUNDLED_BINARIES_DIR="${ROOT}/BundledBinaries"
DIST_DIR="${ROOT}/ThirdParty/FFmpeg/dist"
BUILD_ROOT="${ROOT}/ThirdParty/FFmpeg/build"
FFMPEG_TAG="n7.1"
FFMPEG_VERSION="7.1"
SOURCE_URL="https://convertitapp.com/legal/ffmpeg-source"

mkdir -p "${RESOURCES_DIR}" "${BUNDLED_BINARIES_DIR}" "${DIST_DIR}" "${BUILD_ROOT}"

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is required to provide LGPL build dependencies (lame, libvpx, etc.)."
  exit 1
fi

for dep in nasm pkg-config lame libvorbis opus libvpx webp; do
  if ! brew list "${dep}" >/dev/null 2>&1; then
    echo "Installing ${dep}…"
    brew install "${dep}"
  fi
done

BREW_PREFIX="$(brew --prefix)"
export PKG_CONFIG_PATH="${BREW_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

SRC_DIR="${BUILD_ROOT}/ffmpeg-${FFMPEG_VERSION}"
if [[ ! -d "${SRC_DIR}/.git" ]]; then
  rm -rf "${SRC_DIR}"
  git clone --depth 1 --branch "${FFMPEG_TAG}" https://git.ffmpeg.org/ffmpeg.git "${SRC_DIR}"
fi

pushd "${SRC_DIR}" >/dev/null
git fetch --depth 1 origin "${FFMPEG_TAG}" 2>/dev/null || true
git checkout "${FFMPEG_TAG}" 2>/dev/null || git checkout "tags/${FFMPEG_TAG}" 2>/dev/null || true
make distclean >/dev/null 2>&1 || true

INSTALL_PREFIX="${BUILD_ROOT}/install"

CONFIGURE_ARGS=(
  "--prefix=${INSTALL_PREFIX}"
  --disable-debug
  --disable-doc
  --disable-ffplay
  --disable-sdl2
  --disable-xlib
  --disable-indev=xcbgrab
  --disable-gpl
  --disable-nonfree
  --enable-static
  --disable-shared
  --enable-libmp3lame
  --enable-libvorbis
  --enable-libopus
  --enable-libvpx
  --enable-libwebp
  --enable-videotoolbox
  --enable-audiotoolbox
  "--extra-cflags=-I${BREW_PREFIX}/include"
  "--extra-ldflags=-L${BREW_PREFIX}/lib"
  "--pkg-config-flags=--static"
)

./configure "${CONFIGURE_ARGS[@]}"

CONFIGURE_LINE="./configure ${CONFIGURE_ARGS[*]}"
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
popd >/dev/null

install -m 755 "${SRC_DIR}/ffmpeg" "${BUNDLED_BINARIES_DIR}/ffmpeg"
xattr -cr "${BUNDLED_BINARIES_DIR}/ffmpeg" 2>/dev/null || true

# Verify the build can be bundled sandbox-safe (Xcode rewrites/signs again in the .app).
source "${ROOT}/Scripts/bundle-ffmpeg-dylibs.sh"
VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "${VERIFY_DIR}"' EXIT
if ! verify_bundled_ffmpeg_layout "${BUNDLED_BINARIES_DIR}/ffmpeg" "${VERIFY_DIR}"; then
  exit 1
fi

echo "Verified: FFmpeg runs with bundled dylibs (sandbox-safe)."

git -C "${SRC_DIR}" diff > "${SRC_DIR}/changes.diff" || true

cat > "${SRC_DIR}/COMPILE.txt" <<EOF
ConvertIt FFmpeg build
======================
Built: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
FFmpeg tag: ${FFMPEG_TAG}
Host: $(uname -a)

Configure line:
${CONFIGURE_LINE}

Bundled codecs intentionally avoid GPL libx264. H.264 output uses h264_videotoolbox at runtime.

Build uses --enable-static --disable-shared so the binary has no Homebrew dylib dependencies.

LGPL dependencies compiled into this binary (source must also be offered):
- LAME (libmp3lame)
- libvorbis
- libopus
- libvpx
- libwebp
EOF

ARCHIVE="${DIST_DIR}/convertit-ffmpeg-${FFMPEG_VERSION}-src.tar.gz"
tar -czf "${ARCHIVE}" -C "${BUILD_ROOT}" "ffmpeg-${FFMPEG_VERSION}"

cat > "${RESOURCES_DIR}/ffmpeg-build-info.txt" <<EOF
FFmpeg ${FFMPEG_VERSION} (${FFMPEG_TAG})
Built for ConvertIt — LGPLv2.1 compliant (no --enable-gpl, no --enable-nonfree)
Source tarball: ${SOURCE_URL}/convertit-ffmpeg-${FFMPEG_VERSION}-src.tar.gz
Project: https://ffmpeg.org
License: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
EOF

echo ""
echo "Installed ${BUNDLED_BINARIES_DIR}/ffmpeg"
echo "Source archive for distribution: ${ARCHIVE}"
echo "Upload the tarball to ${SOURCE_URL}/ before shipping the app."
echo ""
"${BUNDLED_BINARIES_DIR}/ffmpeg" -version | head -3
