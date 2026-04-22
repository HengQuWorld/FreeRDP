import { router } from '@kit.ArkUI';
import pasteboard from '@ohos.pasteboard';
import { SessionWindow } from '../components/SessionWindow';
import { SessionViewModel } from '../viewmodel/SessionViewModel';
import { ConnectionProfile } from '../model/ConnectionProfile';
import { SessionEvent } from '../model/SessionModels';
import { AuthDialog } from '../components/AuthDialog';
import { CertDialog } from '../components/CertDialog';

@Entry
@Component
struct Session {
  private static readonly SESSION_WANT_PAYLOAD_KEY: string = 'sessionWantPayload';
  @State sessionViewModel: SessionViewModel | null = null;
  private refreshTimer: number = -1;
  private connectTimer: number = -1;
  private systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
  private applyingRemoteClipboard: boolean = false;
  private lastClipboardText: string = '';
  
  @State authEvent: SessionEvent | null = null;
  @State certEvent: SessionEvent | null = null;

  authDialogController: CustomDialogController = new CustomDialogController({
    builder: AuthDialog({
      event: this.authEvent,
      username: this.sessionViewModel?.state.profile.username || '',
      password: this.sessionViewModel?.state.profile.password || '',
      domain: this.sessionViewModel?.state.profile.domain || '',
      onConfirm: (username: string, pass: string, domain: string) => {
        this.sessionViewModel?.submitAuth(username, pass, domain);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  });

  certDialogController: CustomDialogController = new CustomDialogController({
    builder: CertDialog({
      event: this.certEvent,
      onConfirm: (accept: boolean) => {
        this.sessionViewModel?.submitCert(accept);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  });

  private readStoredSessionParams(): Record<string, Object> {
    const payload: string = AppStorage.get<string>(Session.SESSION_WANT_PAYLOAD_KEY) ?? '';
    if (payload.length === 0) {
      return {};
    }

    try {
      const parsed: Object = JSON.parse(payload) as Object;
      return parsed as Record<string, Object>;
    } catch (error) {
      console.error(`Session readStoredSessionParams failed: ${JSON.stringify(error)}`);
      return {};
    }
  }

  private buildProfile(): ConnectionProfile {
    const params: Record<string, Object> = this.readStoredSessionParams();
    console.info(`Session buildProfile host=${String(params['host'] || '')} id=${String(params['id'] || '')}`);

    return {
      id: (params['id'] as string) || '',
      name: (params['name'] as string) || '',
      host: (params['host'] as string) || '',
      port: (typeof params['port'] === 'number') ? params['port'] : Number(params['port'] || 3389),
      clientHostname: (params['clientHostname'] as string) || '',
      username: (params['username'] as string) || '',
      password: (params['password'] as string) || '',
      rememberPassword: (params['rememberPassword'] as boolean) || false,
      domain: (params['domain'] as string) || '',
      gateway: (params['gateway'] as string) || '',
      gatewayUsername: (params['gatewayUsername'] as string) || '',
      gatewayPassword: (params['gatewayPassword'] as string) || '',
      gatewayDomain: (params['gatewayDomain'] as string) || '',
      securityMode: (params['securityMode'] as string) || 'auto',
      appDataDir: (params['appDataDir'] as string) || '',
      enableClipboard: (params['enableClipboard'] as boolean) || false,
      enableAudio: (params['enableAudio'] as boolean) || false,
      enableDrive: (params['enableDrive'] as boolean) || false
    };
  }

  private clearTimers(): void {
    if (this.connectTimer >= 0) {
      clearTimeout(this.connectTimer);
      this.connectTimer = -1;
    }
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private closeSessionPage(): void {
    router.back();
  }

  private beginSession(profile: ConnectionProfile): void {
    this.clearTimers();
    if (this.sessionViewModel !== null) {
      this.sessionViewModel.disconnect();
    }
    this.sessionViewModel = new SessionViewModel(profile);
    this.sessionViewModel.onAuthRequired = (event: SessionEvent) => {
      this.authEvent = event;
      this.authDialogController.open();
    };
    this.sessionViewModel.onCertRequired = (event: SessionEvent) => {
      this.certEvent = event;
      this.certDialogController.open();
    };

    this.connectTimer = setTimeout(() => {
      this.connectTimer = -1;
      this.startConnection();
    }, 0);

    this.refreshTimer = setInterval(() => {
      if (this.sessionViewModel) {
        this.sessionViewModel.drainNativeEvents();
        const remoteClipboardText: string = this.sessionViewModel.consumeRemoteClipboardText();
        if (remoteClipboardText.length > 0) {
          this.applyRemoteClipboard(remoteClipboardText);
        }
      }
    }, 120);
  }

  private startConnection(): void {
    if (this.sessionViewModel === null) {
      return;
    }

    this.sessionViewModel.connect().then(() => {
      this.sessionViewModel?.refreshSnapshot();
    }).catch((e: Error) => {
      if (this.sessionViewModel) {
        this.sessionViewModel.setFailure('连接失败: ' + e.message);
      }
    });
  }

  private applyRemoteClipboard(text: string): void {
    if (text.length === 0 || text === this.lastClipboardText) {
      return;
    }

    this.applyingRemoteClipboard = true;
    this.lastClipboardText = text;
    this.systemPasteboard.setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)).then(() => {
      this.applyingRemoteClipboard = false;
    }).catch(() => {
      this.applyingRemoteClipboard = false;
    });
  }

  aboutToAppear(): void {
    this.beginSession(this.buildProfile());
  }

  aboutToDisappear(): void {
    this.clearTimers();
    if (this.sessionViewModel) {
      this.sessionViewModel.disconnect();
    }
  }

  build() {
    Column() {
      if (this.sessionViewModel !== null) {
        SessionWindow({
          sessionId: this.sessionViewModel.state.sessionId,
          title: this.sessionViewModel.state.title,
          subtitle: this.sessionViewModel.state.message,
          stage: this.sessionViewModel.state.stage,
          snapshot: this.sessionViewModel.snapshot,
          getFrameBuffer: () => this.sessionViewModel!.getFrameBuffer(),
          setSurfaceId: async (surfaceId: string) => {
            await this.sessionViewModel!.setSurfaceId(surfaceId);
          },
          onMouseMove: async (x: number, y: number) => {
            await this.sessionViewModel!.sendMouseMove(x, y);
          },
          onMouseButton: async (x: number, y: number, buttonFlags: number, down: boolean) => {
            await this.sessionViewModel!.sendMouseButton(x, y, buttonFlags, down);
          },
          onMouseWheel: async (x: number, y: number, delta: number) => {
            await this.sessionViewModel!.sendMouseWheel(x, y, delta);
          },
          onKeyScancode: async (scancode: number, down: boolean) => {
            await this.sessionViewModel!.sendKeyScancode(scancode, down);
          },
          onUnicodeKey: async (codepoint: number, down: boolean) => {
            await this.sessionViewModel!.sendUnicodeKey(codepoint, down);
          },
          onSendCtrlAltDel: async () => {
            await this.sessionViewModel!.sendCtrlAltDel();
          },
          onSendWindowsKey: async () => {
            await this.sessionViewModel!.sendWindowsKey();
          },
          onSendEscape: async () => {
            await this.sessionViewModel!.sendEscape();
          },
          onDisconnect: async () => {
            await this.sessionViewModel!.disconnect();
            this.closeSessionPage();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F5F9')
  }
}
