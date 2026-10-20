#ifndef FREERDP_HARMONY_NATIVE_WINDOW_GEOMETRY_H
#define FREERDP_HARMONY_NATIVE_WINDOW_GEOMETRY_H

#include <cstdint>

namespace freerdp_harmony {

// A buffer dequeued from the native window right after SET_BUFFER_GEOMETRY can
// still carry the previous size: the compositor hands out the buffers it
// already queued before the change took effect. Re-applying the geometry frees
// that queue, but doing it on every frame turns one resize into a burst of
// abort/re-apply pairs and a matching burst of log lines. Measured on the
// emulator: 13 geometry re-applications in 682 ms while a resize settled.
constexpr std::int64_t kGeometryReapplyCooldownMs = 200;

// True when a mismatched buffer may be aborted and the geometry re-applied.
// Frames that arrive inside the cooldown are dropped instead; at ~60 fps that
// costs a few frames during a resize, which is not observable, while the
// recovery still happens as soon as the queue has been recycled.
inline bool CanReapplyNativeGeometry(std::int64_t nowMs, std::int64_t lastReapplyMs) {
  if (lastReapplyMs < 0) {
    return true;
  }
  if (nowMs < lastReapplyMs) {
    // A clock that moved backwards must not stall presentation forever.
    return true;
  }
  return (nowMs - lastReapplyMs) >= kGeometryReapplyCooldownMs;
}

}  // namespace freerdp_harmony

#endif  // FREERDP_HARMONY_NATIVE_WINDOW_GEOMETRY_H
