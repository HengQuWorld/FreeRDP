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
  return (std::strcmp(text, "freerdp_post_connect failed") == 0) ||
         (std::strstr(text, "TODO: Trying to set error code") != nullptr);
}

}  // namespace freerdp_harmony

#endif  // FREERDP_HARMONY_CANCELLATION_NOISE_H
