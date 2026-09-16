import { ThemeColors, LightColors, DarkColors } from '../utils/ThemeConstants';
import { i18n } from '../utils/I18n';

@CustomDialog
export struct ReviewPromptDialog {
  controller: CustomDialogController;
  @StorageLink('__app_is_dark_mode__') @Watch('onThemeChanged') isDark: boolean = false;
  @StorageLink('__app_language__') appLanguage: string = 'system';
  @State colors: ThemeColors = LightColors;
  onRate: () => void = () => {};
  onLater: () => void = () => {};
  onNeverAsk: () => void = () => {};

  onThemeChanged(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  aboutToAppear(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  build() {
    Column({ space: 14 }) {
      Text('★★★★★')
        .fontSize(20)
        .fontColor('#f5b301');

      Text(i18n.get(this.appLanguage, 'review_prompt_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.foreground)
        .textAlign(TextAlign.Center);

      Text(i18n.get(this.appLanguage, 'review_prompt_body'))
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.colors.mutedForeground)
        .textAlign(TextAlign.Center);

      Button(i18n.get(this.appLanguage, 'review_prompt_rate'))
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colors.primaryForeground)
        .backgroundColor(this.colors.primary)
        .borderRadius(12)
        .margin({ top: 6 })
        .onClick(() => {
          this.onRate();
          this.controller.close();
        });

      Row({ space: 8 }) {
        Button(i18n.get(this.appLanguage, 'review_prompt_later'))
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .fontColor(this.colors.mutedForeground)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.onLater();
            this.controller.close();
          });

        Button(i18n.get(this.appLanguage, 'review_prompt_never'))
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .fontColor(this.colors.mutedForeground)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.onNeverAsk();
            this.controller.close();
          });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);
    }
    .padding(24)
    .width('92%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.colors.card)
    .border({ width: 1, color: this.colors.cardBorder })
    .borderRadius(20)
    .shadow({ radius: 24, color: this.colors.shadowLg, offsetX: 0, offsetY: 8 });
  }
}
