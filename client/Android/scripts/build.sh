#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../Studio" && pwd)"

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

resolve_android_sdk() {
  local sdk_dir="${ANDROID_HOME:-}"

  if [[ -z "${sdk_dir}" ]]; then
    sdk_dir="${ANDROID_SDK_ROOT:-}"
  fi

  if [[ -z "${sdk_dir}" ]]; then
    local properties_file="${PROJECT_DIR}/local.properties"
    sdk_dir="$(read_local_property "${properties_file}" "sdk.dir")"
  fi

  if [[ -z "${sdk_dir}" ]]; then
    sdk_dir="${HOME}/Library/Android/sdk"
  fi

  if [[ ! -d "${sdk_dir}" ]]; then
    printf 'Invalid Android SDK directory: %s\n' "${sdk_dir}" >&2
    printf 'Set ANDROID_HOME or add sdk.dir to local.properties\n' >&2
    exit 1
  fi

  printf '%s\n' "${sdk_dir}"
}

resolve_gradlew() {
  local gradlew="${PROJECT_DIR}/gradlew"

  if [[ ! -x "${gradlew}" ]]; then
    chmod +x "${gradlew}"
  fi

  if [[ ! -f "${gradlew}" ]]; then
    printf 'gradlew not found at: %s\n' "${gradlew}" >&2
    exit 1
  fi

  printf '%s\n' "${gradlew}"
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
        libfreerdp \
        winpr \
        include \
        cmake \
        client/Android/Studio/freeRDPCore/src/main/cpp \
        CMakeLists.txt \
        client/CMakeLists.txt \
        client/Android/Studio/freeRDPCore/src/main/cpp/CMakeLists.txt 2>/dev/null || true
      git -C "${repo_root}" ls-files --others --exclude-standard -- \
        libfreerdp \
        winpr \
        include \
        cmake \
        client/Android/Studio/freeRDPCore/src/main/cpp \
        CMakeLists.txt \
        client/CMakeLists.txt \
        client/Android/Studio/freeRDPCore/src/main/cpp/CMakeLists.txt 2>/dev/null || true
    } | awk 'NF && !seen[$0]++'
  )"

  if [[ -n "${changes}" ]]; then
    printf '%s\n' "${changes}"
  fi
}

clean_cmake_cache() {
  log "Cleaning CMake cache (preserving OpenSSL/FreeRDP prebuilt libs)"

  local cxx_dir="${PROJECT_DIR}/freeRDPCore/.cxx"
  if [[ -d "${cxx_dir}" ]]; then
    find "${cxx_dir}" -name "CMakeCache.txt" -type f -delete 2>/dev/null || true
    find "${cxx_dir}" -name "cmake_install.cmake" -type f -delete 2>/dev/null || true
    find "${cxx_dir}" -type d -name "CMakeFiles" -exec rm -rf {} + 2>/dev/null || true
    find "${cxx_dir}" -name ".ninja_deps" -type f -delete 2>/dev/null || true
    find "${cxx_dir}" -name ".ninja_log" -type f -delete 2>/dev/null || true
    find "${cxx_dir}" -name "build.ninja" -type f -delete 2>/dev/null || true
  fi

  log "CMake cache cleaned"
}

clean_full() {
  log "Performing full clean"

  local gradlew
  gradlew="$(resolve_gradlew)"

  (
    cd "${PROJECT_DIR}"
    "${gradlew}" clean
  )

  log "Full clean completed"
}

resolve_release_properties() {
  local prop_file="${PROJECT_DIR}/release.properties"
  local local_prop_file="${PROJECT_DIR}/local.properties"

  RELEASE_STORE_FILE="$(read_local_property "${local_prop_file}" "RELEASE_STORE_FILE")"
  RELEASE_KEY_ALIAS="$(read_local_property "${local_prop_file}" "RELEASE_KEY_ALIAS")"
  RELEASE_KEY_PASSWORD="$(read_local_property "${local_prop_file}" "RELEASE_KEY_PASSWORD")"
  RELEASE_STORE_PASSWORD="$(read_local_property "${local_prop_file}" "RELEASE_STORE_PASSWORD")"

  if [[ -f "${prop_file}" ]]; then
    if [[ -z "${RELEASE_STORE_FILE}" ]]; then
      RELEASE_STORE_FILE="$(read_local_property "${prop_file}" "RELEASE_STORE_FILE")"
    fi
    if [[ -z "${RELEASE_KEY_ALIAS}" ]]; then
      RELEASE_KEY_ALIAS="$(read_local_property "${prop_file}" "RELEASE_KEY_ALIAS")"
    fi
    if [[ -z "${RELEASE_KEY_PASSWORD}" ]]; then
      RELEASE_KEY_PASSWORD="$(read_local_property "${prop_file}" "RELEASE_KEY_PASSWORD")"
    fi
    if [[ -z "${RELEASE_STORE_PASSWORD}" ]]; then
      RELEASE_STORE_PASSWORD="$(read_local_property "${prop_file}" "RELEASE_STORE_PASSWORD")"
    fi
  fi
}

build() {
  local mode="$1"
  local force_clean="${2:-false}"
  local abi="${3:-}"
  local skip_native="${4:-auto}"

  local gradlew
  gradlew="$(resolve_gradlew)"

  local sdk_dir
  sdk_dir="$(resolve_android_sdk)"

  log "SDK: ${sdk_dir}"
  log "gradlew: ${gradlew}"
  log "Build mode: ${mode}"

  if [[ "${force_clean}" == "true" ]]; then
    clean_full
  fi

  local native_changes
  native_changes="$(detect_native_changes)"

  if [[ "${skip_native}" == "auto" ]]; then
    local native_cache="${PROJECT_DIR}/freeRDPCore/.native-libs-cache"
    if [[ -n "${native_changes}" ]]; then
      skip_native="false"
      log "Auto-detect: native code changed, full build required"
      printf '  %s\n' "${native_changes}"
    elif [[ ! -d "${native_cache}" ]] || [[ -z "$(ls -A "${native_cache}" 2>/dev/null)" ]]; then
      skip_native="false"
      log "Auto-detect: no cached native libs found, full build required"
    else
      skip_native="true"
      log "Auto-detect: no native code changes, skipping CMake build"
    fi
  fi

  if [[ "${skip_native}" == "false" && "${force_clean}" != "true" && -n "${native_changes}" ]]; then
    log "Native/CMake changes detected, cleaning CMake cache"
    clean_cmake_cache
  fi

  local gradle_task
  local output_dir

  if [[ "${mode}" == "release" ]]; then
    gradle_task="assembleRelease"
    output_dir="${PROJECT_DIR}/aFreeRDP/build/outputs/apk/release"
  else
    gradle_task="assembleDebug"
    output_dir="${PROJECT_DIR}/aFreeRDP/build/outputs/apk/debug"
  fi

  local gradle_args=()
  gradle_args+=("${gradle_task}")

  if [[ -n "${abi}" ]]; then
    log "Filtering ABI: ${abi}"
    gradle_args+=("-Pandroid.buildOnlyPreDexedDexes=true")
  fi

  if [[ "${skip_native}" == "true" ]]; then
    gradle_args+=("-PskipNativeBuild")
    log "Skipping native CMake build (using cached .so files)"
  fi

  log "Building Android application package (${mode})"
  (
    cd "${PROJECT_DIR}"
    ANDROID_HOME="${sdk_dir}" \
    ANDROID_SDK_ROOT="${sdk_dir}" \
    "${gradlew}" "${gradle_args[@]}"
  )

  local out_dir="${PROJECT_DIR}/build/outputs/${mode}"
  mkdir -p "${out_dir}"

  if [[ -d "${output_dir}" ]]; then
    cp -v "${output_dir}"/*.apk "${out_dir}/" 2>/dev/null || true
  fi

  log "Artifacts saved to: ${out_dir}"
  ls -la "${out_dir}/"
}

print_usage() {
  printf 'Usage: %s [OPTIONS] [debug|release]\n' "${0##*/}"
  printf '\n'
  printf 'Build modes:\n'
  printf '  debug          Build debug APK (default)\n'
  printf '  release        Build release APK\n'
  printf '\n'
  printf 'Options:\n'
  printf '  --clean        Force full clean before build\n'
  printf '  --clean-cmake  Clean only CMake cache (preserve prebuilt libs)\n'
  printf '  --skip-native  Skip native CMake build (requires prior full build)\n'
  printf '  --full         Force full build including native code\n'
  printf '  -h, --help     Show this help message\n'
  printf '\n'
  printf 'Auto-detection (default):\n'
  printf '  If neither --skip-native nor --full is specified, the script\n'
  printf '  automatically detects native code changes and skips CMake when\n'
  printf '  only frontend (Java) code has been modified.\n'
  printf '\n'
  printf 'Environment variables:\n'
  printf '  ANDROID_HOME             Android SDK path\n'
  printf '  ANDROID_SDK_ROOT         Alternative Android SDK path\n'
}

main() {
  local build_mode="debug"
  local force_clean="false"
  local do_clean_cmake="false"
  local skip_native="auto"

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
      --clean-cmake)
        do_clean_cmake="true"
        shift
        ;;
      --skip-native|fast)
        skip_native="true"
        shift
        ;;
      --full)
        skip_native="false"
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

  if [[ "${do_clean_cmake}" == "true" ]]; then
    clean_cmake_cache
    exit 0
  fi

  build "${build_mode}" "${force_clean}" "" "${skip_native}"
  log "Build completed successfully (${build_mode})"
}

main "$@"
