import {
  createSession as nativeCreateSession,
  connect as nativeConnect,
  disconnect as nativeDisconnect,
  getSessionInfo as nativeGetSessionInfo,
  getSnapshot as nativeGetSnapshot,
  getFrameBuffer as nativeGetFrameBuffer,
  setSurfaceId as nativeSetSurfaceId,
  getLastErrorString as nativeGetLastErrorString,
  drainEvents as nativeDrainEvents,
  submitAuth as nativeSubmitAuth,
  submitCert as nativeSubmitCert,
  setClipboardText as nativeSetClipboardText,
  sendMouseMove as nativeSendMouseMove,
  resizeDesktop as nativeResizeDesktop,
  sendMouseButton as nativeSendMouseButton,
  sendMouseWheel as nativeSendMouseWheel,
  sendKeyScancode as nativeSendKeyScancode,
  sendUnicodeKey as nativeSendUnicodeKey,
  sendCtrlAltDel as nativeSendCtrlAltDel,
  sendWindowsKey as nativeSendWindowsKey,
  sendEscape as nativeSendEscape,
  NativeSessionConfig,
  NativeSessionEvent,
  NativeSessionInfo,
  NativeSessionSnapshot,
  NativeDriveRedirection
} from 'libfreerdp_harmony_bridge.so';
import { ConnectionProfile, cloneProfile, createEmptyProfile, DEFAULT_DESKTOP_WIDTH, DEFAULT_DESKTOP_HEIGHT, DriveRedirection, normalizeDriveRedirections } from '../model/ConnectionProfile';
import { SessionEvent, SessionEventType, SessionSnapshot, SessionStage, SessionState } from '../model/SessionModels';
import { i18n } from '../utils/I18n';

const NATIVE_STAGE_IDLE: number = 0;
const NATIVE_STAGE_CONNECTING: number = 1;
const NATIVE_STAGE_CONNECTED: number = 2;
const NATIVE_STAGE_DISCONNECTED: number = 3;
const NATIVE_STAGE_FAILED: number = 4;
const NATIVE_STAGE_AUTH_REQUIRED: number = 5;
const NATIVE_STAGE_CERT_REQUIRED: number = 6;

export interface SessionBackend {
  createSession(profile: ConnectionProfile): number;
  connect(sessionId: number): Promise<SessionState>;
  disconnect(sessionId: number): Promise<void>;
  getState(sessionId: number): SessionState;
  getSnapshot(sessionId: number): SessionSnapshot;
  getFrameBuffer(sessionId: number): ArrayBuffer;
  setSurfaceId(sessionId: number, surfaceId: string): Promise<void>;
  drainEvents(sessionId: number): SessionEvent[];
  submitAuth(sessionId: number, username: string, pass: string, domain: string): Promise<void>;
  submitCert(sessionId: number, accept: boolean): Promise<void>;
  setClipboardText(sessionId: number, text: string): Promise<void>;
  sendMouseMove(sessionId: number, x: number, y: number): Promise<void>;
  resizeDesktop(sessionId: number, width: number, height: number): Promise<void>;
  sendMouseButton(sessionId: number, x: number, y: number, buttonFlags: number, down: boolean): Promise<void>;
  sendMouseWheel(sessionId: number, x: number, y: number, delta: number): Promise<void>;
  sendKeyScancode(sessionId: number, scancode: number, down: boolean): Promise<void>;
  sendUnicodeKey(sessionId: number, codepoint: number, down: boolean): Promise<void>;
  sendCtrlAltDel(sessionId: number): Promise<void>;
  sendWindowsKey(sessionId: number): Promise<void>;
  sendEscape(sessionId: number): Promise<void>;
}

interface SessionRecord {
  sessionId: number;
  profile: ConnectionProfile;
}

class NativeSessionBackendImpl implements SessionBackend {
  private sessions: SessionRecord[] = [];

  private findSession(sessionId: number): SessionRecord | null {
    let index: number = 0;
    while (index < this.sessions.length) {
      const record: SessionRecord = this.sessions[index];
      if (record.sessionId === sessionId) {
        return record;
      }
      index += 1;
    }
    return null;
  }

  private buildNativeConfig(profile: ConnectionProfile): NativeSessionConfig {
    // An auto-fit profile stores 0x0 (follow the view). The session still has
    // to open at a concrete size before any view exists, so it starts at 1080p
    // and the first viewport report resizes it from there.
    const width: number = profile.desktopWidth > 0 ? profile.desktopWidth : DEFAULT_DESKTOP_WIDTH;
    const height: number = profile.desktopHeight > 0 ? profile.desktopHeight : DEFAULT_DESKTOP_HEIGHT;
    const drives: NativeDriveRedirection[] = normalizeDriveRedirections(profile.driveRedirections)
      .map((item: DriveRedirection): NativeDriveRedirection => {
        return { name: item.name, path: item.path };
      });
    return {
      name: profile.name,
      host: profile.host,
      port: profile.port,
      clientHostname: profile.clientHostname,
      username: profile.username,
      password: profile.password,
      domain: profile.domain,
      gateway: profile.gateway,
      gatewayUsername: profile.gatewayUsername,
      gatewayPassword: profile.gatewayPassword,
      gatewayDomain: profile.gatewayDomain,
      securityMode: profile.securityMode,
      appDataDir: profile.appDataDir,
      enableClipboard: profile.enableClipboard,
      enableAudio: profile.enableAudio,
      enableDrive: profile.enableDrive,
      ignoreCertificate: true,
      enableGfx: profile.enableGfx,
      desktopWidth: width,
      desktopHeight: height,
      driveRedirections: drives
    };
  }

  private mapStage(nativeStage: number, connected: boolean): SessionStage {
    // Terminal states must take precedence over the stale `connected` flag.
    // When the remote side disconnects (e.g. another user logs in), the native
    // layer reports nativeStage=DISCONNECTED but `connected` may still be true.
    if (nativeStage === NATIVE_STAGE_DISCONNECTED) {
      return SessionStage.Disconnected;
    }
    if (nativeStage === NATIVE_STAGE_FAILED) {
      return SessionStage.Error;
    }
    if (nativeStage === NATIVE_STAGE_AUTH_REQUIRED) {
      return SessionStage.AuthRequired;
    }
    if (nativeStage === NATIVE_STAGE_CERT_REQUIRED) {
      return SessionStage.CertRequired;
    }
    if (nativeStage === NATIVE_STAGE_CONNECTED || connected) {
      return SessionStage.Connected;
    }
    if (nativeStage === NATIVE_STAGE_CONNECTING) {
      return SessionStage.Connecting;
    }
    return SessionStage.Idle;
  }

  private mapEventType(nativeType: number): SessionEventType {
    if (nativeType === 1) {
      return SessionEventType.StateChanged;
    }
    if (nativeType === 2) {
      return SessionEventType.FrameUpdated;
    }
    if (nativeType === 3) {
      return SessionEventType.RemoteClipboardChanged;
    }
    if (nativeType === 4) {
      return SessionEventType.AuthRequired;
    }
    if (nativeType === 5) {
      return SessionEventType.CertRequired;
    }
    return SessionEventType.StateChanged;
  }

  private translateNativeMessage(rawMessage: string): string {
    if (rawMessage.length === 0) {
      return rawMessage;
    }

    const separatorIndex: number = rawMessage.indexOf('|||');
    let key: string = rawMessage;
    let detail: string = '';
    if (separatorIndex >= 0) {
      key = rawMessage.substring(0, separatorIndex);
      detail = rawMessage.substring(separatorIndex + 3);
    }

    if (key.startsWith('session.') || key.startsWith('error.')) {
      const translated: string = i18n.get(i18n.currentLocale(), key);
      if (translated !== key) {
        if (detail.length > 0) {
          return `${translated}: ${detail}`;
        }
        return translated;
      }
    }

    return rawMessage;
  }

  private defaultMessage(stage: SessionStage): string {
    if (stage === SessionStage.Connected) {
      return i18n.get(i18n.currentLocale(), 'session.connected');
    }
    if (stage === SessionStage.Connecting) {
      return i18n.get(i18n.currentLocale(), 'session.connecting');
    }
    if (stage === SessionStage.Disconnected) {
      return i18n.get(i18n.currentLocale(), 'session.disconnected');
    }
    if (stage === SessionStage.Error) {
      return i18n.get(i18n.currentLocale(), 'session.connect_failed');
    }
    return i18n.get(i18n.currentLocale(), 'session.not_connected');
  }

  private enrichMessage(sessionId: number, stage: SessionStage, nativeInfo: NativeSessionInfo,
                        baseMessage: string): string {
    if (nativeInfo.lastError === 0) {
      return baseMessage;
    }
    if (stage !== SessionStage.Error && stage !== SessionStage.Disconnected) {
      return baseMessage;
    }

    const lastErrorString: string = nativeGetLastErrorString(sessionId);
    return lastErrorString.length > 0 && baseMessage.indexOf(lastErrorString) < 0
      ? `${baseMessage}: ${lastErrorString}`
      : baseMessage;
  }

  private buildState(sessionId: number, nativeInfo: NativeSessionInfo,
                     profile: ConnectionProfile): SessionState {
    const stage: SessionStage = this.mapStage(nativeInfo.stage, nativeInfo.connected);
    const certCN: string = (nativeInfo.certCommonName && nativeInfo.certCommonName.length > 0)
      ? nativeInfo.certCommonName : '';
    const title: string = profile.name.length > 0
      ? profile.name
      : (certCN.length > 0 ? certCN : (profile.host.length > 0 ? profile.host : `Session ${sessionId}`));
    const baseMessage: string = nativeInfo.message.length > 0
      ? this.translateNativeMessage(nativeInfo.message)
      : this.defaultMessage(stage);
    const message: string = this.enrichMessage(sessionId, stage, nativeInfo, baseMessage);

    return {
      sessionId: sessionId,
      stage: stage,
      title: title,
      message: message,
      profile: cloneProfile(profile),
      certCommonName: certCN
    };
  }

  private requireRecord(sessionId: number): SessionRecord {
    const record: SessionRecord | null = this.findSession(sessionId);
    if (record === null) {
      throw new Error(`session ${sessionId} not found`);
    }
    return record;
  }

  private requireNativeOk(ok: boolean, action: string): void {
    if (!ok) {
      throw new Error(`native ${action} failed`);
    }
  }

  createSession(profile: ConnectionProfile): number {
    const sessionId: number = nativeCreateSession(this.buildNativeConfig(profile));
    if (sessionId > 0) {
      this.sessions = [
        ...this.sessions,
        {
          sessionId: sessionId,
          profile: cloneProfile(profile)
        }
      ];
    }
    return sessionId;
  }

  async connect(sessionId: number): Promise<SessionState> {
    const record: SessionRecord = this.requireRecord(sessionId);
    // Resolves once the native side finished building the context; the session
    // thread keeps working in the background from there.
    const nativeInfo: NativeSessionInfo = await nativeConnect(sessionId);
    return this.buildState(sessionId, nativeInfo, record.profile);
  }

  async disconnect(sessionId: number): Promise<void> {
    this.requireRecord(sessionId);
    // Resolves once the native teardown has finished, not when it is queued.
    await nativeDisconnect(sessionId);
  }

  getState(sessionId: number): SessionState {
    const record: SessionRecord | null = this.findSession(sessionId);
    if (record === null) {
      const missingInfo: NativeSessionInfo = {
        stage: NATIVE_STAGE_DISCONNECTED,
        lastError: 1,
        connected: false,
        message: i18n.get(i18n.currentLocale(), 'error.session_not_found'),
        certCommonName: ''
      };
      return this.buildState(sessionId, missingInfo, createEmptyProfile('missing'));
    }

    const nativeInfo: NativeSessionInfo = nativeGetSessionInfo(sessionId);
    return this.buildState(sessionId, nativeInfo, record.profile);
  }

  getSnapshot(sessionId: number): SessionSnapshot {
    this.requireRecord(sessionId);
    const snapshot: NativeSessionSnapshot = nativeGetSnapshot(sessionId);
    return {
      width: snapshot.width,
      height: snapshot.height,
      frameStride: snapshot.frameStride,
      frameSequence: snapshot.frameSequence,
      dirtyLeft: snapshot.dirtyLeft,
      dirtyTop: snapshot.dirtyTop,
      dirtyWidth: snapshot.dirtyWidth,
      dirtyHeight: snapshot.dirtyHeight,
      nativeWindowBound: snapshot.nativeWindowBound === true
    };
  }

  getFrameBuffer(sessionId: number): ArrayBuffer {
    this.requireRecord(sessionId);
    return nativeGetFrameBuffer(sessionId);
  }

  drainEvents(sessionId: number): SessionEvent[] {
    this.requireRecord(sessionId);
    const events: NativeSessionEvent[] = nativeDrainEvents(sessionId);
    let index: number = 0;
    const mapped: SessionEvent[] = [];
    while (index < events.length) {
      mapped.push({
        type: this.mapEventType(events[index].type),
        stage: this.mapStage(events[index].stage, events[index].connected),
        lastError: events[index].lastError,
        connected: events[index].connected,
        frameSequence: events[index].frameSequence,
        message: this.translateNativeMessage(events[index].message),
        clipboardText: events[index].clipboardText,
        certHost: events[index].certHost,
        certSubject: events[index].certSubject,
        certIssuer: events[index].certIssuer,
        certFingerprint: events[index].certFingerprint,
        authUsername: events[index].authUsername,
        authDomain: events[index].authDomain
      });
      index += 1;
    }
    return mapped;
  }

  async setClipboardText(sessionId: number, text: string): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSetClipboardText(sessionId, text), 'setClipboardText');
  }

  async submitAuth(sessionId: number, username: string, pass: string, domain: string): Promise<void> {
    this.requireRecord(sessionId);
    nativeSubmitAuth(sessionId, username, pass, domain);
  }

  async submitCert(sessionId: number, accept: boolean): Promise<void> {
    this.requireRecord(sessionId);
    nativeSubmitCert(sessionId, accept);
  }

  async setSurfaceId(sessionId: number, surfaceId: string): Promise<void> {
    this.requireRecord(sessionId);
    nativeSetSurfaceId(sessionId, surfaceId);
  }

  async sendMouseMove(sessionId: number, x: number, y: number): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendMouseMove(sessionId, x, y), 'sendMouseMove');
  }

  async resizeDesktop(sessionId: number, width: number, height: number): Promise<void> {
    // Best effort: the view asks on a timer and may outlive the session by a
    // few milliseconds. There is nothing to do for a session that is gone, and
    // a refused request only means the server cannot resize right now (no
    // display control channel, or the session is winding down): the viewport
    // keeps working with the letterboxed fit.
    if (this.findSession(sessionId) === null) {
      return;
    }
    nativeResizeDesktop(sessionId, width, height);
  }

  async sendMouseButton(sessionId: number, x: number, y: number, buttonFlags: number,
                        down: boolean): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendMouseButton(sessionId, x, y, buttonFlags, down),
      'sendMouseButton');
  }

  async sendMouseWheel(sessionId: number, x: number, y: number, delta: number): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendMouseWheel(sessionId, x, y, delta), 'sendMouseWheel');
  }

  async sendKeyScancode(sessionId: number, scancode: number, down: boolean): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendKeyScancode(sessionId, scancode, down), 'sendKeyScancode');
  }

  async sendUnicodeKey(sessionId: number, codepoint: number, down: boolean): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendUnicodeKey(sessionId, codepoint, down), 'sendUnicodeKey');
  }

  async sendCtrlAltDel(sessionId: number): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendCtrlAltDel(sessionId), 'sendCtrlAltDel');
  }

  async sendWindowsKey(sessionId: number): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendWindowsKey(sessionId), 'sendWindowsKey');
  }

  async sendEscape(sessionId: number): Promise<void> {
    this.requireRecord(sessionId);
    this.requireNativeOk(nativeSendEscape(sessionId), 'sendEscape');
  }
}

export const sessionBackend: SessionBackend = new NativeSessionBackendImpl();
