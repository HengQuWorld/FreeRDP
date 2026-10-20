#include "native_window_geometry.h"

#include <cstdint>
#include <iostream>

namespace {

int failures = 0;

void Expect(const char* label, std::int64_t nowMs, std::int64_t lastReapplyMs, bool expected) {
  const bool actual = freerdp_harmony::CanReapplyNativeGeometry(nowMs, lastReapplyMs);
  if (actual == expected) {
    std::cout << "OK   [" << label << "]: " << (actual ? "reapply" : "hold") << "\n";
    return;
  }
  std::cout << "FAIL [" << label << "]: expected " << (expected ? "reapply" : "hold")
            << ", got " << (actual ? "reapply" : "hold") << "\n";
  ++failures;
}

}  // namespace

int main() {
  // Nothing has been re-applied yet, so the first mismatch is always served.
  Expect("first", 1000, -1, true);

  // The burst this pacing exists for: consecutive frames must not each reset
  // the geometry.
  Expect("next frame", 1016, 1000, false);
  Expect("same millisecond", 1000, 1000, false);
  Expect("just inside cooldown", 1199, 1000, false);

  // Once the cooldown has passed the retry is allowed again, so a mismatch
  // that outlives the queue still recovers.
  Expect("cooldown reached", 1200, 1000, true);
  Expect("long after", 5000, 1000, true);

  // A clock that went backwards must not block presentation forever.
  Expect("clock backwards", 900, 1000, true);

  if (failures != 0) {
    std::cout << failures << " geometry pacing check(s) failed\n";
    return 1;
  }
  std::cout << "all geometry pacing checks passed\n";
  return 0;
}
