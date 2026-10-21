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

// Every layout that reaches the server costs the user a visible rebuild: the
// Windows shell re-lays out the taskbar and replays its icon animation. The
// view asks again on a retry timer whenever the desktop has not reported the
// requested size yet, so every retry inside the server's apply latency used to
// re-tear the desktop down. Measured against the real server: a requested
// layout took 3.7 s to be applied. The window therefore has to outlast the
// apply latency, not merely one layout tick.
constexpr std::int64_t kDuplicateResizeWindowMs = 4000;

class DesktopResizeGate {
 public:
  // True when this request should go on the wire now. A size equal to the last
  // one sent is suppressed inside kDuplicateResizeWindowMs; a different size
  // always passes, because the user has moved the window again.
  bool ShouldSend(const DesktopSize& target, std::int64_t nowMs) {
    if (sent_ && (target.width == lastSent_.width) && (target.height == lastSent_.height) &&
        (nowMs >= lastSentMs_) && ((nowMs - lastSentMs_) < kDuplicateResizeWindowMs)) {
      return false;
    }
    lastSent_ = target;
    lastSentMs_ = nowMs;
    sent_ = true;
    return true;
  }

  // A layout sent before a disconnect must not suppress the same layout on the
  // next session, which has its own desktop stack.
  void Reset() {
    lastSent_ = DesktopSize{};
    lastSentMs_ = -1;
    sent_ = false;
  }

 private:
  DesktopSize lastSent_;
  std::int64_t lastSentMs_ = -1;
  bool sent_ = false;
};

// DISPLAY_CONTROL_MONITOR_LAYOUT carries the monitor size in millimetres.
// Sending pixels there told the server that a 3254 px wide panel is 3.25 m
// wide, which skews the DPI heuristics Windows uses to pick a text scale.
inline std::uint32_t PhysicalSizeMm(std::uint32_t pixels, std::uint32_t dpi) {
  if ((pixels == 0) || (dpi == 0)) {
    return 0;
  }
  const std::uint64_t millimetres =
      (static_cast<std::uint64_t>(pixels) * 254U) / (static_cast<std::uint64_t>(dpi) * 10U);
  if (millimetres == 0) {
    return 1;
  }
  return static_cast<std::uint32_t>(millimetres);
}

// The percentage the server scales the remote desktop by. The view reports its
// px-per-vp ratio, and the resulting logical desktop then matches the viewport
// in vp: a 180% factor on a 3254 px wide desktop yields the 1808 vp the user
// actually sees, instead of a desktop drawn at 100% and shrunk to fit.
inline std::uint32_t DesktopScaleFactorFromPercent(std::uint32_t deviceScalePercent) {
  if (deviceScalePercent == 0) {
    return 100;
  }
  return deviceScalePercent > 500 ? 500 : deviceScalePercent;
}

// A frame produced before a desktop resize still reports the old desktop size.
// The native buffer geometry follows the frame that is being presented, so such
// a frame pins the geometry back to the old size a few milliseconds after the
// resize set the new one - the compositor then shows one stretched, misaligned
// frame before the next one corrects it. Frames that disagree with the size the
// server just announced are dropped while that size is still fresh; after the
// window the frame is trusted again, so a resize that never announced itself
// cannot freeze the picture.
constexpr std::int64_t kDesktopSizeSettleMs = 1000;

inline bool IsStaleFrameSize(std::uint32_t frameWidth, std::uint32_t frameHeight,
                             std::uint32_t desktopWidth, std::uint32_t desktopHeight,
                             std::int64_t sinceSizeUpdateMs) {
  if ((desktopWidth == 0) || (desktopHeight == 0)) {
    return false;  // nothing authoritative to disagree with
  }
  if ((frameWidth == desktopWidth) && (frameHeight == desktopHeight)) {
    return false;
  }
  if ((sinceSizeUpdateMs < 0) || (sinceSizeUpdateMs >= kDesktopSizeSettleMs)) {
    return false;  // the announcement is old: trust the frame
  }
  return true;
}

}  // namespace freerdp_harmony

#endif  // FREERDP_HARMONY_DESKTOP_RESIZE_H
