#ifndef FREERDP_HARMONY_SESSION_H
#define FREERDP_HARMONY_SESSION_H

#include <condition_variable>
#include <atomic>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "desktop_resize.h"
#include "freerdp_adapter.h"

struct NativeWindow;

class FreeRDPHarmonySession {
 public:
  explicit FreeRDPHarmonySession(HarmonySessionConfig config);
  ~FreeRDPHarmonySession();
  FreeRDPHarmonySession(const FreeRDPHarmonySession&) = delete;
  FreeRDPHarmonySession& operator=(const FreeRDPHarmonySession&) = delete;
  FreeRDPHarmonySession(FreeRDPHarmonySession&&) = delete;
  FreeRDPHarmonySession& operator=(FreeRDPHarmonySession&&) = delete;

  bool Connect();
  bool Disconnect();

  // True once Disconnect() asked this session to stop. The log bridge uses it
  // to tell a user cancellation apart from a real connection failure.
  bool IsStopRequested() const;

  // True once the user closed the credential prompt. The connect loop uses it
  // to end the attempt without reporting a failure.
  bool IsAuthCancelled() const;

  // True once a connect attempt got far enough to create a session. Until then
  // a teardown is the end of a failed attempt, not a session ending, and the
  // retry ladder is the only thing that may publish a state.
  bool HasEverConnected() const;
  void MarkEverConnected();

  // True once no thread can still be running inside the session, so the caller
  // may destroy it. False while a teardown is in flight.
  bool IsTeardownComplete() const;

  HarmonySurfaceSnapshot GetSnapshot() const;
  HarmonySessionInfo GetInfo() const;
  std::uint32_t GetFrameStride() const;
  std::uint64_t GetFrameSequence() const;
  std::vector<std::uint8_t> GetFrameBGRA() const;
  std::vector<HarmonySessionEvent> DrainEvents();
  bool ShouldIgnoreCertificate() const;
  bool SetClipboardText(const std::string& text);
  // Fills the credentials FreeRDP asked for. Returns false when the user
  // closed the prompt, so FreeRDP aborts the attempt instead of retrying it
  // with empty credentials.
  bool FillAuthentication(char** username, char** password, char** domain,
                          std::uint32_t reason);
  bool VerifyCertificate(const char* host, std::uint16_t port, const char* commonName,
                         const char* subject, const char* issuer, const char* fingerprint,
                         std::uint32_t flags);
  bool VerifyChangedCertificate(const char* host, std::uint16_t port, const char* commonName,
                                const char* subject, const char* issuer, const char* newFingerprint,
                                const char* oldSubject, const char* oldIssuer,
                                const char* oldFingerprint, std::uint32_t flags);
  bool SendMouseMove(std::uint16_t x, std::uint16_t y);
  bool SendMouseButton(std::uint16_t x, std::uint16_t y, std::uint16_t buttonFlags, bool down);
  bool SendMouseWheel(std::uint16_t x, std::uint16_t y, std::int16_t delta);
  // Asks the server to lay the remote desktop out at this size. The request is
  // sent once the display control channel has announced its capabilities; on
  // servers without it the call is a no-op and the existing desktop stays.
  // deviceScalePercent is the view's px-per-vp ratio in percent (180 on a 1.8x
  // display); the layout carries it so the server draws the desktop at the same
  // logical size the user sees, instead of 100%. Zero keeps the previous value.
  bool ResizeDesktop(std::uint32_t width, std::uint32_t height,
                     std::uint32_t deviceScalePercent);
  bool SendKeyScancode(std::uint32_t scancode, bool down);
  bool SendUnicodeKey(std::uint16_t codepoint, bool down);
  void SubmitAuth(const std::string& username, const std::string& password, const std::string& domain);
  // Closes the credential prompt without credentials. The attempt is abandoned
  // instead of being retried, which is what the user asked for by cancelling.
  void CancelAuth();
  void SubmitCert(bool accept);
  void SetCertificateCommonName(const std::string& cn);
  void SetSurfaceId(const std::string& surfaceIdStr);
  void UpdateFrame(std::uint32_t width, std::uint32_t height, std::uint32_t left,
                   std::uint32_t top, std::uint32_t dirtyWidth, std::uint32_t dirtyHeight,
                   const std::uint8_t* data, std::size_t size, std::uint32_t stride);
  void UpdateSnapshot(std::uint32_t width, std::uint32_t height, std::uint32_t left,
                      std::uint32_t top, std::uint32_t dirtyWidth,
                      std::uint32_t dirtyHeight);
  void UpdateStage(HarmonySessionStage stage, std::uint32_t lastError,
                   const std::string& message);
  void SetCliprdrContext(void* cliprdr);
  void MarkClipboardReady(bool ready);
  // Display control channel (dynamic resolution) plumbing. The context is
  // published by the channel when it connects; caps arrive once the server
  // answered, and only then may a monitor layout be sent.
  void SetDispContext(void* disp);
  void MarkDisplayControlReady(std::uint32_t maxNumMonitors,
                               std::uint32_t maxMonitorAreaFactorA,
                               std::uint32_t maxMonitorAreaFactorB);
  std::string GetLocalClipboardText() const;
  bool SendClipboardFormatList();
  bool SendClipboardDataRequest(std::uint32_t formatId);
  bool OnRemoteClipboardData(const std::string& text);

 private:
  struct InputEvent {
    enum class Type {
      kMouse,
      kScancodeKey,
      kUnicodeKey,
      kDesktopResize,
    };

    Type type;
    std::uint16_t flags;
    std::uint16_t x;
    std::uint16_t y;
    std::uint32_t scancode;
    std::uint16_t codepoint;
  };

  // Detaches the current RDP context from the session. The caller becomes the
  // sole owner of the returned pointer and must free it once every thread that
  // could still use it is gone. Requires mutex_ to be held.
  //
  // This is the only legal way to obtain a context for release: taking a raw
  // snapshot and freeing it later lets the worker thread release the same
  // pointer first, which is what produced the SEGV_MAPERR crashes in
  // freerdp_client_context_free reported by AppGallery Connect.
  void* TakeContextLocked();

  bool EnsureContext();
  bool ApplySettings(void* settings, std::string& outError);
  std::vector<std::string> BuildCommandLineArgs() const;
  bool QueueInputEvent(const InputEvent& event);
  bool ProcessInputEvents(void* input);
  // Sends the last requested desktop size through the display control channel.
  // Requires the disp context and its caps; the request stays pending until
  // both are there. Runs on the session thread.
  void SendPendingDesktopResize();

  // Pins the native buffer geometry to the RDP desktop size. Requires mutex_ to
  // be held. Returns true when the window is bound to the requested size.
  bool EnsureNativeWindowGeometryLocked(std::uint32_t width, std::uint32_t height);
  // Adopts a desktop size announced by the server. Requires mutex_ to be held.
  void AdoptDesktopSizeLocked(std::uint32_t width, std::uint32_t height);
  // Emits one line with the measured presentation cost and resets the sample.
  // Requires mutex_ to be held.
  void FlushPresentStatsLocked();
  // Repaints the desktop FreeRDP already holds into the freshly allocated
  // surface buffers. Runs on the session thread, which is also the only writer
  // of the GDI buffer, so the pixels cannot change underneath it.
  void RepaintFromGdi();
  // True when a dequeued buffer still carrying the previous geometry may reset
  // and re-apply that geometry. Paced so a resize cannot turn into one
  // abort/SET_BUFFER_GEOMETRY pair per frame. Requires mutex_ to be held.
  bool CanReapplyNativeGeometryLocked(std::int64_t nowMs);
  // Writes the current frame into a native buffer and flushes it, declaring the
  // whole written area. Requires mutex_ to be held.
  void PresentToNativeWindowLocked(std::uint32_t width, std::uint32_t height,
                                   const std::uint8_t* data, std::uint32_t stride);
  void ThreadMain();
  void ThreadMainWithRetry();
  
  // 智能连接相关方法
  void ResetConnectionAttempt();
  bool PrepareNextConnectionAttempt();
  std::vector<std::string> GetSecurityProtocolsForAttempt() const;
  std::string GetCurrentAttemptDescription() const;
  
  // 自适应参数调整
  void AdjustParametersForAttempt();

  HarmonySessionConfig config_;
  mutable std::mutex mutex_;
  std::condition_variable stateChanged_;
  HarmonySurfaceSnapshot snapshot_;
  HarmonySessionInfo info_;
  void* context_;
  std::vector<std::uint8_t> frameBuffer_;
  std::uint32_t frameStride_;
  std::uint64_t frameSequence_;
  bool hasPendingFrameEvent_;
  std::deque<HarmonySessionEvent> pendingSessionEvents_;
  void* inputEventHandle_;
  std::deque<InputEvent> pendingInputEvents_;
  void* cliprdr_;
  void* disp_;
  bool displayControlReady_;
  freerdp_harmony::DesktopResizeQueue desktopResize_;
  // Collapses a layout the view asks for twice inside one layout tick. Every
  // layout that reaches the server makes Windows rebuild the desktop, and the
  // shell replays its taskbar animation each time.
  freerdp_harmony::DesktopResizeGate desktopResizeGate_;
  // Monitor area budget the server announced with its caps. Recorded for the
  // log: the protocol comment in this tree does not define the two factors
  // precisely enough to enforce them without risking a rejected auto fit.
  std::uint32_t maxMonitorAreaFactorA_;
  std::uint32_t maxMonitorAreaFactorB_;
  // The view's px-per-vp ratio in percent, sent with every layout so the server
  // scales the desktop to the same logical size the viewport has.
  std::uint32_t deviceScalePercent_;
  // Desktop size the server last announced. Frames that disagree with it right
  // after the announcement are pre-resize frames and must not pin the buffer
  // geometry back to the old size.
  std::uint32_t desktopWidth_;
  std::uint32_t desktopHeight_;
  std::int64_t desktopSizeUpdatedMs_;
  // Set when the view changed the size it draws into: the compositor gave the
  // surface new buffers, which are empty until something paints them.
  bool repaintRequested_;
  // Pre-resize frames discarded since the session started. Reported once at
  // teardown: a nonzero value explains a picture that briefly disagreed with
  // the announced desktop size.
  std::uint64_t staleFrameDrops_;
  // Frames that never reached the compositor, over the current sample window
  // and over the whole session. The periodic line shows whether drops are
  // happening while the user watches; the teardown line shows the total.
  std::uint64_t droppedPresentFrames_;
  std::uint64_t droppedPresentTotal_;
  // Presentation cost, sampled. "The desktop is slow" is either "the server
  // sent few frames" or "we spent the frame budget copying": the two have
  // completely different fixes, and only a measurement tells them apart.
  std::uint64_t presentFrames_;
  std::uint64_t presentBytes_;
  std::uint64_t presentCopyUs_;
  std::uint64_t presentFlushUs_;
  std::uint64_t presentWaitUs_;
  std::uint64_t presentMaxUs_;
  std::int64_t presentStatsSinceMs_;
  // Desktop size the UI was last told about. UpdateSnapshot may already have
  // moved the snapshot forward (a server resize does that before the next
  // frame), so the size the UI still shows has to be tracked on its own or it
  // would never learn about the new geometry.
  freerdp_harmony::DesktopSize publishedDesktop_;
  bool clipboardReady_;
  std::string localClipboardText_;
  bool started_;
  // Atomic so the log callback can read it on any thread, including while the
  // session mutex is held elsewhere; taking the mutex there would deadlock.
  std::atomic<bool> stopRequested_;
  bool disconnecting_;
  // Atomic: written by the session thread, read from FreeRDP's teardown
  // callback, which can run on that same thread but must not take mutex_.
  std::atomic<bool> everConnected_;
  bool warnedMissingNativeWindow_;
  std::thread worker_;
  NativeWindow* nativeWindow_;
  // Last geometry applied to nativeWindow_. A surface created before the first
  // UpdateSnapshot arrives is sized by the view, not by the desktop, so this is
  // tracked here and re-applied from UpdateFrame.
  std::uint32_t nativeGeometryWidth_;
  std::uint32_t nativeGeometryHeight_;
  // Native buffer setup failures repeat on every frame; report one per surface
  // binding so a real failure is still visible without flooding hilog.
  bool warnedNativeWindowFailure_;
  // Geometry is re-applied on every frame until it sticks, so a failure is
  // reported once instead of once per frame.
  bool warnedGeometryFailure_;
  // A buffer fence that never signals drops every frame; report it once per
  // surface binding rather than once per frame.
  bool warnedFenceFailure_;
  // Pre-resize frames are dropped in a burst after every resize; one line per
  // resize keeps that visible without flooding hilog.
  bool warnedStaleFrame_;
  // Timestamp of the last paced SET_BUFFER_GEOMETRY re-apply, in milliseconds;
  // negative until the first one.
  std::int64_t lastGeometryReapplyMs_ = -1;
  // True while frames are presented through the native window instead of the
  // shared frame buffer, which therefore holds an out-of-date frame.
  bool frameBufferStale_;

  // Authentication & Certificate Dialog State
  mutable std::mutex dialogMutex_;
  std::condition_variable dialogCV_;
  bool dialogAnswered_;
  // Set when the user closed the prompt. FillAuthentication() reports it to
  // FreeRDP, and the connect loop ends the attempt instead of retrying.
  bool dialogCancelled_;
  bool certAccepted_;
  std::string dialogUsername_;
  std::string dialogPassword_;
  std::string dialogDomain_;
  
  // 智能连接相关成员
  int currentConnectionAttempt_;
  int maxConnectionAttempts_;
  std::vector<std::string> securityProtocolOrder_;
  bool enableAdaptiveParameters_;
  bool useHighPerformanceMode_;
  std::string lastErrorType_;
  std::string lastSuccessfulProtocol_;
  
  // 连接历史记录（静态，跨会话共享）
  struct ConnectionHistory {
    std::string host;
    int port;
    std::string protocol;
    std::chrono::system_clock::time_point lastUsed;
    bool operator==(const ConnectionHistory& other) const {
      return host == other.host && port == other.port;
    }
  };
  
  static std::vector<ConnectionHistory> connectionHistory_;
  static std::mutex historyMutex_;
  
  // 查找和保存历史记录
  static std::string FindBestProtocolForHost(const std::string& host, int port);
  static void SaveSuccessfulProtocol(const std::string& host, int port, const std::string& protocol);
};

using FreeRDPHarmonySessionPtr = std::shared_ptr<FreeRDPHarmonySession>;

#endif
