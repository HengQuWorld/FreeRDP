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

# Every location the script considers, most specific first. The search and
# the "not found" report both read this list, so they cannot drift apart.
android_sdk_candidates() {
  local properties_file

  printf '%s\n' "${ANDROID_HOME:-}"
  printf '%s\n' "${ANDROID_SDK_ROOT:-}"

  for properties_file in \
    "${PROJECT_DIR}/local.properties" \
    "${PROJECT_DIR}/../local.properties"; do
    printf '%s\n' "$(read_local_property "${properties_file}" "sdk.dir")"
  done

  # Conventional install locations, macOS first and then Linux.
  printf '%s\n' \
    "${HOME}/Library/Android/sdk" \
    "${HOME}/Android/Sdk" \
    "${HOME}/Android/sdk" \
    "/Applications/Android Studio.app/Contents/sdk" \
    "/opt/homebrew/share/android-commandlinetools" \
    "/usr/local/share/android-commandlinetools" \
    "/usr/lib/android-sdk" \
    "/opt/android-sdk"
}

report_sdk_not_found() {
  {
    printf '[build] No Android SDK found.\n'
    printf '[build] Searched, in order:\n'
    android_sdk_candidates | awk 'NF && !seen[$0]++ { printf "          %s\n", $0 }'
    printf '\n'
    printf '[build] Point the build at an existing SDK:\n'
    printf '          export ANDROID_HOME=/path/to/android-sdk\n'
    printf '          or add "sdk.dir=/path/to/android-sdk" to\n'
    printf '            %s/local.properties\n' "${PROJECT_DIR}"
    printf '\n'
    printf '[build] Or install one:\n'
    printf '          macOS: brew install --cask android-commandlinetools\n'
    printf '          Linux: https://developer.android.com/studio#command-line-tools-only\n'
    printf '          then:  sdkmanager "platform-tools" "platforms;android-%s" \\\n' "${DEFAULT_COMPILE_API}"
    printf '                            "build-tools;%s" "ndk;%s" "cmake;%s"\n' \
      "${DEFAULT_TOOLS_VERSION}" "${DEFAULT_NDK_VERSION}" "${ANDROID_CMAKE_VERSION}"
  } >&2
}

resolve_android_sdk() {
  local candidate

  while IFS= read -r candidate; do
    if [[ -n "${candidate}" && -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done <<EOF
$(android_sdk_candidates)
EOF

  return 1
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

# ---------------------------------------------------------------------------
# Environment preflight
# ---------------------------------------------------------------------------

# Defaults mirror client/Android/Studio/build.gradle; a release.properties in
# the Gradle project overrides them, which read_gradle_default honours.
DEFAULT_COMPILE_API="36"
DEFAULT_TOOLS_VERSION="36.0.0"
DEFAULT_NDK_VERSION="29.0.13113456"
ANDROID_CMAKE_VERSION="3.22.1"
ANDROID_MIN_JDK="17"

PREFLIGHT_ERRORS=0
PREFLIGHT_WARNINGS=0

preflight_note() {
  local level="$1"
  local what="$2"
  shift 2

  local hint
  {
    printf '  [%s] %s\n' "${level}" "${what}"
    for hint in "$@"; do
      printf '            %s\n' "${hint}"
    done
  } >&2
}

preflight_error() {
  PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
  preflight_note "missing" "$@"
}

preflight_warn() {
  PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
  preflight_note "warn" "$@"
}

read_ndk_version() {
  local gradle_file="${PROJECT_DIR}/freeRDPCore/build.gradle"
  local version=""

  if [[ -f "${gradle_file}" ]]; then
    version="$(
      sed -n 's/^[[:space:]]*ndkVersion[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "${gradle_file}" | head -n 1
    )"
  fi

  printf '%s\n' "${version:-${DEFAULT_NDK_VERSION}}"
}

read_gradle_default() {
  local property="$1"
  local fallback="$2"
  local prop_file="${PROJECT_DIR}/release.properties"
  local value=""

  if [[ -f "${prop_file}" ]]; then
    value="$(read_local_property "${prop_file}" "${property}")"
  fi

  printf '%s\n' "${value:-${fallback}}"
}

sdk_manager_hint() {
  local sdk_dir="$1"
  local package="$2"
  local manager="${sdk_dir}/cmdline-tools/latest/bin/sdkmanager"

  if [[ -x "${manager}" ]]; then
    printf '%s "%s"\n' "${manager}" "${package}"
  else
    printf 'sdkmanager "%s"\n' "${package}"
  fi
}

check_host_tool() {
  local tool="$1"
  shift

  if command -v "${tool}" >/dev/null 2>&1; then
    return 0
  fi

  preflight_error "host tool '${tool}' not found in PATH" "$@"
}

check_java() {
  local java_bin=""

  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    java_bin="${JAVA_HOME}/bin/java"
  elif command -v java >/dev/null 2>&1; then
    java_bin="$(command -v java)"
  else
    preflight_error "no JDK found (JAVA_HOME unset and 'java' not in PATH)" \
      "Android Gradle Plugin requires JDK ${ANDROID_MIN_JDK} or newer." \
      'macOS: brew install --cask temurin'
    return 0
  fi

  local major
  major="$("${java_bin}" -version 2>&1 | head -n 1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p')"

  if [[ -z "${major}" ]]; then
    preflight_warn "could not determine the JDK version of ${java_bin}" \
      "Android Gradle Plugin requires JDK ${ANDROID_MIN_JDK} or newer."
  elif [[ "${major}" -lt "${ANDROID_MIN_JDK}" ]]; then
    preflight_error "JDK ${major} is too old (${java_bin})" \
      "Android Gradle Plugin requires JDK ${ANDROID_MIN_JDK} or newer."
  fi
}

# Missing SDK components are only fatal while the licences are unaccepted:
# with licences in place the Android Gradle Plugin downloads them for us, so
# blocking there would refuse a build that would in fact have succeeded.
SDK_COMPONENT_LEVEL="error"

has_sdk_licenses() {
  local sdk_dir="$1"

  [[ -d "${sdk_dir}/licenses" ]] && [[ -n "$(ls -A "${sdk_dir}/licenses" 2>/dev/null)" ]]
}

report_missing_sdk_component() {
  if [[ "${SDK_COMPONENT_LEVEL}" == "warn" ]]; then
    preflight_warn "$@"
  else
    preflight_error "$@"
  fi
}

# Rewrite `key` in a properties file so exactly one definition survives.
# Appending would be wrong twice over: a file whose last line has no newline
# would be joined to the new line, and a second definition would leave this
# script (which returns the first match) disagreeing with Gradle's
# java.util.Properties (which keeps the last).
set_local_property() {
  local properties_file="$1"
  local key="$2"
  local value="$3"
  local tmp_file="${properties_file}.tmp.$$"

  if awk -F= -v property_key="${key}" -v property_value="${value}" '
    $1 == property_key {
      if (!written) {
        printf "%s=%s\n", property_key, property_value
        written = 1
      }
      next
    }
    { print }
    END {
      if (!written) {
        printf "%s=%s\n", property_key, property_value
      }
    }
  ' "${properties_file}" > "${tmp_file}"; then
    # cat rather than mv, so a symlinked or specially permissioned file keeps
    # its inode and mode.
    cat "${tmp_file}" > "${properties_file}"
  fi

  rm -f "${tmp_file}"
}

# Gradle only reads local.properties for signing keys; the SDK itself may come
# from ANDROID_HOME, which the script always exports. Writing the file anyway
# keeps Android Studio and a bare ./gradlew working on a fresh checkout.
ensure_local_properties() {
  local sdk_dir="$1"
  local properties_file="${PROJECT_DIR}/local.properties"
  local configured

  if [[ ! -f "${properties_file}" ]]; then
    printf 'sdk.dir=%s\n' "${sdk_dir}" > "${properties_file}"
    log "Created ${properties_file} with sdk.dir=${sdk_dir}"
    return 0
  fi

  configured="$(read_local_property "${properties_file}" "sdk.dir")"

  if [[ "${configured}" == "${sdk_dir}" ]]; then
    return 0
  fi

  if [[ -n "${configured}" ]]; then
    log "Note: local.properties sdk.dir=${configured} differs from the SDK in use"
    return 0
  fi

  set_local_property "${properties_file}" "sdk.dir" "${sdk_dir}"
  log "Added sdk.dir=${sdk_dir} to $(basename "${properties_file}")"
}

gradle_property() {
  local property="$1"
  local value

  value="$(read_local_property "${PROJECT_DIR}/local.properties" "${property}")"
  if [[ -z "${value}" ]]; then
    value="$(read_local_property "${PROJECT_DIR}/release.properties" "${property}")"
  fi

  printf '%s\n' "${value}"
}

check_release_signing() {
  local store_file
  store_file="$(gradle_property RELEASE_STORE_FILE)"

  if [[ -z "${store_file}" ]]; then
    preflight_error 'no release signing keystore configured' \
      'Set RELEASE_STORE_FILE, RELEASE_STORE_PASSWORD, RELEASE_KEY_ALIAS and' \
      'RELEASE_KEY_PASSWORD in client/Android/Studio/local.properties.'
    return 0
  fi

  # Gradle does not expand a leading ~ in file(); match that before testing.
  store_file="${store_file/#\~\//${HOME}/}"
  if [[ ! -f "${store_file}" ]]; then
    preflight_error "release signing keystore not found: ${store_file}" \
      'Check RELEASE_STORE_FILE in client/Android/Studio/local.properties.'
  fi
}

# preflight <sdk_dir> <needs_native:true|false> <build_mode>
#
# Reports every missing host tool and Android SDK component in one pass, with
# the command that installs it, instead of failing somewhere inside Gradle or
# CMake. Errors are blocking; warnings are for components Gradle installs on
# its own once the SDK licences are accepted.
preflight() {
  local sdk_dir="$1"
  local needs_native="${2:-true}"
  local build_mode="${3:-debug}"

  PREFLIGHT_ERRORS=0
  PREFLIGHT_WARNINGS=0
  SDK_COMPONENT_LEVEL="error"

  log "Checking build environment"

  if has_sdk_licenses "${sdk_dir}"; then
    SDK_COMPONENT_LEVEL="warn"
  fi

  check_java

  if [[ "${build_mode}" == "release" ]]; then
    check_release_signing
  fi

  local ndk_version
  ndk_version="$(read_ndk_version)"
  local compile_api
  compile_api="$(read_gradle_default COMPILE_API "${DEFAULT_COMPILE_API}")"
  local tools_version
  tools_version="$(read_gradle_default TOOLS_VERSION "${DEFAULT_TOOLS_VERSION}")"

  if [[ "${needs_native}" == "true" ]]; then
    check_host_tool pkg-config \
      'Required by client/Android/cmake/ExternalFreeRDP.cmake.' \
      'macOS: brew install pkg-config | Debian: apt-get install pkg-config'
    check_host_tool make \
      'Used to build OpenH264 and FFmpeg from source.' \
      'macOS: xcode-select --install'
    check_host_tool perl \
      'Used by the OpenSSL Configure script.'
    check_host_tool git \
      'Used to fetch external sources (Opus, libpng, libjpeg-turbo, libwebp).'

    if [[ ! -d "${sdk_dir}/ndk/${ndk_version}" ]]; then
      report_missing_sdk_component "Android NDK ${ndk_version} not installed" \
        "Install with: $(sdk_manager_hint "${sdk_dir}" "ndk;${ndk_version}")" \
        'The version is pinned by client/Android/Studio/freeRDPCore/build.gradle.' \
        'Gradle downloads it automatically once the SDK licences are accepted.'
    fi

    if [[ ! -x "${sdk_dir}/cmake/${ANDROID_CMAKE_VERSION}/bin/cmake" ]]; then
      report_missing_sdk_component "Android SDK CMake ${ANDROID_CMAKE_VERSION} not installed" \
        "Install with: $(sdk_manager_hint "${sdk_dir}" "cmake;${ANDROID_CMAKE_VERSION}")" \
        'Gradle downloads it automatically once the SDK licences are accepted.'
    fi
  else
    log 'Skipping native toolchain checks (native build disabled)'
  fi

  if [[ ! -d "${sdk_dir}/platforms/android-${compile_api}" ]]; then
    preflight_warn "Android platform android-${compile_api} not installed" \
      "Install with: $(sdk_manager_hint "${sdk_dir}" "platforms;android-${compile_api}")" \
      'Gradle installs it automatically once the SDK licences are accepted.'
  fi

  if [[ ! -d "${sdk_dir}/build-tools/${tools_version}" ]]; then
    preflight_warn "Android build-tools ${tools_version} not installed" \
      "Install with: $(sdk_manager_hint "${sdk_dir}" "build-tools;${tools_version}")" \
      'Gradle installs it automatically once the SDK licences are accepted.'
  fi

  if [[ ! -d "${sdk_dir}/platform-tools" ]]; then
    preflight_warn 'Android platform-tools not installed (adb)' \
      "Install with: $(sdk_manager_hint "${sdk_dir}" 'platform-tools')" \
      'Only needed to deploy and debug on a device.'
  fi

  if [[ "${SDK_COMPONENT_LEVEL}" != "warn" ]]; then
    preflight_warn 'No accepted Android SDK licences found' \
      "Accept them with: $(sdk_manager_hint "${sdk_dir}" '--licenses')" \
      'Without them Gradle cannot install the SDK components listed above.'
  fi

  if [[ "${PREFLIGHT_ERRORS}" -gt 0 ]]; then
    {
      printf '\n'
      printf '[build] Environment check failed: %d missing component(s).\n' "${PREFLIGHT_ERRORS}"
      printf '[build] Install the items marked [missing] above, then re-run.\n'
    } >&2
    exit 1
  fi

  if [[ "${PREFLIGHT_WARNINGS}" -gt 0 ]]; then
    log "Environment check passed with ${PREFLIGHT_WARNINGS} warning(s)"
  else
    log 'Environment check passed'
  fi
}

# Native inputs: anything that changes the compiled output must force a rebuild,
# otherwise the script reuses stale .so files and packages an APK that does not
# match the source tree.
NATIVE_INPUT_PATHS=(
  libfreerdp
  winpr
  include
  cmake
  client/Android/cmake
  client/Android/Studio/build.gradle
  client/Android/Studio/freeRDPCore/build.gradle
  client/Android/Studio/freeRDPCore/src/main/cpp
  CMakeLists.txt
  client/CMakeLists.txt
)

detect_native_changes() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  # Repository root, not the Gradle project: git resolves the pathspecs below
  # relative to this directory, so being one level short makes every one of
  # them match nothing and silently disables change detection.
  local repo_root
  repo_root="$(cd "${PROJECT_DIR}/../../.." && pwd)"

  if ! git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  local changes
  changes="$(
    {
      git -C "${repo_root}" diff --name-only HEAD -- "${NATIVE_INPUT_PATHS[@]}" 2>/dev/null || true
      git -C "${repo_root}" ls-files --others --exclude-standard -- "${NATIVE_INPUT_PATHS[@]}" 2>/dev/null || true
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

build() {
  local mode="$1"
  local force_clean="${2:-false}"
  local skip_native="${3:-auto}"

  local gradlew
  gradlew="$(resolve_gradlew)"

  local sdk_dir
  if ! sdk_dir="$(resolve_android_sdk)"; then
    report_sdk_not_found
    exit 1
  fi

  ensure_local_properties "${sdk_dir}"

  log "SDK: ${sdk_dir}"
  log "gradlew: ${gradlew}"
  log "Build mode: ${mode}"

  if [[ "${force_clean}" == "true" ]]; then
    clean_full
  fi

  local native_changes
  native_changes="$(detect_native_changes)"

  if [[ "${skip_native}" == "auto" ]]; then
    # The cache is per variant, so inspect this variant's own subtree: another
    # variant having a populated cache says nothing about whether this one does.
    local native_cache="${PROJECT_DIR}/freeRDPCore/.native-libs-cache/${mode}"
    if [[ -n "${native_changes}" ]]; then
      skip_native="false"
      log "Auto-detect: native code changed, full build required"
      printf '  %s\n' "${native_changes}"
    elif [[ ! -d "${native_cache}" ]] || [[ -z "$(ls -A "${native_cache}" 2>/dev/null)" ]]; then
      skip_native="false"
      log "Auto-detect: no cached native libs for ${mode}, full build required"
    else
      skip_native="true"
      log "Auto-detect: no native code changes, skipping CMake build"
    fi
  fi

  local needs_native="true"
  if [[ "${skip_native}" == "true" ]]; then
    needs_native="false"
  fi

  preflight "${sdk_dir}" "${needs_native}" "${mode}"

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

  if [[ "${skip_native}" == "true" ]]; then
    gradle_args+=("-PskipNativeBuild")
    # The cached native libraries are variant-scoped; without this Gradle cannot
    # tell a debug build from a release one and refuses to guess.
    gradle_args+=("-PnativeLibsVariant=${mode}")
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
  printf '  --check        Check the build environment and exit\n'
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
  printf 'Environment check:\n'
  printf '  Every build first verifies the host tools and Android SDK\n'
  printf '  components it needs, listing what is missing and how to install\n'
  printf '  it. Use --check to run the check alone.\n'
  printf '\n'
  printf 'Environment variables:\n'
  printf '  ANDROID_HOME             Android SDK path\n'
  printf '  ANDROID_SDK_ROOT         Alternative Android SDK path\n'
  printf '  JAVA_HOME                JDK %s or newer (Gradle)\n' "${ANDROID_MIN_JDK}"
}

main() {
  local build_mode="debug"
  local force_clean="false"
  local do_clean_cmake="false"
  local skip_native="auto"
  local check_only="false"

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
      --check)
        check_only="true"
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

  if [[ "${check_only}" == "true" ]]; then
    local sdk_dir
    if ! sdk_dir="$(resolve_android_sdk)"; then
      report_sdk_not_found
      exit 1
    fi
    log "SDK: ${sdk_dir}"
    local gradlew
    gradlew="$(resolve_gradlew)"
    log "gradlew: ${gradlew}"
    # Mirror what build() would decide, so an explicit --skip-native does not
    # demand the native toolchain it was told not to use.
    local needs_native="true"
    if [[ "${skip_native}" == "true" ]]; then
      needs_native="false"
    fi
    preflight "${sdk_dir}" "${needs_native}" "${build_mode}"
    exit 0
  fi

  if [[ "${do_clean_cmake}" == "true" ]]; then
    clean_cmake_cache
    exit 0
  fi

  build "${build_mode}" "${force_clean}" "${skip_native}"
  log "Build completed successfully (${build_mode})"
}

main "$@"
