#include "native_window_damage.h"

#include <cstdint>
#include <iostream>

namespace {

int failures = 0;

void ExpectRect(const char* label, std::uint32_t left, std::uint32_t top,
                std::uint32_t dirtyWidth, std::uint32_t dirtyHeight,
                std::uint32_t desktopWidth, std::uint32_t desktopHeight,
                std::uint32_t copiedWidth, std::uint32_t copiedHeight,
                std::uint32_t expectedLeft, std::uint32_t expectedTop,
                std::uint32_t expectedWidth, std::uint32_t expectedHeight) {
  const freerdp_harmony::FrameRect rect = freerdp_harmony::ComputeDamageRect(
      left, top, dirtyWidth, dirtyHeight, desktopWidth, desktopHeight, copiedWidth,
      copiedHeight);
  if ((rect.left == expectedLeft) && (rect.top == expectedTop) &&
      (rect.width == expectedWidth) && (rect.height == expectedHeight)) {
    std::cout << "OK   [" << label << "]: " << rect.left << "," << rect.top << " "
              << rect.width << "x" << rect.height << "\n";
    return;
  }
  std::cout << "FAIL [" << label << "]: expected " << expectedLeft << "," << expectedTop << " "
            << expectedWidth << "x" << expectedHeight << ", got " << rect.left << ","
            << rect.top << " " << rect.width << "x" << rect.height << "\n";
  ++failures;
}

}  // namespace

int main() {
  // A dirty rect inside the desktop is passed through untouched.
  ExpectRect("interior", 10, 20, 100, 50, 1920, 1080, 1920, 1080, 10, 20, 100, 50);

  // The union can extend past the desktop after a resize; clamp to the edge.
  ExpectRect("oversize", 1900, 1000, 400, 400, 1920, 1080, 1920, 1080, 1900, 1000, 20, 80);

  // A rect that starts outside the desktop leaves nothing to recompose, so the
  // whole copied area is reported instead of an empty region.
  ExpectRect("fully offscreen", 2000, 10, 100, 100, 1920, 1080, 1920, 1080, 0, 0, 1920, 1080);

  // Zero-size dirty rect: the buffer was rewritten, so never report "no damage".
  ExpectRect("empty dirty", 0, 0, 0, 0, 800, 600, 800, 600, 0, 0, 800, 600);

  // The copy is clamped to the buffer, so the fallback must not exceed it.
  ExpectRect("clipped copy", 0, 0, 0, 0, 1920, 1080, 1024, 768, 0, 0, 1024, 768);

  // No desktop yet: nothing can be reported.
  ExpectRect("zero desktop", 0, 0, 100, 100, 0, 0, 1024, 768, 0, 0, 0, 0);

  // left + dirtyWidth would wrap in 32-bit arithmetic; it must not go negative.
  ExpectRect("overflow", 0xFFFFFFF0U, 0, 0xFFFFU, 0xFFFFU, 1920, 1080, 1920, 1080, 0, 0, 1920,
             1080);

  if (failures != 0) {
    std::cout << failures << " failure(s)\n";
    return 1;
  }
  std::cout << "all damage-rect cases passed\n";
  return 0;
}
