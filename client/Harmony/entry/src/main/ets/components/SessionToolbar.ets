import { SessionStage } from '../model/SessionModels';

@Component
export struct SessionToolbar {
  @Prop stage: SessionStage;
  @Prop isFullscreen: boolean = false;
  onSendCtrlAltDel: () => void = (): void => {};
  onSendWindowsKey: () => void = (): void => {};
  onSendEscape: () => void = (): void => {};
  onShowKeyboard: () => void = (): void => {};
  onToggleFullscreen: () => void = (): void => {};
  onDisconnect: () => void = (): void => {};

  build() {
    Row({ space: 8 }) {
      Scroll() {
        Row({ space: 8 }) {
          Button(this.isFullscreen ? '退出全屏' : '全屏')
            .type(ButtonType.Normal)
            .enabled(this.stage === SessionStage.Connected)
            .onClick(() => this.onToggleFullscreen())

          Button('键盘')
            .type(ButtonType.Normal)
            .enabled(this.stage === SessionStage.Connected)
            .onClick(() => this.onShowKeyboard())

        Button('Ctrl+Alt+Del')
          .type(ButtonType.Normal)
          .enabled(this.stage === SessionStage.Connected)
          .onClick(() => this.onSendCtrlAltDel())

        Button('Win')
          .type(ButtonType.Normal)
          .enabled(this.stage === SessionStage.Connected)
          .onClick(() => this.onSendWindowsKey())

        Button('Esc')
          .type(ButtonType.Normal)
          .enabled(this.stage === SessionStage.Connected)
          .onClick(() => this.onSendEscape())

        Button('断开')
          .type(ButtonType.Capsule)
          .enabled(this.stage === SessionStage.Connected || this.stage === SessionStage.Connecting)
          .onClick(() => this.onDisconnect())
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    .backgroundColor('rgba(12,20,22,0.82)')
    .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
    .borderRadius(22)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetX: 0, offsetY: 6 })
  }
}
