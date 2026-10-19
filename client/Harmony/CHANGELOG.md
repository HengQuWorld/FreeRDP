Changelog

Notable user-facing changes in the HarmonyOS client.
App releases use the 1.x tags; upstream FreeRDP 3.x tags are unrelated.

Version 1.2.2 (2026-10-19)

Added
  The desktop uses the whole screen. A new “Auto fit” resolution, the default for new connections, re-lays the desktop out for the window as you resize it or go full screen, instead of shrinking it into the middle with empty bands above and below. Fixed resolutions keep working as before.

Improved
  Lighter frame handling. Frames are drawn straight into the window instead of being copied whole on every redraw, and a still desktop is no longer refreshed over and over, so long sessions use less power and low-end devices keep up better.
  Connections open smoothly. Setting up a connection no longer runs on the thread that draws, so the interface stays responsive while a session opens.
  A leaner download. Release builds no longer carry the runtime checks that only debugging needs.

Fixed
  Passwords stay out of logs. The server password never touches the command line, and log lines and error messages mask it, so an uploaded log cannot reveal it.
  Cancelling is not a failure. A connection you cancel is logged as ordinary information without error lines, so a report that says “failed” means something really failed.
  Closing updates immediately. A closing session no longer reports that it does not exist, and closing it twice does not disconnect again.

Version 1.2.1 (2026-10-18)

Added
  Rate the app without leaving it. After three successful connections, the app invites you to rate it in AppGallery. Choose “Maybe later” or “Don’t ask again”; the prompt stays away for 30 days. A rating entry is also available in Settings.

Improved
  Closing a session is immediate. Closing the window or disconnecting responds right away instead of freezing the interface, and memory is released as soon as the session ends.
  More dependable during long use. Fixed a crash that could occur when closing a window while a connection was still starting.

Version 1.2.0 (2026-09-08)

Added
  Local folder redirection (drive redirection), so remote desktops can use folders from the device.

Improved
  Tablets no longer show the soft keyboard automatically when a field receives focus.
  Updated to HarmonyOS 6.0.0 (API 20) for current devices and AppGallery requirements.
