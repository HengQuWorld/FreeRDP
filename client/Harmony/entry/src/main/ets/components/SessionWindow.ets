import { SessionSnapshot, SessionStage } from '../model/SessionModels';
import { RemoteDesktopSurface } from './RemoteDesktopSurface';
import { SessionToolbar } from './SessionToolbar';
import { ThemeColors, LightColors, DarkColors } from '../utils/ThemeConstants';
import { i18n } from '../utils/I18n';

@Component
export struct SessionWindow {
  @Prop sessionId: number;
  @Prop title: string;
  @Prop subtitle: string;
  @Prop stage: SessionStage;
  @Prop statusMessage: string;
  @Prop snapshot: SessionSnapshot;
  @Prop @Watch('onThemeChanged') isDark: boolean = false;
  @Prop appLanguage: string = 'system';
  @State colors: ThemeColors = LightColors;
  getFrameBuffer: () => ArrayBuffer = (): ArrayBuffer => new ArrayBuffer(0);
  setSurfaceId: (surfaceId: string) => Promise<void> = async (_surfaceId: string): Promise<void> => {};
  onMouseMove: (x: number, y: number) => void = (_x: number, _y: number): void => {};
  onMouseButton: (x: number, y: number, buttonFlags: number, down: boolean) => void =
    (_x: number, _y: number, _buttonFlags: number, _down: boolean): void => {};
  onMouseWheel: (x: number, y: number, delta: number) => void =
    (_x: number, _y: number, _delta: number): void => {};
  onKeyScancode: (scancode: number, down: boolean) => void =
    (_scancode: number, _down: boolean): void => {};
  onUnicodeKey: (codepoint: number, down: boolean) => void =
    (_codepoint: number, _down: boolean): void => {};
  onSendCtrlAltDel: () => void = (): void => {};
  onSendWindowsKey: () => void = (): void => {};
  onSendEscape: () => void = (): void => {};
  onDisconnect: () => void = (): void => {};
  @State private isFullscreen: boolean = false;
  @State private keyboardRequestToken: number = 0;
  @State private chromeVisible: boolean = true;
  @State private zoomScale: number = 1.0;
  @State private zoomInToken: number = 0;
  @State private zoomOutToken: number = 0;
  @State private zoomResetToken: number = 0;
  @State private showNavigationPad: boolean = false;
  @State private panUpToken: number = 0;
  @State private panDownToken: number = 0;
  @State private panLeftToken: number = 0;
  @State private panRightToken: number = 0;
  @State private surfaceWidth: number = 0;
  @State private surfaceHeight: number = 0;
  @State private navPadX: number = 0;
  @State private navPadY: number = 0;
  private chromeHideTimer: number = -1;
  private navPadDragging: boolean = false;
  private navPadDragStartX: number = 0;
  private navPadDragStartY: number = 0;
  private navPadInited: boolean = false;

  onThemeChanged(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  private scheduleChromeAutoHide(): void {
    if (this.chromeHideTimer !== -1) {
      clearTimeout(this.chromeHideTimer);
    }
    this.chromeHideTimer = setTimeout(() => {
      this.chromeVisible = false;
      this.chromeHideTimer = -1;
    }, 8000);
  }

  private revealChrome(): void {
    this.chromeVisible = true;
    this.scheduleChromeAutoHide();
  }

  private extendChromeInteractionIfVisible(): void {
    if (this.chromeVisible) {
      this.scheduleChromeAutoHide();
    }
  }

  private ensureNavPadPosition(): void {
    if (this.navPadInited) return;
    this.navPadX = Math.max(0, this.surfaceWidth - 176);
    this.navPadY = Math.max(0, this.surfaceHeight - 280);
    this.navPadInited = true;
  }

  aboutToAppear(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
    this.scheduleChromeAutoHide();
  }

  aboutToDisappear(): void {
    if (this.chromeHideTimer !== -1) {
      clearTimeout(this.chromeHideTimer);
      this.chromeHideTimer = -1;
    }
  }

  private getConnectionStateColor(): string {
    if (this.stage === SessionStage.Connected) return 'rgba(34,160,107,0.85)';
    if (this.stage === SessionStage.Connecting) return 'rgba(176,136,44,0.85)';
    if (this.stage === SessionStage.Error) return 'rgba(200,40,40,0.85)';
    return 'rgba(120,113,108,0.85)';
  }

  private getConnectionStateText(): string {
    if (this.stage === SessionStage.Connected) return i18n.get(this.appLanguage, 'status.connected');
    if (this.stage === SessionStage.Connecting) return i18n.get(this.appLanguage, 'status.connecting');
    if (this.stage === SessionStage.Error) return i18n.get(this.appLanguage, 'status.error');
    if (this.stage === SessionStage.Disconnected) return i18n.get(this.appLanguage, 'status.disconnected');
    return i18n.get(this.appLanguage, 'status.idle');
  }

  build() {
    Stack() {
      RemoteDesktopSurface({
        sessionId: this.sessionId,
        stage: this.stage,
        snapshot: this.snapshot,
        keyboardRequestToken: this.keyboardRequestToken,
        isFullscreen: this.isFullscreen,
        isDark: this.isDark,
        getFrameBuffer: this.getFrameBuffer,
        setSurfaceId: this.setSurfaceId,
        onMouseMove: this.onMouseMove,
        onMouseButton: (x, y, btn, down) => {
          this.extendChromeInteractionIfVisible();
          this.onMouseButton(x, y, btn, down);
        },
        onMouseWheel: this.onMouseWheel,
        onKeyScancode: (code, down) => {
          this.extendChromeInteractionIfVisible();
          this.onKeyScancode(code, down);
        },
        onUnicodeKey: (code, down) => {
          this.extendChromeInteractionIfVisible();
          this.onUnicodeKey(code, down);
        },
        onScaleChange: (scale: number) => {
          this.zoomScale = scale;
        },
        onSurfaceSizeChange: (width: number, height: number) => {
          this.surfaceWidth = width;
          this.surfaceHeight = height;
        },
        zoomInToken: this.zoomInToken,
        zoomOutToken: this.zoomOutToken,
        zoomResetToken: this.zoomResetToken,
        panUpToken: this.panUpToken,
        panDownToken: this.panDownToken,
        panLeftToken: this.panLeftToken,
        panRightToken: this.panRightToken
      })

      if (this.chromeVisible) {
        Column() {
          Row() {
            Column({ space: 2 }) {
              Text(this.title)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#ffffff')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(this.subtitle)
                .fontSize(12)
                .fontColor('rgba(231,229,228,0.82)')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Row({ space: 8 }) {
              Text(this.getConnectionStateText())
                .fontSize(11)
                .fontColor('#ffffff')
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.getConnectionStateColor())
                .borderRadius(14)

              if (this.stage === SessionStage.Connected) {
                Button(this.isFullscreen ? i18n.get(this.appLanguage, 'exit_fullscreen') : i18n.get(this.appLanguage, 'fullscreen'))
                  .height(32)
                  .fontSize(12)
                  .fontColor('#e7e5e4')
                  .backgroundColor('rgba(255,255,255,0.08)')
                  .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
                  .borderRadius(16)
                  .onClick(() => {
                    this.isFullscreen = !this.isFullscreen;
                    this.extendChromeInteractionIfVisible();
                  })
              }
            }
            .margin({ left: 12 })
            .justifyContent(FlexAlign.End)
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: this.isFullscreen ? 12 : 14, bottom: 12 })
          .backgroundColor('rgba(12,20,22,0.76)')
          .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
          .borderRadius(this.isFullscreen ? 20 : 18)
          .margin({ left: 12, right: 12, top: 12 })
          .shadow({ radius: 18, color: 'rgba(0,0,0,0.16)', offsetX: 0, offsetY: 6 })
          .onTouch((ev: TouchEvent) => {
            if (ev.type === TouchType.Down) this.extendChromeInteractionIfVisible();
          })
          .onMouse(() => {})
          .onHover(() => {})

          if (this.stage === SessionStage.Error || this.stage === SessionStage.Disconnected) {
            Text(this.statusMessage)
              .fontSize(12)
              .fontColor('rgba(231,229,228,0.90)')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.stage === SessionStage.Error
                ? 'rgba(200,40,40,0.18)' : 'rgba(120,113,108,0.18)')
              .borderRadius(12)
              .margin({ left: 12, right: 12, top: 6 })
          }

          Blank()
            .layoutWeight(1)

          if (this.stage === SessionStage.Connected) {
            SessionToolbar({
              stage: this.stage,
              isFullscreen: this.isFullscreen,
              zoomScale: this.zoomScale,
              showNavigationPad: this.showNavigationPad,
              onZoomIn: (): void => {
                this.zoomInToken += 1;
                this.extendChromeInteractionIfVisible();
              },
              onZoomOut: (): void => {
                this.zoomOutToken += 1;
                this.extendChromeInteractionIfVisible();
              },
              onResetZoom: (): void => {
                this.zoomResetToken += 1;
                this.extendChromeInteractionIfVisible();
              },
              onToggleNavigationPad: (): void => {
                this.showNavigationPad = !this.showNavigationPad;
                if (this.showNavigationPad) {
                  this.ensureNavPadPosition();
                }
                this.extendChromeInteractionIfVisible();
              },
              onSendCtrlAltDel: this.onSendCtrlAltDel,
              onSendWindowsKey: this.onSendWindowsKey,
              onSendEscape: this.onSendEscape,
              onShowKeyboard: (): void => {
                this.keyboardRequestToken += 1;
              },
              onToggleFullscreen: (): void => {
                this.isFullscreen = !this.isFullscreen;
              },
              onDisconnect: this.onDisconnect
            })
            .onMouse(() => {})
            .onHover(() => {})
          }
        }
        .width('100%')
        .height('100%')
      } else {
        Column({ space: 5 }) {
          Blank().width(4).height(4).borderRadius(2).backgroundColor('rgba(231,229,228,0.90)')
          Blank().width(4).height(4).borderRadius(2).backgroundColor('rgba(231,229,228,0.35)')
          Blank().width(4).height(4).borderRadius(2).backgroundColor('rgba(231,229,228,0.35)')
        }
        .onClick(() => this.revealChrome())
        .onTouch((ev: TouchEvent) => {
          if (ev.type === TouchType.Down) this.revealChrome();
        })
        .padding({ top: 8, bottom: 8, left: 4, right: 4 })
        .backgroundColor('rgba(12,20,22,0.76)')
        .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
        .borderRadius({ topLeft: 12, bottomLeft: 12, topRight: 0, bottomRight: 0 })
        .position({ x: '100%', y: '50%' })
        .translate({ x: '-100%', y: '-50%' })
        .hitTestBehavior(HitTestMode.Default)
      }

      if (this.showNavigationPad && this.stage === SessionStage.Connected) {
        this.buildNavigationPad()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.background)
    .padding(this.isFullscreen ? 0 : 12)
    .clip(true)
    .animation({ duration: 300, curve: Curve.EaseIn })
  }

  @Builder
  private buildNavigationPad(): void {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        this.buildNavButton('−', () => {
          this.zoomOutToken += 1;
          this.extendChromeInteractionIfVisible();
        })
        this.buildNavButton('+', () => {
          this.zoomInToken += 1;
          this.extendChromeInteractionIfVisible();
        })
      }
      Blank().height(8)
      this.buildNavButton('▲', () => {
        this.panUpToken += 1;
        this.extendChromeInteractionIfVisible();
      })
      Row({ space: 52 }) {
        this.buildNavButton('◀', () => {
          this.panLeftToken += 1;
          this.extendChromeInteractionIfVisible();
        })
        this.buildNavButton('▶', () => {
          this.panRightToken += 1;
          this.extendChromeInteractionIfVisible();
        })
      }
      this.buildNavButton('▼', () => {
        this.panDownToken += 1;
        this.extendChromeInteractionIfVisible();
      })
    }
    .alignItems(HorizontalAlign.Center)
    .padding(12)
    .backgroundColor('rgba(12,20,22,0.5)')
    .borderRadius(20)
    .position({ x: this.navPadX, y: this.navPadY })
    .zIndex(9999)
    .hitTestBehavior(HitTestMode.Default)
    .onMouse(() => {})
    .onHover(() => {})
    .onTouch((ev: TouchEvent) => {
      if (ev.type === TouchType.Down) {
        this.navPadDragging = false;
        this.navPadDragStartX = ev.touches[0].x;
        this.navPadDragStartY = ev.touches[0].y;
      } else if (ev.type === TouchType.Move) {
        const dx = ev.touches[0].x - this.navPadDragStartX;
        const dy = ev.touches[0].y - this.navPadDragStartY;
        if (Math.abs(dx) + Math.abs(dy) > 8) {
          this.navPadDragging = true;
        }
        if (this.navPadDragging) {
          this.navPadX += dx;
          this.navPadY += dy;
          this.navPadDragStartX = ev.touches[0].x;
          this.navPadDragStartY = ev.touches[0].y;
        }
      } else if (ev.type === TouchType.Up || ev.type === TouchType.Cancel) {
        this.navPadDragging = false;
      }
    })
  }

  @Builder
  private buildNavButton(label: string, onTap: () => void): void {
    Button() {
      Text(label)
        .fontSize(20)
        .fontColor(Color.White)
    }
    .width(44)
    .height(44)
    .backgroundColor('rgba(255,255,255,0.15)')
    .borderRadius(12)
    .type(ButtonType.Normal)
    .enabled(this.stage === SessionStage.Connected)
    .onClick(onTap)
  }
}
