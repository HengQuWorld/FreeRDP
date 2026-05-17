import { SessionStage } from '../model/SessionModels';
import { i18n } from '../utils/I18n';

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
        this.buildToolbarBtn('−', () => this.onZoomOut(), false)
        this.buildToolbarBtn(`${Math.round(this.zoomScale * 100)}%`, () => this.onResetZoom(), this.zoomScale > 1.05)
        this.buildToolbarBtn('+', () => this.onZoomIn(), false)
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
