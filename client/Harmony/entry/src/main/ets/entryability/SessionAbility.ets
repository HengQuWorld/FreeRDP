import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { SessionRecord, sessionManager } from '../service/SessionManager';
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

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    logger.info(LogTags.SESSION_ABILITY, 'SessionAbility onCreate');
    
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
      windowStage.loadContent('pages/Session');
      logger.info(LogTags.SESSION_ABILITY, 'loadContent called for Session page');

      const ws = windowStage as WindowStageLike;
      const mainWin = ws.getMainWindowSync?.();

      const apply = (win: Object): void => {
        try {
          const w = win as WindowLike;
          w.setWindowTitle?.(this.sessionTitle);
          w.setWindowDecorVisible?.(true);
          logger.info(LogTags.SESSION_ABILITY, `Window configured - Title: ${this.sessionTitle}`);
        } catch (e) {
          logger.error(LogTags.SESSION_ABILITY, 'Failed to configure window', e);
        }
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

  onDestroy(): void {
    logger.info(LogTags.SESSION_ABILITY, `onDestroy - Session ID: ${this.sessionId}`);
    
    try {
      if (this.sessionId > 0) {
        const record: SessionRecord | undefined = sessionManager.getSession(this.sessionId);
        if (record !== undefined) {
          logger.info(LogTags.SESSION_ABILITY, `Disconnecting and removing session ${this.sessionId}`);
          void sessionManager.disconnect(this.sessionId);
          sessionManager.removeSession(this.sessionId);
        } else {
          logger.warn(LogTags.SESSION_ABILITY, `Session ${this.sessionId} not found during cleanup`);
        }
      }
    } catch (e) {
      logger.error(LogTags.SESSION_ABILITY, 'Failed to cleanup session', e);
    }
  }
}
