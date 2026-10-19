#ifndef FREERDP_HARMONY_DESKTOP_RESIZE_H
#define FREERDP_HARMONY_DESKTOP_RESIZE_H

#include <cstdint>

namespace freerdp_harmony {

struct DesktopSize {
  std::uint32_t width = 0;
  std::uint32_t height = 0;
};

// Holds the desktop size the view asked for until the display control channel
// can carry it.
//
// The channel may be connected but not yet have announced its capabilities, and
// the server may still be laying the session out, so a request that arrives
// early has to wait instead of being dropped. Several requests collapse into
// the most recent one, a request that matches the current desktop is consumed
// without traffic, and a consumed request is never sent twice by itself: the
// view asks again when the size it wants changes.
class DesktopResizeQueue {
 public:
  // Zero is not a protocol-legal desktop size; the view uses it for "no
  // request". Returns false, leaving any earlier request untouched.
  bool Request(std::uint32_t width, std::uint32_t height) {
    if ((width == 0) || (height == 0)) {
      return false;
    }
    requested_.width = width;
    requested_.height = height;
    pending_ = true;
    return true;
  }

  // Consumes the pending request once the channel can send it, and reports
  // whether it has to be sent: not when the desktop already has that size,
  // because asking again would only make the server re-lay out the session.
  // A request that is not ready stays pending for the next attempt.
  bool TakeReady(bool channelReady, const DesktopSize& desktop, DesktopSize* layout) {
    if (!pending_ || !channelReady || (layout == nullptr)) {
      return false;
    }
    pending_ = false;
    if ((desktop.width == requested_.width) && (desktop.height == requested_.height)) {
      return false;
    }
    *layout = requested_;
    return true;
  }

  bool HasPending() const {
    return pending_;
  }

 private:
  DesktopSize requested_;
  bool pending_ = false;
};

// The UI sizes its surface from the desktop dimensions, so it only redraws to
// the new geometry when it is told the size changed. UpdateSnapshot may already
// have moved the snapshot to the new size before the first frame arrives, so
// the comparison has to be against what the UI was told last.
inline bool ShouldPublishDesktopSize(const DesktopSize& published, const DesktopSize& frame) {
  return (published.width != frame.width) || (published.height != frame.height);
}

}  // namespace freerdp_harmony

#endif  // FREERDP_HARMONY_DESKTOP_RESIZE_H
