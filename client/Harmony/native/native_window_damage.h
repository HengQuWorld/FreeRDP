#ifndef FREERDP_HARMONY_NATIVE_WINDOW_DAMAGE_H
#define FREERDP_HARMONY_NATIVE_WINDOW_DAMAGE_H

#include <algorithm>
#include <cstdint>

namespace freerdp_harmony {

struct FrameRect {
  std::uint32_t left = 0;
  std::uint32_t top = 0;
  std::uint32_t width = 0;
  std::uint32_t height = 0;
};

// Clamps the dirty rect FreeRDP reports to the desktop that was actually copied
// into the native buffer.
//
// FreeRDP reports the union of the invalidated regions, which a resize can
// already have outgrown; an out-of-range rect makes the compositor skip the
// flush altogether. An empty rect would tell the compositor that nothing
// changed even though the whole buffer was just rewritten, so it falls back to
// the copied area instead.
inline FrameRect ComputeDamageRect(std::uint32_t left, std::uint32_t top,
                                   std::uint32_t dirtyWidth, std::uint32_t dirtyHeight,
                                   std::uint32_t desktopWidth, std::uint32_t desktopHeight,
                                   std::uint32_t copiedWidth, std::uint32_t copiedHeight) {
  FrameRect rect;
  if ((desktopWidth == 0) || (desktopHeight == 0)) {
    return rect;
  }

  const std::uint64_t originX = std::min<std::uint64_t>(left, desktopWidth);
  const std::uint64_t originY = std::min<std::uint64_t>(top, desktopHeight);
  const std::uint64_t endX =
      std::min<std::uint64_t>(desktopWidth, static_cast<std::uint64_t>(left) +
                                               std::min<std::uint64_t>(dirtyWidth, desktopWidth));
  const std::uint64_t endY =
      std::min<std::uint64_t>(desktopHeight, static_cast<std::uint64_t>(top) +
                                                 std::min<std::uint64_t>(dirtyHeight, desktopHeight));

  rect.left = static_cast<std::uint32_t>(originX);
  rect.top = static_cast<std::uint32_t>(originY);
  rect.width = static_cast<std::uint32_t>(endX > originX ? endX - originX : 0);
  rect.height = static_cast<std::uint32_t>(endY > originY ? endY - originY : 0);

  if ((rect.width == 0) || (rect.height == 0)) {
    rect.left = 0;
    rect.top = 0;
    rect.width = std::min(copiedWidth, desktopWidth);
    rect.height = std::min(copiedHeight, desktopHeight);
  }
  return rect;
}

}  // namespace freerdp_harmony

#endif  // FREERDP_HARMONY_NATIVE_WINDOW_DAMAGE_H
