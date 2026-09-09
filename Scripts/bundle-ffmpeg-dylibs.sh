#!/bin/bash
# Rewrites Homebrew dylib paths so bundled ffmpeg runs inside the sandboxed app.
# Expects ffmpeg in Contents/Resources and copies deps to Contents/Frameworks.
set -euo pipefail

bundle_ffmpeg_dylibs() {
  local binary="$1"
  local frameworks_dir="$2"
  local dep_prefix="${3:-@executable_path/../Frameworks}"

  mkdir -p "${frameworks_dir}"

  local pending=("${binary}")
  local -a processed=()

  while ((${#pending[@]})); do
    local current="${pending[0]}"
    pending=("${pending[@]:1}")

    local already=0
    for done in "${processed[@]:-}"; do
      [[ "$done" == "$current" ]] && already=1 && break
    done
    (( already )) && continue
    processed+=("${current}")

    while IFS= read -r dep; do
      [[ -z "${dep}" ]] && continue
      [[ "${dep}" != /opt/homebrew/* && "${dep}" != /usr/local/* ]] && continue

      local name dest new_path
      name="$(basename "${dep}")"
      dest="${frameworks_dir}/${name}"

      if [[ "${current}" == "${binary}" ]]; then
        new_path="${dep_prefix}/${name}"
      else
        new_path="@loader_path/${name}"
      fi

      if [[ ! -f "${dest}" ]]; then
        cp "${dep}" "${dest}"
        chmod 755 "${dest}"
        xattr -cr "${dest}" 2>/dev/null || true
        install_name_tool -id "${new_path}" "${dest}"
        pending+=("${dest}")
      fi

      install_name_tool -change "${dep}" "${new_path}" "${current}" 2>/dev/null || true
    done < <(otool -L "${current}" | awk 'NR>1 {print $1}')
  done

  fix_rpath_deps_in_frameworks "${frameworks_dir}"
}

# libwebp and similar Homebrew builds reference sibling libs via @rpath, not absolute paths.
fix_rpath_deps_in_frameworks() {
  local frameworks_dir="$1"

  for lib in "${frameworks_dir}"/*.dylib; do
    [[ -e "${lib}" ]] || continue
    while IFS= read -r dep; do
      [[ "${dep}" == @rpath/* ]] || continue
      local name="${dep#@rpath/}"
      [[ -f "${frameworks_dir}/${name}" ]] || continue
      install_name_tool -change "${dep}" "@loader_path/${name}" "${lib}" 2>/dev/null || true
    done < <(otool -L "${lib}" | awk 'NR>1 {print $1}')
  done
}

ad_hoc_sign() {
  local target="$1"
  codesign --force --sign - "${target}" >/dev/null 2>&1 || codesign -f -s - "${target}"
}

# Verifies rewritten ffmpeg in a fake .app layout (Resources + Frameworks).
verify_bundled_ffmpeg_layout() {
  local source_ffmpeg="$1"
  local work_dir="$2"

  local app_root="${work_dir}/ConvertIt.app"
  local resources_dir="${app_root}/Contents/Resources"
  local frameworks_dir="${app_root}/Contents/Frameworks"

  mkdir -p "${resources_dir}" "${frameworks_dir}"
  cp "${source_ffmpeg}" "${resources_dir}/ffmpeg"
  chmod +x "${resources_dir}/ffmpeg"

  bundle_ffmpeg_dylibs "${resources_dir}/ffmpeg" "${frameworks_dir}" "@executable_path/../Frameworks"

  if otool -L "${resources_dir}/ffmpeg" | grep -qE '/opt/homebrew|/usr/local'; then
    echo "error: FFmpeg still references Homebrew paths after dylib bundling."
    otool -L "${resources_dir}/ffmpeg" | grep -E '/opt/homebrew|/usr/local' || true
    return 1
  fi

  ad_hoc_sign "${resources_dir}/ffmpeg"
  for lib in "${frameworks_dir}"/*.dylib; do
    [[ -e "${lib}" ]] || continue
    ad_hoc_sign "${lib}"
  done

  if ! "${resources_dir}/ffmpeg" -version >/dev/null 2>&1; then
    echo "error: Bundled FFmpeg failed a local smoke test after rewriting dylib paths."
    "${resources_dir}/ffmpeg" -version 2>&1 | head -5 || true
    return 1
  fi

  return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  bundle_ffmpeg_dylibs "$1" "$2" "${3:-@executable_path/../Frameworks}"
fi
