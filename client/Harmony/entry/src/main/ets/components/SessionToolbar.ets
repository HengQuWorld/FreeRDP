import { SessionStage } from '../model/SessionModels';
import { i18n } from '../utils/I18n';
import { PressRepeat } from '../utils/PressRepeat';

const ZOOM_REPEAT_START_DELAY_MS: number = 300;
const ZOOM_REPEAT_INTERVAL_MS: number = 80;

@Component
export struct SessionToolbar {
  @Prop stage: SessionStage;
  @Prop isFullscreen: boolean = false;
  @StorageLink('__app_language__') appLanguage: string = 'system';
  onSendCtrlAltDel: () => void = (): void => {};
  onSendWindowsKey: () => void = (): void => {};
  onSendEscape: () => void = (): void => {};
  onShowKeyboard: () => void = (): void => {};
  onToggleFullscreen: () => void = (): void => {};
  onDisconnect: () => void = (): void => {};
  @Prop zoomScale: number = 1.0;
  onZoomIn: () => void = (): void => {};
  onZoomOut: () => void = (): void => {};
  onResetZoom: () => void = (): void => {};
  @Prop showNavigationPad: boolean = false;
  onToggleNavigationPad: () => void = (): void => {};
  private zoomInRepeat: PressRepeat = new PressRepeat(ZOOM_REPEAT_START_DELAY_MS, ZOOM_REPEAT_INTERVAL_MS);
  private zoomOutRepeat: PressRepeat = new PressRepeat(ZOOM_REPEAT_START_DELAY_MS, ZOOM_REPEAT_INTERVAL_MS);

  aboutToDisappear(): void {
    this.zoomInRepeat.stop();
    this.zoomOutRepeat.stop();
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.buildToolbarBtn(i18n.get(this.appLanguage, 'keyboard'), () => this.onShowKeyboard(), false)
        this.buildToolbarBtn('导航', () => this.onToggleNavigationPad(), this.showNavigationPad)
        this.buildToolbarBtn('Ctrl+Alt+Del', () => this.onSendCtrlAltDel(), false)
        this.buildToolbarBtn('Win', () => this.onSendWindowsKey(), false)
        this.buildToolbarBtn('Esc', () => this.onSendEscape(), false)
      }
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .backgroundColor('rgba(12,20,22,0.82)')
      .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
      .borderRadius(22)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetX: 0, offsetY: 6 })
      .constraintSize({ maxWidth: '100%' })

      Row({ space: 8 }) {
        this.buildZoomBtn('−', this.zoomOutRepeat, () => this.onZoomOut())
        this.buildToolbarBtn(`${Math.round(this.zoomScale * 100)}%`, () => this.onResetZoom(), this.zoomScale > 1.05)
        this.buildZoomBtn('+', this.zoomInRepeat, () => this.onZoomIn())
        this.buildToolbarBtn(this.isFullscreen ? i18n.get(this.appLanguage, 'exit_fullscreen') : i18n.get(this.appLanguage, 'fullscreen'), () => this.onToggleFullscreen(), false)
        Button(i18n.get(this.appLanguage, 'disconnect'))
          .type(ButtonType.Normal)
          .height(40)
          .constraintSize({ minWidth: 68 })
          .flexShrink(1)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#f87171')
          .backgroundColor('rgba(239,68,68,0.10)')
          .border({ width: 1, color: 'rgba(239,68,68,0.22)' })
          .borderRadius(16)
          .enabled(this.stage === SessionStage.Connected || this.stage === SessionStage.Connecting)
          .onClick(() => this.onDisconnect())
      }
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .backgroundColor('rgba(12,20,22,0.82)')
      .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
      .borderRadius(22)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetX: 0, offsetY: 6 })
      .constraintSize({ maxWidth: '100%' })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 12, right: 12 })
    .margin({ bottom: this.isFullscreen ? 12 : 24 })
  }

  // Zoom steps repeat while the key is held: pressing once must act at once,
  // and holding must keep going without a lift.
  @Builder
  private buildZoomBtn(label: string, repeat: PressRepeat, onStep: () => void): void {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#f5f5f4')
        .maxLines(1)
    }
    .height(40)
    .constraintSize({ minWidth: 68 })
    .flexShrink(1)
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
    .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
    .stateStyles({
      normal: { .backgroundColor('rgba(255,255,255,0.08)') },
      pressed: { .backgroundColor('rgba(255,255,255,0.28)') }
    })
    .enabled(this.stage === SessionStage.Connected)
    .opacity(this.stage === SessionStage.Connected ? 1 : 0.5)
    .onTouch((ev: TouchEvent) => {
      if (ev.type === TouchType.Down) {
        if (this.stage === SessionStage.Connected) {
          repeat.start(onStep);
        }
      } else if (ev.type === TouchType.Up || ev.type === TouchType.Cancel) {
        repeat.stop();
      }
    })
  }

  @Builder
  private buildToolbarBtn(label: string, onTap: () => void, active: boolean): void {
    Button(label)
      .type(ButtonType.Normal)
      .height(40)
      .constraintSize({ minWidth: 68 })
      .flexShrink(1)
      .fontSize(12)
      .fontColor(active ? '#ffffff' : '#f5f5f4')
      .backgroundColor(active ? 'rgba(34,160,107,0.85)' : 'rgba(255,255,255,0.08)')
      .border({ width: active ? 0 : 1, color: active ? 'rgba(34,160,107,0.85)' : 'rgba(255,255,255,0.12)' })
      .borderRadius(16)
      .enabled(this.stage === SessionStage.Connected)
      .opacity(this.stage === SessionStage.Connected ? 1 : 0.5)
      .onClick(onTap)
  }
}
