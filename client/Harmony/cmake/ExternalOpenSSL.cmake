include(ExternalProject)

set(OPENSSL_VERSION "openssl-3.6.1")
set(OPENSSL_URL_HASH "SHA256=b1bfedcd5b289ff22aee87c9d600f515767ebf45f77168cb6d64f231f518a82e")
set(OPENSSL_URL "https://github.com/openssl/openssl/releases/download/${OPENSSL_VERSION}/${OPENSSL_VERSION}.tar.gz")

set(OPENSSL_CACHE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../cache")
if(EXISTS "${OPENSSL_CACHE_DIR}/${OPENSSL_VERSION}.tar.gz")
  set(OPENSSL_URL "file://${OPENSSL_CACHE_DIR}/${OPENSSL_VERSION}.tar.gz")
endif()

if(OHOS_ARCH STREQUAL "arm64-v8a")
  set(OSSL_ARCH "ohos-aarch64")
  set(OSSL_TARGET "aarch64-linux-ohos")
elseif(OHOS_ARCH STREQUAL "armeabi-v7a")
  set(OSSL_ARCH "ohos-arm")
  set(OSSL_TARGET "armv7a-linux-ohos")
  set(OSSL_CFLAGS_EXTRA "-D__ARM_MAX_ARCH__=8")
elseif(OHOS_ARCH STREQUAL "x86_64")
  set(OSSL_ARCH "ohos-x86_64")
  set(OSSL_TARGET "x86_64-linux-ohos")
else()
  message(FATAL_ERROR "ExternalOpenSSL: unsupported OHOS_ARCH '${OHOS_ARCH}'")
endif()

set(PREBUILT_OPENSSL_DIR "${CMAKE_CURRENT_LIST_DIR}/../native/third_party/openssl-prebuilt/${OHOS_ARCH}")

set(USE_PREBUILT_OPENSSL OFF)
if(EXISTS "${PREBUILT_OPENSSL_DIR}/libssl.a" AND EXISTS "${PREBUILT_OPENSSL_DIR}/libcrypto.a")
  if("$ENV{USE_PREBUILT_OPENSSL}" STREQUAL "1")
    set(USE_PREBUILT_OPENSSL ON)
    set(OPENSSL_INSTALL_DIR "${PREBUILT_OPENSSL_DIR}")
    message(STATUS "ExternalOpenSSL: Using prebuilt OpenSSL from ${PREBUILT_OPENSSL_DIR}")
  endif()
endif()

if(NOT USE_PREBUILT_OPENSSL)
  set(OPENSSL_PERSISTENT_CACHE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../cache/build/openssl/${OHOS_ARCH}")
  set(OPENSSL_INSTALL_DIR "${OPENSSL_PERSISTENT_CACHE_DIR}/install")

  if(EXISTS "${OPENSSL_INSTALL_DIR}/libssl.a" AND EXISTS "${OPENSSL_INSTALL_DIR}/libcrypto.a")
    if(NOT "$ENV{FORCE_REBUILD_OPENSSL}" STREQUAL "1")
      message(STATUS "ExternalOpenSSL: Cache hit at ${OPENSSL_INSTALL_DIR}, skipping build")
      set(OPENSSL_CACHE_HIT ON)
    endif()
  endif()

  if(NOT OPENSSL_CACHE_HIT)
    message(STATUS "ExternalOpenSSL: Building OpenSSL from source for ${OHOS_ARCH}")

    get_filename_component(OHOS_TOOLCHAIN_BIN "${CMAKE_C_COMPILER}" DIRECTORY)
    get_filename_component(OHOS_LLVM_DIR "${OHOS_TOOLCHAIN_BIN}" DIRECTORY)
    get_filename_component(OHOS_NATIVE_DIR "${OHOS_LLVM_DIR}" DIRECTORY)
    get_filename_component(OHOS_NDK_HOME "${OHOS_NATIVE_DIR}" DIRECTORY)

    set(OHOS_SYSROOT "${OHOS_NDK_HOME}/native/sysroot")
    set(OSSL_CFLAGS "-target ${OSSL_TARGET} --sysroot=${OHOS_SYSROOT} -D__MUSL__ ${OSSL_CFLAGS_EXTRA}")

    set(HARMONY_OPENSSL_PATCH "${CMAKE_CURRENT_LIST_DIR}/../../../scripts/harmony-openssl.patch")

    set(OSSL_ENV
        "PATH=${OHOS_TOOLCHAIN_BIN}:$ENV{PATH}"
        "CC=${OHOS_TOOLCHAIN_BIN}/clang"
        "CXX=${OHOS_TOOLCHAIN_BIN}/clang++"
        "AR=${OHOS_TOOLCHAIN_BIN}/llvm-ar"
        "LD=${OHOS_TOOLCHAIN_BIN}/ld.lld"
        "STRIP=${OHOS_TOOLCHAIN_BIN}/llvm-strip"
        "RANLIB=${OHOS_TOOLCHAIN_BIN}/llvm-ranlib"
        "NM=${OHOS_TOOLCHAIN_BIN}/llvm-nm"
        "CFLAGS=${OSSL_CFLAGS}"
        "CXXFLAGS=${OSSL_CFLAGS}"
    )

    ExternalProject_Add(
      openssl
      SOURCE_DIR ${CMAKE_BINARY_DIR}/openssl-src
      URL ${OPENSSL_URL}
      URL_HASH ${OPENSSL_URL_HASH}
      PATCH_COMMAND patch -p1 -s < ${HARMONY_OPENSSL_PATCH}
      CONFIGURE_COMMAND
        ${CMAKE_COMMAND} -E env ${OSSL_ENV} perl <SOURCE_DIR>/Configure ${OSSL_ARCH} no-shared no-module no-tests no-apps
        no-docs no-legacy no-dso no-ssl-trace --prefix=${OPENSSL_INSTALL_DIR} --libdir=${OPENSSL_INSTALL_DIR}
        --openssldir=${OPENSSL_INSTALL_DIR}
      BUILD_COMMAND ${CMAKE_COMMAND} -E env ${OSSL_ENV} make build_libs -j
      INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${OPENSSL_INSTALL_DIR}/include/openssl
      COMMAND ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR>/include/openssl ${OPENSSL_INSTALL_DIR}/include/openssl
      COMMAND ${CMAKE_COMMAND} -E copy_directory <BINARY_DIR>/include/openssl ${OPENSSL_INSTALL_DIR}/include/openssl
      COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libssl.a ${OPENSSL_INSTALL_DIR}/libssl.a
      COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libcrypto.a ${OPENSSL_INSTALL_DIR}/libcrypto.a
      BUILD_BYPRODUCTS ${OPENSSL_INSTALL_DIR}/libssl.a ${OPENSSL_INSTALL_DIR}/libcrypto.a
    )
  endif()
endif()

add_library(openssl-lib INTERFACE IMPORTED GLOBAL)
set_target_properties(
  openssl-lib PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INSTALL_DIR}/include"
                         INTERFACE_LINK_LIBRARIES "${OPENSSL_INSTALL_DIR}/libssl.a;${OPENSSL_INSTALL_DIR}/libcrypto.a"
)

if(TARGET openssl)
  add_dependencies(openssl-lib openssl)
endif()

file(MAKE_DIRECTORY ${OPENSSL_INSTALL_DIR}/include)
