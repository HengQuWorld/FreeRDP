import { ConnectionProfile, cloneProfile } from '../model/ConnectionProfile';
import { SessionEvent, SessionEventType, SessionSnapshot, SessionStage, SessionState } from '../model/SessionModels';
import { sessionBridge } from './SessionNativeBridge';
import { logger, LogTags } from '../utils/Logger';
import { i18n } from '../utils/I18n';

export interface SessionRecord {
  sessionId: number;
  profile: ConnectionProfile;
  state: SessionState;
  snapshot: SessionSnapshot;
  remoteClipboardText: string;
  authUsername: string;
  authDomain: string;
}

type SessionChangedCallback = () => void;
type CertCommonNameDiscoveredCallback = (sessionId: number, cn: string) => void;

class SessionManagerImpl {
  private sessions: Map<number, SessionRecord> = new Map();
  private refreshTimers: Map<number, number> = new Map();
  private listeners: Set<SessionChangedCallback> = new Set();
  private cnDiscoveredListeners: Set<CertCommonNameDiscoveredCallback> = new Set();
  private cnNotifiedSessionIds: Set<number> = new Set();
  private lastObservedFrameSequences: Map<number, number> = new Map();

  onChanged(callback: SessionChangedCallback): () => void {
    this.listeners.add(callback);
    return () => {
      this.listeners.delete(callback);
    };
  }

  onCertCommonNameDiscovered(callback: CertCommonNameDiscoveredCallback): () => void {
    this.cnDiscoveredListeners.add(callback);
    return () => {
      this.cnDiscoveredListeners.delete(callback);
    };
  }

  private notifyChanged(): void {
    this.listeners.forEach((callback: SessionChangedCallback) => {
      callback();
    });
  }

  private notifyCnDiscovered(sessionId: number, cn: string): void {
    this.cnDiscoveredListeners.forEach((callback: CertCommonNameDiscoveredCallback) => {
      callback(sessionId, cn);
    });
  }

  private buildInitialSessionState(sessionId: number, profile: ConnectionProfile): SessionState {
    return {
      sessionId: sessionId,
      stage: SessionStage.Idle,
      title: profile.name.length > 0 ? profile.name : profile.host,
      message: '尚未连接',
      profile: cloneProfile(profile),
      certCommonName: ''
    };
  }

  private buildInitialSnapshot(): SessionSnapshot {
    return {
      width: 0,
      height: 0,
      frameStride: 0,
      frameSequence: 0,
      dirtyLeft: 0,
      dirtyTop: 0,
      dirtyWidth: 0,
      dirtyHeight: 0
    };
  }

  async createAndConnect(profile: ConnectionProfile): Promise<number> {
    logger.info(LogTags.SESSION_MANAGER, `Creating session for ${profile.host}:${profile.port}`);
    
    const sessionId: number = sessionBridge.createSession(profile);
    if (sessionId <= 0) {
      logger.error(LogTags.SESSION_MANAGER, 'Failed to create session: sessionId <= 0');
      return 0;
    }

    logger.info(LogTags.SESSION_MANAGER, `Session created with ID: ${sessionId}`);

    const record: SessionRecord = {
      sessionId: sessionId,
      profile: cloneProfile(profile),
      state: this.buildInitialSessionState(sessionId, profile),
      snapshot: this.buildInitialSnapshot(),
      remoteClipboardText: '',
      authUsername: '',
      authDomain: ''
    };
    this.sessions.set(sessionId, record);

    const connectingState: SessionState = {
      sessionId: record.state.sessionId,
      stage: SessionStage.Connecting,
      title: record.state.title,
      message: i18n.get(i18n.currentLocale(), 'session.connecting'),
      profile: record.state.profile,
      certCommonName: ''
    };
    record.state = connectingState;
    this.notifyChanged();

    try {
      logger.info(LogTags.SESSION_MANAGER, `Connecting session ${sessionId}...`);
      const connectedState: SessionState = await sessionBridge.connect(sessionId);
      record.state = connectedState;
      record.snapshot = sessionBridge.getSnapshot(sessionId);
      this.lastObservedFrameSequences.set(sessionId, record.snapshot.frameSequence);
      
      if (connectedState.certCommonName.length > 0 && !this.cnNotifiedSessionIds.has(sessionId)) {
        this.cnNotifiedSessionIds.add(sessionId);
        this.notifyCnDiscovered(sessionId, connectedState.certCommonName);
      }
      
      logger.info(LogTags.SESSION_MANAGER, `Session ${sessionId} connected successfully`);
    } catch (e) {
      const errorMsg: string = logger.logException(LogTags.SESSION_MANAGER, 'Connection', e);
      const friendlyMsg: string = i18n.get(i18n.currentLocale(), 'session.connect_failed');
      
      record.state = {
        sessionId: sessionId,
        stage: SessionStage.Error,
        title: profile.name.length > 0 ? profile.name : profile.host,
        message: `${friendlyMsg}: ${errorMsg}`,
        profile: cloneProfile(profile),
        certCommonName: ''
      };
      
      this.notifyChanged();
      // 抛出错误让 UI 层也能感知！
      throw new Error(`${friendlyMsg}: ${errorMsg}`);
    }

    this.startEventPolling(sessionId);
    this.notifyChanged();
    return sessionId;
  }

  async disconnect(sessionId: number): Promise<void> {
    logger.info(LogTags.SESSION_MANAGER, `Disconnecting session ${sessionId}`);
    
    const record: SessionRecord | undefined = this.sessions.get(sessionId);
    if (record === undefined) {
      logger.warn(LogTags.SESSION_MANAGER, `Session ${sessionId} not found for disconnect`);
      return;
    }

    this.stopEventPolling(sessionId);

    try {
      await sessionBridge.disconnect(sessionId);
      logger.info(LogTags.SESSION_MANAGER, `Session ${sessionId} disconnected successfully`);
    } catch (e) {
      logger.error(LogTags.SESSION_MANAGER, `Failed to disconnect session ${sessionId}`, e);
    }

    record.state = {
      sessionId: record.state.sessionId,
      stage: SessionStage.Disconnected,
      title: record.state.title,
      message: i18n.get(i18n.currentLocale(), 'session.disconnected'),
      profile: record.state.profile,
      certCommonName: record.state.certCommonName
    };
    this.notifyChanged();
  }

  removeSession(sessionId: number): void {
    this.stopEventPolling(sessionId);
    this.sessions.delete(sessionId);
    this.lastObservedFrameSequences.delete(sessionId);
    this.cnNotifiedSessionIds.delete(sessionId);
    this.notifyChanged();
  }

  getActiveSessions(): SessionRecord[] {
    const result: SessionRecord[] = [];
    this.sessions.forEach((record: SessionRecord) => {
      if (record.state.stage === SessionStage.Connected || record.state.stage === SessionStage.Connecting) {
        result.push(record);
      }
    });
    return result;
  }

  getAllSessions(): SessionRecord[] {
    const result: SessionRecord[] = [];
    this.sessions.forEach((record: SessionRecord) => {
      result.push(record);
    });
    return result;
  }

  getSession(sessionId: number): SessionRecord | undefined {
    return this.sessions.get(sessionId);
  }

  getSessionState(sessionId: number): SessionState | undefined {
    return this.sessions.get(sessionId)?.state;
  }

  getSessionSnapshot(sessionId: number): SessionSnapshot | undefined {
    return this.sessions.get(sessionId)?.snapshot;
  }

  getFrameBuffer(sessionId: number): ArrayBuffer {
    const record: SessionRecord | undefined = this.sessions.get(sessionId);
    if (record === undefined || record.state.sessionId <= 0) {
      return new ArrayBuffer(0);
    }
    return sessionBridge.getFrameBuffer(sessionId);
  }

  async setSurfaceId(sessionId: number, surfaceId: string): Promise<void> {
    if (sessionId > 0) {
      await sessionBridge.setSurfaceId(sessionId, surfaceId);
    }
  }

  async submitAuth(sessionId: number, username: string, pass: string, domain: string): Promise<void> {
    if (sessionId > 0) {
      await sessionBridge.submitAuth(sessionId, username, pass, domain);
    }
  }

  async submitCert(sessionId: number, accept: boolean): Promise<void> {
    if (sessionId > 0) {
      await sessionBridge.submitCert(sessionId, accept);
    }
  }

  async sendMouseMove(sessionId: number, x: number, y: number): Promise<void> {
    await sessionBridge.sendMouseMove(sessionId, x, y);
  }

  async sendMouseButton(sessionId: number, x: number, y: number, buttonFlags: number, down: boolean): Promise<void> {
    await sessionBridge.sendMouseButton(sessionId, x, y, buttonFlags, down);
  }

  async sendMouseWheel(sessionId: number, x: number, y: number, delta: number): Promise<void> {
    await sessionBridge.sendMouseWheel(sessionId, x, y, delta);
  }

  async sendKeyScancode(sessionId: number, scancode: number, down: boolean): Promise<void> {
    await sessionBridge.sendKeyScancode(sessionId, scancode, down);
  }

  async sendUnicodeKey(sessionId: number, codepoint: number, down: boolean): Promise<void> {
    await sessionBridge.sendUnicodeKey(sessionId, codepoint, down);
  }

  async sendCtrlAltDel(sessionId: number): Promise<void> {
    await sessionBridge.sendCtrlAltDel(sessionId);
  }

  async sendWindowsKey(sessionId: number): Promise<void> {
    await sessionBridge.sendWindowsKey(sessionId);
  }

  async sendEscape(sessionId: number): Promise<void> {
    await sessionBridge.sendEscape(sessionId);
  }

  async setClipboardText(sessionId: number, text: string): Promise<void> {
    await sessionBridge.setClipboardText(sessionId, text);
  }

  consumeRemoteClipboardText(sessionId: number): string {
    const record: SessionRecord | undefined = this.sessions.get(sessionId);
    if (record === undefined) {
      return '';
    }
    const text: string = record.remoteClipboardText;
    record.remoteClipboardText = '';
    return text;
  }

  private startEventPolling(sessionId: number): void {
    if (this.refreshTimers.has(sessionId)) {
      return;
    }

    const timer: number = setInterval(() => {
      this.pollSessionEvents(sessionId);
    }, 120);
    this.refreshTimers.set(sessionId, timer);
  }

  private stopEventPolling(sessionId: number): void {
    const timer: number | undefined = this.refreshTimers.get(sessionId);
    if (timer !== undefined) {
      clearInterval(timer);
      this.refreshTimers.delete(sessionId);
    }
  }

  private pollSessionEvents(sessionId: number): void {
    const record: SessionRecord | undefined = this.sessions.get(sessionId);
    if (record === undefined) {
      logger.warn(LogTags.SESSION_MANAGER, `Session ${sessionId} not found during event polling, stopping`);
      this.stopEventPolling(sessionId);
      return;
    }

    let events: SessionEvent[];
    try {
      events = sessionBridge.drainEvents(sessionId);
    } catch (e) {
      logger.error(LogTags.SESSION_MANAGER, `Failed to drain events for session ${sessionId}`, e);
      return;
    }

    let shouldRefreshState: boolean = false;
    let shouldRefreshSnapshot: boolean = false;
    let index: number = 0;
    while (index < events.length) {
      const event: SessionEvent = events[index];
      if (event.type === SessionEventType.StateChanged) {
        shouldRefreshState = true;
      } else if (event.type === SessionEventType.FrameUpdated) {
        const lastSeq: number = this.lastObservedFrameSequences.get(sessionId) ?? 0;
        if (event.frameSequence > lastSeq) {
          shouldRefreshSnapshot = true;
        }
      } else if (event.type === SessionEventType.RemoteClipboardChanged) {
        record.remoteClipboardText = event.clipboardText;
      } else if (event.type === SessionEventType.AuthRequired) {
        record.authUsername = event.authUsername;
        record.authDomain = event.authDomain;
        shouldRefreshState = true;
        logger.info(LogTags.SESSION_MANAGER, `Auth required for session ${sessionId}`);
      } else if (event.type === SessionEventType.CertRequired) {
        shouldRefreshState = true;
        logger.info(LogTags.SESSION_MANAGER, `Cert verification required for session ${sessionId}`);
      }
      index += 1;
    }

    if (!shouldRefreshState &&
        record.state.stage !== SessionStage.Disconnected &&
        record.state.stage !== SessionStage.Error) {
      try {
        const reconciledState: SessionState = sessionBridge.getState(sessionId);
        if (reconciledState.stage !== record.state.stage ||
            reconciledState.message !== record.state.message ||
            reconciledState.certCommonName !== record.state.certCommonName) {
          if (!this.cnNotifiedSessionIds.has(sessionId) &&
              reconciledState.certCommonName.length > 0) {
            this.cnNotifiedSessionIds.add(sessionId);
            this.notifyCnDiscovered(sessionId, reconciledState.certCommonName);
          }
          record.state = reconciledState;
          shouldRefreshState = true;
        }
      } catch (e) {
        logger.error(LogTags.SESSION_MANAGER,
          `Failed to reconcile state for session ${sessionId}`, e);
      }
    }

    if (shouldRefreshState) {
      try {
        const newState: SessionState = sessionBridge.getState(sessionId);
        if (!this.cnNotifiedSessionIds.has(sessionId) &&
            newState.certCommonName.length > 0) {
          this.cnNotifiedSessionIds.add(sessionId);
          this.notifyCnDiscovered(sessionId, newState.certCommonName);
        }
        record.state = newState;
      } catch (e) {
        logger.error(LogTags.SESSION_MANAGER, `Failed to refresh state for session ${sessionId}`, e);
      }
    }
    if (shouldRefreshSnapshot) {
      try {
        record.snapshot = sessionBridge.getSnapshot(sessionId);
        this.lastObservedFrameSequences.set(sessionId, record.snapshot.frameSequence);
      } catch (e) {
        logger.error(LogTags.SESSION_MANAGER, `Failed to refresh snapshot for session ${sessionId}`, e);
      }
    }

    if (shouldRefreshState || shouldRefreshSnapshot) {
      this.notifyChanged();
    }
  }

  disconnectAll(): void {
    const sessionIds: number[] = [];
    this.sessions.forEach((_: SessionRecord, sessionId: number) => {
      sessionIds.push(sessionId);
    });
    sessionIds.forEach((sessionId: number) => {
      void this.disconnect(sessionId);
    });
  }
}

export const sessionManager: SessionManagerImpl = new SessionManagerImpl();
