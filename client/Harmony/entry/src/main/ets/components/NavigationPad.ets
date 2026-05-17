import { SessionStage } from '../model/SessionModels';
import { ThemeColors, LightColors, DarkColors } from '../utils/ThemeConstants';

@Component
export struct NavigationPad {
  @Prop stage: SessionStage;
  @Prop visible: boolean = false;
  @Prop viewerWidth: number = 0;
  @Prop viewerHeight: number = 0;
  @StorageLink('__app_is_dark_mode__') @Watch('onThemeChanged') isDark: boolean = false;
  @State colors: ThemeColors = LightColors;
  @State private navVisible: boolean = false;

  onZoomIn: () => void = (): void => {};
  onZoomOut: () => void = (): void => {};
  onPanUp: () => void = (): void => {};
  onPanDown: () => void = (): void => {};
  onPanLeft: () => void = (): void => {};
  onPanRight: () => void = (): void => {};

  private navTimers: Record<string, number> = {};

  onThemeChanged(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  aboutToAppear(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
    this.navVisible = this.visible && this.stage === SessionStage.Connected;
  }

  aboutToDisappear(): void {
    const keys: string[] = ['up', 'down', 'left', 'right', 'zoomIn', 'zoomOut'];
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (this.navTimers[key] > 0) {
        clearInterval(this.navTimers[key]);
        this.navTimers[key] = 0;
      }
    }
  }

  private handleNavAction(action: 'up' | 'down' | 'left' | 'right' | 'zoomIn' | 'zoomOut'): void {
    if (this.stage !== SessionStage.Connected) return;

    if (action === 'zoomIn') {
      this.onZoomIn();
    } else if (action === 'zoomOut') {
      this.onZoomOut();
    } else if (action === 'up') {
      this.onPanUp();
    } else if (action === 'down') {
      this.onPanDown();
    } else if (action === 'left') {
      this.onPanLeft();
    } else if (action === 'right') {
      this.onPanRight();
    }
  }

  @Builder
  private buildNavButton(action: 'up' | 'down' | 'left' | 'right' | 'zoomIn' | 'zoomOut') {
    Button() {
      Text(this.getNavLabel(action))
        .fontSize(20)
        .fontColor(Color.White)
    }
    .width(44)
    .height(44)
    .backgroundColor('rgba(255,255,255,0.08)')
    .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
    .borderRadius(14)
    .type(ButtonType.Normal)
    .enabled(this.stage === SessionStage.Connected)
    .onTouch((ev: TouchEvent) => {
      if (ev.type === TouchType.Down) {
        this.handleNavAction(action);
        this.navTimers[action] = setInterval(() => {
          this.handleNavAction(action);
        }, 100);
      } else if (ev.type === TouchType.Up || ev.type === TouchType.Cancel) {
        if (this.navTimers[action]) {
          clearInterval(this.navTimers[action]);
          this.navTimers[action] = 0;
        }
      }
    })
  }

  private getNavLabel(action: 'up' | 'down' | 'left' | 'right' | 'zoomIn' | 'zoomOut'): string {
    switch (action) {
      case 'up': return '▲';
      case 'down': return '▼';
      case 'left': return '◀';
      case 'right': return '▶';
      case 'zoomIn': return '+';
      case 'zoomOut': return '−';
    }
  }

  build() {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        this.buildNavButton('zoomOut')
        this.buildNavButton('zoomIn')
      }
      Blank().height(8)
      this.buildNavButton('up')
      Row({ space: 52 }) {
        this.buildNavButton('left')
        this.buildNavButton('right')
      }
      this.buildNavButton('down')
    }
    .alignItems(HorizontalAlign.Center)
    .padding(12)
    .backgroundColor('rgba(12,20,22,0.82)')
    .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
    .borderRadius(20)
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.3)', offsetX: 0, offsetY: 4 })
    .position({
      x: 16,
      y: 200
    })
    .width(152)
    .visibility(this.visible && this.stage === SessionStage.Connected ? Visibility.Visible : Visibility.None)
    .zIndex(9999)
    .hitTestBehavior(HitTestMode.Default)
  }
}
