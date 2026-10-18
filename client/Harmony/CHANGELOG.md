# Changelog

Notable user-facing changes in the HarmonyOS client.
App releases use the `1.x` tags; upstream FreeRDP `3.x` tags are unrelated.

## 1.2.1 — 2026-10-18

### Added

- **Rate the app without leaving it.** After three successful connections, the app invites you to rate it in AppGallery. Choose “Maybe later” or “Don’t ask again”; the prompt stays away for 30 days. A rating entry is also available in Settings.

### Improved

- **Closing a session is immediate.** Closing the window or disconnecting responds right away instead of freezing the interface, and memory is released as soon as the session ends.
- **More dependable during long use.** Fixed a crash that could occur when closing a window while a connection was still starting.

## 1.2.0 — 2026-09-08

### Added

- Local folder redirection (drive redirection), so remote desktops can use folders from the device.

### Improved

- Tablets no longer show the soft keyboard automatically when a field receives focus.
- Updated to HarmonyOS 6.0.0 (API 20) for current devices and AppGallery requirements.
