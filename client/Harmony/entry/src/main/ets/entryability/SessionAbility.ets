import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import { Configuration } from '@ohos.app.ability.Configuration';
import window from '@ohos.window';
import { SessionRecord, sessionManager } from '../service/SessionManager';
import { DARK_MODE_STORAGE_KEY, DarkColors, LightColors, syncSystemColorMode } from '../utils/ThemeConstants';
import { logger, LogTags } from '../utils/Logger';

interface WantLike {
  parameters?: Record<string, Object>;
}

interface UIAbilityContextWithWant {
  getWant?: () => WantLike;
  want?: WantLike;
  setMissionLabel?: (label: string) => Promise<void>;
}

interface WindowLike {
  setWindowTitle?: (t: string) => void;
  setWindowDecorVisible?: (visible: boolean) => void;
  setWindowBackgroundColor?: (color: string) => void;
}

interface WindowStageLike {
  getMainWindowSync?: () => Object;
  getMainWindow?: () => Promise<Object>;
}

export interface SessionLaunchParams {
  sessionId: number;
  title: string;
}

export const DEFAULT_SESSION_LAUNCH_PARAMS: SessionLaunchParams = {
  sessionId: 0,
  title: '远程桌面'
};

export default class SessionAbility extends UIAbility {
  private sessionId: number = 0;
  private sessionTitle: string = '远程桌面';
  private mainWindow: Object | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    logger.info(LogTags.SESSION_ABILITY, 'SessionAbility onCreate');

    syncSystemColorMode(this.context.config.colorMode);

    try {
      const params = want?.parameters ?? {};
      this.sessionId = Number(
        (params['sessionId'] !== undefined && params['sessionId'] !== null)
          ? String(params['sessionId']) : '0'
      );
      this.sessionTitle =
        (params['title'] !== undefined && params['title'] !== null)
          ? String(params['title']) : '远程桌面';

      logger.info(LogTags.SESSION_ABILITY, `Session params - ID: ${this.sessionId}, Title: ${this.sessionTitle}`);

      const ctx = this.context as UIAbilityContextWithWant;
      ctx.setMissionLabel?.(this.sessionTitle);

      AppStorage.setOrCreate<SessionLaunchParams>('__session_launch_bridge__', {
        sessionId: this.sessionId,
        title: this.sessionTitle
      });
    } catch (e) {
      logger.error(LogTags.SESSION_ABILITY, 'Failed to parse session parameters', e);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    logger.info(LogTags.SESSION_ABILITY, 'onWindowStageCreate');
    
    try {
      windowStage.loadContent('pages/Session', (error: Error | undefined) => {
        if (error !== undefined) {
          logger.error(LogTags.SESSION_ABILITY, `loadContent failed: ${JSON.stringify(error)}`);
        }
        this.applyWindowBackground();
      });
      logger.info(LogTags.SESSION_ABILITY, 'loadContent called for Session page');

      const ws = windowStage as WindowStageLike;
      const mainWin = ws.getMainWindowSync?.();

      const apply = (win: Object): void => {
        this.mainWindow = win;
        const w = win as WindowLike;
        // The title is part of the session identity: losing it is a real fault.
        try {
          w.setWindowTitle?.(this.sessionTitle);
        } catch (e) {
          logger.error(LogTags.SESSION_ABILITY, 'Failed to set the window title', e);
        }
        // Changing the window chrome can be refused while the window is still
        // being created. That used to be logged as "Failed to configure window",
        // which reads like a broken session and pushed real failures down the
        // log ring buffer.
        try {
          w.setWindowDecorVisible?.(true);
        } catch (_e) {
          logger.info(LogTags.SESSION_ABILITY,
            'Window chrome not adjustable yet, keeping the default decoration');
        }
        logger.info(LogTags.SESSION_ABILITY, `Window configured - Title: ${this.sessionTitle}`);
      };

      if (mainWin) {
        apply(mainWin);
      } else {
        ws.getMainWindow?.()
          .then((win: Object): void => apply(win))
          .catch((e: Error): void => {
            logger.error(LogTags.SESSION_ABILITY, 'Failed to get main window asynchronously', e);
          });
      }
    } catch (e) {
      logger.error(LogTags.SESSION_ABILITY, 'Failed in onWindowStageCreate', e);
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark: boolean = syncSystemColorMode(newConfig.colorMode);
    logger.info(LogTags.SESSION_ABILITY,
      `System color mode changed: ${newConfig.colorMode}, dark=${isDark}`);
    this.applyWindowBackground();
  }

  private applyWindowBackground(): void {
    const dark: boolean = AppStorage.get<boolean>(DARK_MODE_STORAGE_KEY) === true;
    const background: string = (dark ? DarkColors : LightColors).background;
    try {
      (this.mainWindow as WindowLike)?.setWindowBackgroundColor?.(background);
    } catch (e) {
      logger.error(LogTags.SESSION_ABILITY, 'Failed to set window background', e);
    }
  }

  onDestroy(): void {
    logger.info(LogTags.SESSION_ABILITY, `onDestroy - Session ID: ${this.sessionId}`);
    
    try {
      if (this.sessionId > 0) {
        const record: SessionRecord | undefined = sessionManager.getSession(this.sessionId);
        if (record !== undefined) {
          logger.info(LogTags.SESSION_ABILITY, `Disconnecting and removing session ${this.sessionId}`);
          // Order matters: the record must outlive the native teardown. Dropping
          // it first let getSession() return undefined while the native session
          // was still shutting down, which surfaced as "session not found".
          void sessionManager.disconnectAndRemove(this.sessionId);
        } else {
          logger.warn(LogTags.SESSION_ABILITY, `Session ${this.sessionId} not found during cleanup`);
        }
      }
    } catch (e) {
      logger.error(LogTags.SESSION_ABILITY, 'Failed to cleanup session', e);
    }
  }
}
