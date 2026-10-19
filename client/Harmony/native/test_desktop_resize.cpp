#include "desktop_resize.h"

#include <cstdint>
#include <iostream>

namespace {

int failures = 0;

using freerdp_harmony::DesktopResizeQueue;
using freerdp_harmony::DesktopSize;

void Expect(bool condition, const char* label) {
  if (condition) {
    std::cout << "OK   [" << label << "]\n";
    return;
  }
  std::cout << "FAIL [" << label << "]\n";
  ++failures;
}

void ExpectLayout(const DesktopSize& layout, std::uint32_t width, std::uint32_t height,
                  const char* label) {
  if ((layout.width == width) && (layout.height == height)) {
    std::cout << "OK   [" << label << "]: " << layout.width << "x" << layout.height << "\n";
    return;
  }
  std::cout << "FAIL [" << label << "]: expected " << width << "x" << height << ", got "
            << layout.width << "x" << layout.height << "\n";
  ++failures;
}

}  // namespace

int main() {
  const DesktopSize desktop1920{ 1920, 1080 };

  // The view uses zero for "no request"; that is not a legal desktop size and
  // must not replace a request that is already waiting.
  {
    DesktopResizeQueue queue;
    Expect(!queue.Request(0, 1080), "zero request rejected");
    Expect(!queue.HasPending(), "zero request leaves nothing pending");
    Expect(queue.Request(1000, 600), "valid request accepted");
    Expect(!queue.Request(0, 0), "second zero request rejected");
    DesktopSize layout;
    Expect(queue.TakeReady(true, desktop1920, &layout), "earlier request survives a zero one");
    ExpectLayout(layout, 1000, 600, "earlier request survives a zero one");
  }

  // A layout requested before the display control caps arrived has to wait for
  // the channel instead of being dropped.
  {
    DesktopResizeQueue queue;
    queue.Request(1000, 600);
    DesktopSize layout;
    Expect(!queue.TakeReady(false, desktop1920, &layout), "not ready yet");
    Expect(queue.HasPending(), "request stays pending until the channel is ready");
    Expect(queue.TakeReady(true, desktop1920, &layout), "sent once the channel is ready");
    ExpectLayout(layout, 1000, 600, "sent once the channel is ready");
    Expect(!queue.HasPending(), "consumed after sending");
    Expect(!queue.TakeReady(true, desktop1920, &layout), "not sent twice");
  }

  // Dragging a window produces a stream of sizes; only the latest one matters.
  {
    DesktopResizeQueue queue;
    queue.Request(1000, 600);
    queue.Request(1200, 800);
    queue.Request(1280, 720);
    DesktopSize layout;
    Expect(queue.TakeReady(true, desktop1920, &layout), "coalesced request sent");
    ExpectLayout(layout, 1280, 720, "coalesced request keeps the latest size");
  }

  // The server may already have applied the size the view is asking for (its
  // retry can race with the frame). Re-sending would only re-lay out the
  // session, so the request is consumed silently.
  {
    DesktopResizeQueue queue;
    queue.Request(1280, 720);
    DesktopSize layout;
    Expect(!queue.TakeReady(true, DesktopSize{ 1280, 720 }, &layout), "matching size not sent");
    Expect(!queue.HasPending(), "matching size consumed silently");
  }

  // A server that refuses a layout does not make the queue spin, but a new
  // viewport size asks again.
  {
    DesktopResizeQueue queue;
    queue.Request(1000, 600);
    DesktopSize layout;
    Expect(queue.TakeReady(true, desktop1920, &layout), "first attempt sent");
    queue.Request(1400, 900);
    Expect(queue.TakeReady(true, desktop1920, &layout), "new request asks again");
    ExpectLayout(layout, 1400, 900, "new request asks again");
  }

  // The UI only redraws to new geometry when it is told the size changed, and
  // UpdateSnapshot may have moved the snapshot before the frame arrives. The
  // comparison is against what the UI was told last, never the snapshot.
  {
    Expect(freerdp_harmony::ShouldPublishDesktopSize(DesktopSize{ 0, 0 }, desktop1920),
           "first frame publishes the size");
    Expect(!freerdp_harmony::ShouldPublishDesktopSize(desktop1920, desktop1920),
           "unchanged size is not republished");
    // A server resize already moved the snapshot to 1280x720; the UI still
    // shows the 1920x1080 it was told about, so this frame must be published.
    Expect(freerdp_harmony::ShouldPublishDesktopSize(desktop1920, DesktopSize{ 1280, 720 }),
           "server resize publishes the new geometry");
    Expect(!freerdp_harmony::ShouldPublishDesktopSize(DesktopSize{ 1280, 720 },
                                                      DesktopSize{ 1280, 720 }),
           "no second event for the settled geometry");
  }

  std::cout << "\n" << (failures == 0 ? "ALL PASSED" : "SOME FAILED") << ": " << failures
            << " failures\n";
  return failures;
}
