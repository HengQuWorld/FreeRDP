import { i18n } from '../utils/I18n';
import { ThemeColors, LightColors, DarkColors } from '../utils/ThemeConstants';
import { LanguagePicker } from './LanguagePicker';

@Component
export struct LanguageToggle {
  @StorageLink('__app_language__') appLanguage: string = 'system';
  @StorageLink('__app_is_dark_mode__') @Watch('onThemeChanged') isDark: boolean = false;
  @State colors: ThemeColors = LightColors;

  private dialogController: CustomDialogController = new CustomDialogController({
    builder: LanguagePicker({
      onSelect: (code: string) => {
        i18n.setLanguage(code);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  onThemeChanged(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  aboutToAppear(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  build() {
    Button(this.displayLabel())
      .type(ButtonType.Circle)
      .width(36)
      .height(36)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.colors.accentForeground)
      .backgroundColor(this.colors.accent)
      .onClick(() => {
        this.dialogController.open();
      })
  }

  private displayLabel(): string {
    if (this.appLanguage === 'system') {
      return '🌐';
    }
    if (this.appLanguage === 'zh-CN') {
      return '中';
    }
    return 'EN';
  }
}
