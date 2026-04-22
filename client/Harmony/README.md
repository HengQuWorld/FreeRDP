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

## Desktop Preview

- For immediate one-host-per-window desktop access, use the existing SDL3 client:

```bash
./client/Harmony/tools/open-sdl-window.sh 192.168.3.154 gaord 'Passw0rd~!@'
```

- This launches a dedicated remote desktop window with clipboard and dynamic resolution enabled.
- The same FreeRDP core is reused by the Harmony native bridge, so this is the fastest way to
  verify connectivity, rendering and keyboard/mouse behavior before wiring ArkTS to N-API.
