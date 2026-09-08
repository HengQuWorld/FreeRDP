#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
  printf '[build] %s\n' "$1" >&2
}

read_local_property() {
  local properties_file="$1"
  local key="$2"

  if [[ ! -f "${properties_file}" ]]; then
    return 0
  fi

  awk -F= -v property_key="${key}" '
    $1 == property_key {
      sub(/^[^=]*=/, "", $0)
      print
      exit
    }
  ' "${properties_file}"
}

resolve_sdk_dir() {
  local sdk_dir="${DEVECO_SDK_HOME:-}"

  if [[ -z "${sdk_dir}" ]]; then
    local properties_file="${PROJECT_DIR}/local.properties"

    sdk_dir="$(read_local_property "${properties_file}" "hwsdk.dir")"
    if [[ -z "${sdk_dir}" ]]; then
      sdk_dir="$(read_local_property "${properties_file}" "sdk.dir")"
    fi
  fi
  if [[ -z "${sdk_dir}" ]]; then
    sdk_dir="/Applications/DevEco-Studio.app/Contents/sdk"
  fi

  if [[ ! -d "${sdk_dir}" ]]; then
    printf 'Invalid HarmonyOS SDK directory: %s\n' "${sdk_dir}" >&2
    exit 1
  fi

  printf '%s\n' "${sdk_dir}"
}

resolve_hvigor_bin() {
  local sdk_dir="$1"

  if command -v hvigorw >/dev/null 2>&1; then
    command -v hvigorw
    return 0
  fi

  local deveco_root
  deveco_root="$(cd "${sdk_dir}/.." && pwd)"
  local hvigor_bin="${deveco_root}/tools/hvigor/bin/hvigorw"

  if [[ -x "${hvigor_bin}" ]]; then
    printf '%s\n' "${hvigor_bin}"
    return 0
  fi

  printf 'Unable to find hvigorw. Expected: %s or in PATH\n' "${hvigor_bin}" >&2
  exit 1
}

detect_native_changes() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  local repo_root
  repo_root="$(cd "${PROJECT_DIR}/../.." && pwd)"

  if ! git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  local changes
  changes="$(
    {
      git -C "${repo_root}" diff --name-only HEAD -- \
        client/Harmony/cmake \
        client/Harmony/native \
        client/Harmony/entry/src/main/cpp \
        channels \
        libfreerdp \
        winpr \
        include \
        cmake 2>/dev/null || true
      git -C "${repo_root}" ls-files --others --exclude-standard -- \
        client/Harmony/cmake \
        client/Harmony/native \
        client/Harmony/entry/src/main/cpp \
        channels \
        libfreerdp \
        winpr \
        include \
        cmake 2>/dev/null || true
    } | awk 'NF && !seen[$0]++'
  )"

  if [[ -n "${changes}" ]]; then
    printf '%s\n' "${changes}"
  fi
}

freerdp_cache_dir() {
  local repo_root
  repo_root="$(cd "${PROJECT_DIR}/../.." && pwd)"
  printf '%s/cache/build/freerdp\n' "${repo_root}"
}

clean_freerdp_cache() {
  local cache_dir
  cache_dir="$(freerdp_cache_dir)"

  if [[ -d "${cache_dir}" ]]; then
    log "Removing FreeRDP persistent cache: ${cache_dir}"
    rm -rf "${cache_dir}"
  fi
}

has_freerdp_source_changes() {
  local native_changes="$1"

  if [[ -z "${native_changes}" ]]; then
    return 1
  fi

  # Check if any changed file is in FreeRDP source directories
  if printf '%s\n' "${native_changes}" | grep -qE '^(channels|libfreerdp|winpr|include|cmake)/'; then
    return 0
  fi

  return 1
}

clean_bridge_only() {
  log "Performing incremental clean (bridge layer only)"
  
  local cmake_intermediates="${PROJECT_DIR}/entry/build/default/intermediates/cmake"
  local cmake_outputs="${PROJECT_DIR}/entry/build/default/outputs"
  
  if [[ -d "${cmake_intermediates}" ]]; then
    log "Removing CMake intermediates: ${cmake_intermediates}"
    rm -rf "${cmake_intermediates}"
  fi
  
  if [[ -d "${cmake_outputs}" ]]; then
    log "Removing CMake outputs: ${cmake_outputs}"
    rm -rf "${cmake_outputs}"
  fi
  
  local entry_build="${PROJECT_DIR}/entry/build"
  if [[ -d "${entry_build}" ]]; then
    find "${entry_build}" -name "*.so" -type f -delete 2>/dev/null || true
    find "${entry_build}" -name "CMakeCache.txt" -type f -delete 2>/dev/null || true
    find "${entry_build}" -name "cmake_install.cmake" -type f -delete 2>/dev/null || true
    find "${entry_build}" -type d -name "CMakeFiles" -exec rm -rf {} + 2>/dev/null || true
  fi
  
  log "Bridge layer cleaned, OpenSSL/FreeRDP cache preserved"
}

clean_full() {
  log "Performing full clean"

  local sdk_dir
  local hvigor_bin

  sdk_dir="$(resolve_sdk_dir)"
  hvigor_bin="$(resolve_hvigor_bin "${sdk_dir}")"

  (
    cd "${PROJECT_DIR}"
    env -u DEVECO_SDK_HOME -u HOS_SDK_HOME -u OHOS_SDK_HOME -u OHOS_BASE_SDK_HOME \
      DEVECO_SDK_HOME="${sdk_dir}" \
      "${hvigor_bin}" clean
  )

  clean_freerdp_cache

  log "Full clean completed"
}

build() {
  local mode="$1"
  local force_clean="${2:-false}"

  local sdk_dir
  local hvigor_bin

  sdk_dir="$(resolve_sdk_dir)"
  hvigor_bin="$(resolve_hvigor_bin "${sdk_dir}")"

  log "SDK: ${sdk_dir}"
  log "hvigorw: ${hvigor_bin}"
  log "Build mode: ${mode}"

  local mode_file="${PROJECT_DIR}/.build-signing-mode"
  echo "${mode}" > "${mode_file}"
  trap "rm -f '${mode_file}'" RETURN

  local force_rebuild_freerdp="${FORCE_REBUILD_FREERDP:-0}"

  if [[ "${force_clean}" == "true" ]]; then
    clean_full
    force_rebuild_freerdp=1
  else
    local native_changes
    native_changes="$(detect_native_changes)"

    if [[ -n "${native_changes}" ]]; then
      log "Native/CMake changes detected:"
      printf '%s\n' "${native_changes}"

      if has_freerdp_source_changes "${native_changes}"; then
        log "FreeRDP source changes detected, clearing persistent cache"
        clean_freerdp_cache
        force_rebuild_freerdp=1
      else
        clean_bridge_only
      fi
    fi
  fi

  log "Building HarmonyOS application package (${mode})"
  (
    cd "${PROJECT_DIR}"
    env -u DEVECO_SDK_HOME -u HOS_SDK_HOME -u OHOS_SDK_HOME -u OHOS_BASE_SDK_HOME \
      DEVECO_SDK_HOME="${sdk_dir}" \
      FORCE_REBUILD_FREERDP="${force_rebuild_freerdp}" \
      "${hvigor_bin}" assembleApp -p product=default -p buildMode="${mode}"
  )

  local out_dir="${PROJECT_DIR}/build/outputs/default/${mode}"
  mkdir -p "${out_dir}"

  local entry_build_dir="${PROJECT_DIR}/entry/build/default/outputs/default"

  if [[ -f "${entry_build_dir}/entry-default-signed.hap" ]]; then
    cp "${entry_build_dir}/entry-default-signed.hap" "${out_dir}/"
  fi
  if [[ -f "${entry_build_dir}/entry-default-unsigned.hap" ]]; then
    cp "${entry_build_dir}/entry-default-unsigned.hap" "${out_dir}/"
  fi

  local app_build_dir="${PROJECT_DIR}/build/outputs/default"
  if compgen -G "${app_build_dir}/*-default-signed.app" >/dev/null 2>&1; then
    cp "${app_build_dir}/"*-default-signed.app "${out_dir}/"
  fi
  if compgen -G "${app_build_dir}/*-default-unsigned.app" >/dev/null 2>&1; then
    cp "${app_build_dir}/"*-default-unsigned.app "${out_dir}/"
  fi

  log "Artifacts saved to: ${out_dir}"
  ls -la "${out_dir}/"
}

print_usage() {
  printf 'Usage: %s [OPTIONS] [debug|release]\n' "${0##*/}"
  printf '\n'
  printf 'Build modes:\n'
  printf '  debug        Build debug package (default)\n'
  printf '  release      Build release package\n'
  printf '\n'
  printf 'Options:\n'
  printf '  --clean      Force full clean before build\n'
  printf '  --clean-bridge  Clean only bridge layer (preserve OpenSSL/FreeRDP cache)\n'
  printf '  -h, --help   Show this help message\n'
  printf '\n'
  printf 'Environment variables:\n'
  printf '  FORCE_REBUILD_OPENSSL=1   Force rebuild OpenSSL\n'
  printf '  FORCE_REBUILD_FREERDP=1   Force rebuild FreeRDP\n'
}

main() {
  local build_mode="debug"
  local force_clean="false"
  local do_clean_bridge="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      debug|release)
        build_mode="$1"
        shift
        ;;
      --release)
        build_mode="release"
        shift
        ;;
      --clean)
        force_clean="true"
        shift
        ;;
      --clean-bridge)
        do_clean_bridge="true"
        shift
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      *)
        print_usage
        exit 1
        ;;
    esac
  done

  if [[ "${do_clean_bridge}" == "true" ]]; then
    clean_bridge_only
    exit 0
  fi

  build "${build_mode}" "${force_clean}"
  log "Build completed successfully (${build_mode})"
}

main "$@"
