#include "cancellation_noise.h"

#include <iostream>

namespace {

int failures = 0;

void Expect(const char* text, bool stopRequested, bool expected, const char* label) {
  const bool actual = freerdp_harmony::IsCancellationNoise(text, stopRequested);
  std::cout << (actual == expected ? "OK   [" : "FAIL [") << label
            << "] stopRequested=" << (stopRequested ? "true" : "false") << " text=\""
            << (text != nullptr ? text : "(null)") << "\" -> "
            << (actual ? "downgrade" : "keep level") << "\n";
  if (actual != expected) {
    ++failures;
  }
}

}  // namespace

int main() {
  const char* kCancelMarker = "ERRCONNECT_CONNECT_CANCELLED [0x0002000B]";

  // A user-requested abort: both the cancel marker and the unwind that follows
  // it are routine, whichever thread they are logged from. The marker is logged
  // from the thread asking to abort, where the session's own flag may not be
  // visible yet, so it must not depend on it.
  Expect(kCancelMarker, false, true, "cancel marker");
  Expect(kCancelMarker, true, true, "cancel marker, stopping");
  Expect("freerdp_post_connect failed", true, true, "post connect after cancel");
  Expect("TODO: Trying to set error code FREERDP_ERROR_POST_CONNECT_FAILED, but "
         "FREERDP_ERROR_CONNECT_CANCELLED already set!",
         true, true, "error override after cancel");

  // The same messages during a real failure must keep their level, otherwise a
  // genuine defect would be hidden by the next cancellation.
  Expect("freerdp_post_connect failed", false, false, "post connect failure");
  Expect("TODO: Trying to set error code FREERDP_ERROR_POST_CONNECT_FAILED, but "
         "FREERDP_ERROR_CONNECT_FAILED already set!",
         false, false, "error override during failure");

  // Aborting a connect that is still in flight closes the socket under it, so
  // the transport reports the very failure the abort caused. Seen on a
  // cancelled connect to an unreachable host, right after the cancel.
  Expect("Couldn't get socket ip address", true, true, "aborted socket");
  Expect("Failed to connect", true, true, "aborted nego connect");

  // The same two during a real failure must keep their level, otherwise a
  // genuine network error would be hidden.
  Expect("Couldn't get socket ip address", false, false, "socket failure, no cancel");
  Expect("Failed to connect", false, false, "nego failure, no cancel");

  // Everything else keeps its severity even while the user is disconnecting.
  Expect("TLS handshake failed: certificate verify failed", true, false, "unrelated error");
  Expect("freerdp_connect failed", true, false, "unrelated connect error");
  Expect("ERRCONNECT_AUTHENTICATION_FAILED [0x00020009]", true, false, "auth failure");
  Expect("Failed to connect with TLS security", true, false, "nego debug variant");
  Expect(nullptr, true, false, "null text");

  std::cout << "\n" << (failures == 0 ? "ALL PASSED" : "SOME FAILED") << ": " << failures
            << " failures\n";
  return failures == 0 ? 0 : 1;
}
