#ifndef FREERDP_HARMONY_CANCELLATION_NOISE_H
#define FREERDP_HARMONY_CANCELLATION_NOISE_H

#include <cstring>

// libfreerdp reports a user-requested abort with the same ERROR severity it
// uses for real faults. Those lines reach hilog and, through it, AppGallery
// Connect's failure statistics, so a routine window close must not look like a
// defect. This is the whole policy for telling the two apart, kept out of the
// log bridge so it can be tested.

namespace freerdp_harmony {

inline bool IsCancellationNoise(const char* text, bool stopRequested) {
  if (text == nullptr) {
    return false;
  }

  // Self-identifying: this error code is only ever produced by a cancellation,
  // and it is logged from the thread asking to abort, not from the session
  // thread, so `stopRequested` may not be visible here.
  if (std::strstr(text, "ERRCONNECT_CONNECT_CANCELLED") != nullptr) {
    return true;
  }

  // Shared with genuine failures: it takes the session's own verdict.
  if (!stopRequested) {
    return false;
  }
  // Messages that only ever appear as a consequence of an abort. The abort
  // closes the socket underneath a connect that is still in flight, so the
  // transport reports the very failure the abort caused. Observed on a
  // cancelled connect to an unreachable host: after the cancel was registered,
  // tcp.c logged "Couldn't get socket ip address" and nego.c logged "Failed to
  // connect". Both are exact strings; nego.c's DEBUG variant appends the
  // security protocol, so it does not match here.
  if ((std::strcmp(text, "Failed to connect") == 0) ||
      (std::strcmp(text, "Couldn't get socket ip address") == 0)) {
    return true;
  }

  return (std::strcmp(text, "freerdp_post_connect failed") == 0) ||
         (std::strstr(text, "TODO: Trying to set error code") != nullptr);
}

}  // namespace freerdp_harmony

#endif  // FREERDP_HARMONY_CANCELLATION_NOISE_H
