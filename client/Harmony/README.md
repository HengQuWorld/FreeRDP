# FreeRDP Harmony Client

A HarmonyOS 6 client shell for FreeRDP.

## Goals

- Reuse `libfreerdp`, `winpr` and `client/common` as much as possible.
- Keep the HarmonyOS shell thin, clear and user friendly.
- Isolate native bridge code so protocol updates do not leak into ArkTS pages.

## Structure

- `entry`: HarmonyOS Stage model shell, pages and view models.
- `native`: N-API and FreeRDP adapter skeleton.

## Current Status

- ArkTS shell, bookmark model, quick connect form and session page are scaffolded.
- Native bridge contract is defined in ArkTS and mirrored by C++ stubs.
- The native layer now contains a real FreeRDP session object with connect, disconnect,
  GDI initialization and dirty-rectangle tracking.
- The native layer now also exposes framebuffer and keyboard/mouse injection methods for the
  next N-API step.
- The native session now reuses `client/common` command-line parsing and addin/channel loading
  through `freerdp_client_settings_parse_command_line()` and `freerdp_client_load_channels()`.
- The repository CMake tree can include the Harmony native target with
  `-DWITH_CLIENT_HARMONY=ON`.
- ArkTS now loads the real Harmony N-API module, renders the native BGRA framebuffer into
  a Harmony `PixelMap`, and routes touch/mouse/basic keyboard input back into FreeRDP.
- The workspace shell supports host bookmarks, multiple session tabs, active session polling and a
  professional split-pane layout.

OpenSSL is downloaded and cross-compiled automatically by CMake (via `ExternalProject`)
during the native build step — no manual steps are required.

### Build the App

```bash
# Debug build
client/Harmony/scripts/build.sh debug

# Release build
client/Harmony/scripts/build.sh release
```

Or open `client/Harmony` in DevEco Studio and build from the IDE.

### Desktop Preview

For quick connectivity testing, use the existing SDL3 client:

```bash
tools/open-sdl-window.sh <host> <username> <password>
```

## License

This client is part of FreeRDP and licensed under the Apache License 2.0.
See the root `LICENSE` file for details.

This product includes software developed by the OpenSSL Project for use
in the OpenSSL Toolkit (https://www.openssl.org/). See
`native/third_party/NOTICE` for the full OpenSSL and SSLeay license texts.
