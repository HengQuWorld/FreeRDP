import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { sessionWindowManager } from '../service/SessionWindowManager';
import { DARK_MODE_STORAGE_KEY, DarkColors, LightColors, syncSystemColorMode } from '../utils/ThemeConstants';
import { i18n } from '../utils/I18n';
import { logger, LogTags } from '../utils/Logger';

interface WindowLike {
  setWindowTitle?: (t: string) => void;
  setWindowBackgroundColor?: (color: string) => void;
}

interface WindowStageLike {
  getMainWindowSync?: () => Object;
  getMainWindow?: () => Promise<Object>;
}

export default class EntryAbility extends UIAbility {
  private mainWindow: Object | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    logger.info(LogTags.ENTRY_ABILITY, 'EntryAbility onCreate');

    // The ability keeps the default COLOR_MODE_NOT_SET, so the system drives
    // both the theme resources and the window decoration. Only the rendering
    // state has to learn which way the system went.
    const isDark: boolean = syncSystemColorMode(this.context.config.colorMode);
    logger.info(LogTags.ENTRY_ABILITY,
      `System color mode: ${this.context.config.colorMode}, dark=${isDark}`);

    AppStorage.setOrCreate('__app_context__', this.context);
    i18n.init(this.context);
    AppStorage.setOrCreate('appName', i18n.get(i18n.currentLocale(), 'app_title'));
    AppStorage.setOrCreate('preferredInputMode', 'touchpad');
    AppStorage.setOrCreate('showBookmarksFirst', true);
    AppStorage.setOrCreate('bookmarkPayload', '');
    AppStorage.setOrCreate('draftProfilePayload', '');
    AppStorage.setOrCreate<number>('activeSessionId', 0);
    PersistentStorage.persistProp('bookmarkPayload', '');
    PersistentStorage.persistProp('draftProfilePayload', '');

    i18n.onLanguageChanged((_code: string) => {
      this.applyWindowTitle();
    });

    try {
      sessionWindowManager.initialize(this.context);
      logger.info(LogTags.ENTRY_ABILITY, 'SessionWindowManager initialized');
    } catch (e) {
      logger.error(LogTags.ENTRY_ABILITY, 'Failed to initialize SessionWindowManager', e);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    logger.info(LogTags.ENTRY_ABILITY, 'onWindowStageCreate');

    try {
      const ws = windowStage as WindowStageLike;
      const mainWin = ws.getMainWindowSync?.();
      if (mainWin) {
        this.mainWindow = mainWin;
        this.applyWindowTitle();
        logger.info(LogTags.ENTRY_ABILITY, 'Main window obtained');
      }
    } catch (e) {
      logger.error(LogTags.ENTRY_ABILITY, 'Failed to get main window', e);
    }

    windowStage.loadContent('pages/Index', (error: Error | undefined) => {
      const serializedError: string | undefined = JSON.stringify(error);
      if (error !== undefined && serializedError !== undefined &&
          serializedError.indexOf('"code":0') < 0) {
        logger.error(LogTags.ENTRY_ABILITY, `loadContent failed: ${serializedError}`);
      } else {
        logger.info(LogTags.ENTRY_ABILITY, 'loadContent succeeded');
      }
      this.applyWindowBackground();
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark: boolean = syncSystemColorMode(newConfig.colorMode);
    logger.info(LogTags.ENTRY_ABILITY,
      `System color mode changed: ${newConfig.colorMode}, dark=${isDark}`);
    this.applyWindowBackground();
  }

  /**
   * Paints the window surface itself in the current theme color, so the frame
   * behind the page never flashes white while content renders. The window
   * decoration is drawn by the system and cannot be recolored from a
   * third-party app; it follows the system dark/light setting on its own.
   */
  private applyWindowBackground(): void {
    const dark: boolean = AppStorage.get<boolean>(DARK_MODE_STORAGE_KEY) === true;
    const background: string = (dark ? DarkColors : LightColors).background;
    try {
      (this.mainWindow as WindowLike)?.setWindowBackgroundColor?.(background);
    } catch (e) {
      logger.error(LogTags.ENTRY_ABILITY, 'Failed to set window background', e);
    }
  }

  private applyWindowTitle(): void {
    try {
      const title = AppStorage.get<string>('appName') ?? '碧虎远程桌面';
      const w = this.mainWindow as WindowLike;
      w?.setWindowTitle?.(title);
      logger.debug(LogTags.ENTRY_ABILITY, `Window title set to: ${title}`);
    } catch (e) {
      logger.error(LogTags.ENTRY_ABILITY, 'Failed to apply window title', e);
    }
  }

  onDestroy(): void {
  }
}
