include(ExternalProject)

get_filename_component(OHOS_COMPILER_BIN_DIR "${CMAKE_C_COMPILER}" DIRECTORY)
get_filename_component(OHOS_LLVM_DIR "${OHOS_COMPILER_BIN_DIR}" DIRECTORY)
get_filename_component(OHOS_NATIVE_DIR "${OHOS_LLVM_DIR}" DIRECTORY)
set(OHOS_TOOLCHAIN_FILE "${OHOS_NATIVE_DIR}/build/cmake/ohos.toolchain.cmake")

if(NOT EXISTS "${OHOS_TOOLCHAIN_FILE}")
  message(FATAL_ERROR "ExternalFreeRDP: ohos.toolchain.cmake not found at ${OHOS_TOOLCHAIN_FILE}")
endif()

# The persistent cache is keyed by architecture *and* build type. The two
# builds pass different configure options and produce different archives, so a
# directory shared between them let a debug package link a release core (or the
# other way round) while looking like it used the build the developer asked for.
string(TOLOWER "${CMAKE_BUILD_TYPE}" FREERDP_BUILD_TYPE_KEY)
if(FREERDP_BUILD_TYPE_KEY STREQUAL "")
  set(FREERDP_BUILD_TYPE_KEY "default")
endif()

set(FREERDP_PERSISTENT_CACHE_DIR
    "${CMAKE_CURRENT_LIST_DIR}/../../../cache/build/freerdp/${OHOS_ARCH}/${FREERDP_BUILD_TYPE_KEY}")
set(FREERDP_INSTALL_DIR "${FREERDP_PERSISTENT_CACHE_DIR}/install")

# ExternalProject keeps its stamps in the build tree, which survives when the
# persistent cache is deleted (by --clean, or by hand). Pin the prefix so the
# stamps can be found and discarded below.
set(FREERDP_EP_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/freerdp-prefix")
set(FREERDP_STAMP_DIR "${FREERDP_EP_PREFIX}/src/freerdp-stamp")

# With verbose assertions every WINPR_ASSERT becomes a logged, formatted check,
# and the core library announces the option in a WARN banner on the first
# context. That is worth having while debugging and is pure noise, plus a
# per-check cost, in a released build. Upstream defaults the option ON, so the
# Harmony build states it explicitly instead of inheriting it.
if(FREERDP_BUILD_TYPE_KEY STREQUAL "debug" OR FREERDP_BUILD_TYPE_KEY STREQUAL "relwithdebinfo")
  set(FREERDP_VERBOSE_WINPR_ASSERT ON)
else()
  set(FREERDP_VERBOSE_WINPR_ASSERT OFF)
endif()

set(FREERDP_CACHE_HIT OFF)
if(EXISTS "${FREERDP_INSTALL_DIR}/lib/libfreerdp3.a"
   AND EXISTS "${FREERDP_INSTALL_DIR}/lib/libwinpr3.a"
   AND EXISTS "${FREERDP_INSTALL_DIR}/include/winpr3/winpr/config.h")
  if(NOT "$ENV{FORCE_REBUILD_FREERDP}" STREQUAL "1")
    message(STATUS "ExternalFreeRDP: Cache hit at ${FREERDP_INSTALL_DIR}, skipping build")
    set(FREERDP_CACHE_HIT ON)
  endif()
endif()

if(NOT FREERDP_CACHE_HIT)
  # A stamp claiming 'built' and 'installed' is a lie once the install tree it
  # installed into is gone, and ninja trusts stamps over the filesystem. Drop
  # them so the steps below run again; the existing object files in the build
  # tree still make this an incremental rebuild.
  foreach(_freerdp_stamp freerdp-build freerdp-install freerdp-done)
    if(EXISTS "${FREERDP_STAMP_DIR}/${_freerdp_stamp}")
      message(STATUS "ExternalFreeRDP: discarding stale stamp ${_freerdp_stamp}")
      file(REMOVE "${FREERDP_STAMP_DIR}/${_freerdp_stamp}")
    endif()
  endforeach()

  message(STATUS "ExternalFreeRDP: Building FreeRDP from source for ${OHOS_ARCH} (${FREERDP_BUILD_TYPE_KEY}, verbose asserts ${FREERDP_VERBOSE_WINPR_ASSERT})")

  set(FREERDP_CMAKE_ARGS
      -DCMAKE_TOOLCHAIN_FILE:FILEPATH=${OHOS_TOOLCHAIN_FILE}
      -DOHOS_ARCH:STRING=${OHOS_ARCH}
      -DOHOS_STL:STRING=c++_shared
      -DCMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM}
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX:PATH=${FREERDP_INSTALL_DIR}
      -DCMAKE_INSTALL_LIBDIR:STRING=lib
      -DBUILD_SHARED_LIBS:BOOL=OFF
      -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON
      -DOPENSSL_ROOT_DIR:PATH=${OPENSSL_INSTALL_DIR}
      -DOPENSSL_INCLUDE_DIR:PATH=${OPENSSL_INSTALL_DIR}/include
      -DOPENSSL_SSL_LIBRARY:FILEPATH=${OPENSSL_INSTALL_DIR}/libssl.a
      -DOPENSSL_CRYPTO_LIBRARY:FILEPATH=${OPENSSL_INSTALL_DIR}/libcrypto.a
      -DWITH_OPENSSL:BOOL=ON
      -DWITH_CLIENT:BOOL=ON
      -DWITH_CLIENT_COMMON:BOOL=ON
      -DWITH_CLIENT_CHANNELS:BOOL=ON
      -DWITH_SERVER:BOOL=OFF
      -DWITH_SAMPLE:BOOL=OFF
      -DWITH_CLIENT_SDL:BOOL=OFF
      -DWITH_X11:BOOL=OFF
      -DWITH_WAYLAND:BOOL=OFF
      -DWITH_MANPAGES:BOOL=OFF
      -DWITH_PULSE:BOOL=OFF
      -DWITH_CUPS:BOOL=OFF
      -DWITH_FFMPEG:BOOL=OFF
      -DWITH_DSP_FFMPEG:BOOL=OFF
      -DWITH_VIDEO_FFMPEG:BOOL=OFF
      -DWITH_SWSCALE:BOOL=OFF
      -DWITH_KRB5:BOOL=OFF
      -DWITH_UNICODE_BUILTIN:BOOL=ON
      -DWITH_FUSE:BOOL=OFF
      -DCHANNEL_URBDRC:BOOL=OFF
      -DCHANNEL_URBDRC_CLIENT:BOOL=OFF
      -DBUILD_TESTING:BOOL=OFF
      -DWITH_INTERNAL_RC4:BOOL=ON
      -DWITH_INTERNAL_MD4:BOOL=ON
      -DWITH_INTERNAL_MD5:BOOL=ON
      -DWITH_VERBOSE_WINPR_ASSERT:BOOL=${FREERDP_VERBOSE_WINPR_ASSERT}
  )

  if(TARGET openssl)
    ExternalProject_Add(
      freerdp
      PREFIX ${FREERDP_EP_PREFIX}
      SOURCE_DIR ${FREERDP_SOURCE_DIR}
      CMAKE_COMMAND ${CMAKE_COMMAND}
      CMAKE_ARGS ${FREERDP_CMAKE_ARGS}
      DEPENDS openssl
      BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR>
      INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target install
      COMMAND ${CMAKE_COMMAND} -DFREERDP_LIB_DIR=${FREERDP_INSTALL_DIR}/lib -P ${CMAKE_CURRENT_LIST_DIR}/CollectArchives.cmake
      BUILD_BYPRODUCTS ${FREERDP_INSTALL_DIR}/lib/libfreerdp3.a ${FREERDP_INSTALL_DIR}/lib/libfreerdp-client3.a ${FREERDP_INSTALL_DIR}/lib/libwinpr3.a
    )
  else()
    ExternalProject_Add(
      freerdp
      PREFIX ${FREERDP_EP_PREFIX}
      SOURCE_DIR ${FREERDP_SOURCE_DIR}
      CMAKE_COMMAND ${CMAKE_COMMAND}
      CMAKE_ARGS ${FREERDP_CMAKE_ARGS}
      BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR>
      INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target install
      COMMAND ${CMAKE_COMMAND} -DFREERDP_LIB_DIR=${FREERDP_INSTALL_DIR}/lib -P ${CMAKE_CURRENT_LIST_DIR}/CollectArchives.cmake
      BUILD_BYPRODUCTS ${FREERDP_INSTALL_DIR}/lib/libfreerdp3.a ${FREERDP_INSTALL_DIR}/lib/libfreerdp-client3.a ${FREERDP_INSTALL_DIR}/lib/libwinpr3.a
    )
  endif()
endif()

file(MAKE_DIRECTORY ${FREERDP_INSTALL_DIR}/include/freerdp3)
file(MAKE_DIRECTORY ${FREERDP_INSTALL_DIR}/include/winpr3)
file(MAKE_DIRECTORY ${FREERDP_INSTALL_DIR}/lib)

set(FREERDP_ARCHIVES_RSP "${FREERDP_INSTALL_DIR}/lib/freerdp_archives.rsp")
file(GLOB_RECURSE FREERDP_ARCHIVES "${FREERDP_INSTALL_DIR}/lib/*.a")
if(FREERDP_ARCHIVES)
  string(REPLACE ";" "\n" FREERDP_ARCHIVES_LIST "${FREERDP_ARCHIVES}")
  file(WRITE ${FREERDP_ARCHIVES_RSP} "${FREERDP_ARCHIVES_LIST}\n")
else()
  file(WRITE ${FREERDP_ARCHIVES_RSP}
       "${FREERDP_INSTALL_DIR}/lib/libfreerdp3.a
${FREERDP_INSTALL_DIR}/lib/libfreerdp-client3.a
${FREERDP_INSTALL_DIR}/lib/libwinpr3.a
"
  )
endif()
