import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { commentManager } from '@kit.AppGalleryKit';
import dataPreferences from '@ohos.data.preferences';
import { logger, LogTags } from '../utils/Logger';

const PREFS_STORE_NAME: string = 'freerdp_store';
const KEY_SUCCESS_COUNT: string = 'review_success_count';
const KEY_PROMPT_COUNT: string = 'review_prompt_count';
const KEY_LAST_PROMPT_AT: string = 'review_last_prompt_at';
const KEY_REVIEW_DONE: string = 'review_done';
const KEY_NEVER_ASK: string = 'review_never_ask';

/** 至少成功使用（连接并进入桌面）该次数后才主动促评 */
const MIN_SUCCESS_COUNT: number = 3;
/** 两次主动促评之间的最小间隔，避免打扰 */
const PROMPT_COOLDOWN_MS: number = 30 * 24 * 60 * 60 * 1000;
/** 主动促评的最大次数 */
const MAX_PROMPT_COUNT: number = 3;
/** 兜底包名，正常情况从 context 读取 */
const BUNDLE_NAME_FALLBACK: string = 'com.hengqutiandi.rdpclient';
const APP_DETAIL_ACTION: string = 'ohos.want.action.appdetail';
const STORE_DEEP_LINK_PREFIX: string = 'store://appgallery.huawei.com/app/detail?id=';
const STORE_APP_LINK_PREFIX: string = 'https://appgallery.huawei.com/app/detail?id=';

/** 用户已评价过当前版本 */
const ERR_COMMENTED_CURRENT_VERSION: number = 1021500007;
/** 评论数量已达上限 */
const ERR_COMMENT_LIMIT_REACHED: number = 1021500008;
/** 距上次评论不足一年 */
const ERR_COMMENTED_WITHIN_ONE_YEAR: number = 1021500009;
/** 用户未登录华为账号 */
const ERR_NOT_SIGNED_IN: number = 1021500006;

export enum ReviewRequestResult {
  /** 系统评价弹窗已拉起 */
  Shown = 0,
  /** 已经评价过，无需重复评价 */
  AlreadyReviewed = 1,
  /** 当前环境不支持应用内评价（未登录华为账号等） */
  Unavailable = 2,
  /** 拉起失败 */
  Failed = 3,
  /** 评论数量已达上限（临时限制，不视为已评价） */
  LimitReached = 4
}

class AppReviewServiceImpl {
  private context: common.UIAbilityContext | null = null;
  private preferences: dataPreferences.Preferences | null = null;
  private loaded: boolean = false;
  private successCount: number = 0;
  private promptCount: number = 0;
  private lastPromptAt: number = 0;
  private reviewDone: boolean = false;
  private neverAsk: boolean = false;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    await this.ensureLoaded();
  }

  /**
   * 记录一次成功的远程桌面使用，用于判断用户是否已真正用起来，适合引导评价。
   */
  async notifySuccessfulConnection(): Promise<void> {
    await this.ensureLoaded();
    this.successCount += 1;
    await this.saveValue(KEY_SUCCESS_COUNT, this.successCount);
  }

  /**
   * 是否应该向用户展示主动促评弹窗。
   */
  async shouldPrompt(): Promise<boolean> {
    await this.ensureLoaded();
    if (this.reviewDone || this.neverAsk) {
      return false;
    }
    if (this.successCount < MIN_SUCCESS_COUNT || this.promptCount >= MAX_PROMPT_COUNT) {
      return false;
    }
    return Date.now() - this.lastPromptAt >= PROMPT_COOLDOWN_MS;
  }

  async markPromptShown(): Promise<void> {
    await this.ensureLoaded();
    this.promptCount += 1;
    this.lastPromptAt = Date.now();
    await this.saveValue(KEY_PROMPT_COUNT, this.promptCount);
    await this.saveValue(KEY_LAST_PROMPT_AT, this.lastPromptAt);
  }

  async markNeverAsk(): Promise<void> {
    await this.ensureLoaded();
    this.neverAsk = true;
    await this.saveValue(KEY_NEVER_ASK, true);
  }

  /**
   * 拉起华为应用市场提供的应用内评价弹窗（无需跳转应用市场）。
   * 注意：弹窗由应用市场客户端负责提交，应用侧拿不到“是否已提交成功”的回执，
   * 因此只有应用市场返回明确的“已评价”错误码时才记录为已完成。
   */
  async requestInAppReview(): Promise<ReviewRequestResult> {
    const ctx: common.UIAbilityContext | null = this.resolveContext();
    if (ctx === null) {
      return ReviewRequestResult.Unavailable;
    }

    try {
      await commentManager.showCommentDialog(ctx);
      logger.info(LogTags.APP_REVIEW, 'In-app review dialog shown');
      return ReviewRequestResult.Shown;
    } catch (e) {
      const code: number = (e as BusinessError).code;
      logger.warn(LogTags.APP_REVIEW, `showCommentDialog failed, code: ${code}, message: ${(e as BusinessError).message}`);
      if (code === ERR_COMMENTED_CURRENT_VERSION || code === ERR_COMMENTED_WITHIN_ONE_YEAR) {
        await this.markReviewDone();
        return ReviewRequestResult.AlreadyReviewed;
      }
      if (code === ERR_COMMENT_LIMIT_REACHED) {
        return ReviewRequestResult.LimitReached;
      }
      return code === ERR_NOT_SIGNED_IN ? ReviewRequestResult.Unavailable : ReviewRequestResult.Failed;
    }
  }

  /**
   * 跳转应用市场写评论页，作为应用内评价弹窗不可用时的兜底路径。
   */
  async openStoreReviewPage(): Promise<boolean> {
    const ctx: common.UIAbilityContext | null = this.resolveContext();
    if (ctx === null) {
      return false;
    }

    const bundleName: string = this.resolveBundleName(ctx);
    const want: Want = {
      action: APP_DETAIL_ACTION,
      uri: `${STORE_DEEP_LINK_PREFIX}${bundleName}&action=write-review`
    };

    try {
      await ctx.startAbility(want);
      return true;
    } catch (e) {
      logger.warn(LogTags.APP_REVIEW, `Failed to open AppGallery via deep link: ${(e as BusinessError).message}`);
    }

    try {
      await ctx.openLink(`${STORE_APP_LINK_PREFIX}${bundleName}&action=write-review`,
        { appLinkingOnly: false });
      return true;
    } catch (e) {
      logger.error(LogTags.APP_REVIEW, 'Failed to open AppGallery review page', e);
      return false;
    }
  }

  private async markReviewDone(): Promise<void> {
    await this.ensureLoaded();
    this.reviewDone = true;
    await this.saveValue(KEY_REVIEW_DONE, true);
  }

  private resolveContext(): common.UIAbilityContext | null {
    if (this.context !== null) {
      return this.context;
    }
    const stored: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('__app_context__');
    if (stored !== undefined) {
      this.context = stored;
      return stored;
    }
    return null;
  }

  private resolveBundleName(ctx: common.UIAbilityContext): string {
    try {
      const name: string = ctx.abilityInfo.bundleName;
      return name.length > 0 ? name : BUNDLE_NAME_FALLBACK;
    } catch (_e) {
      return BUNDLE_NAME_FALLBACK;
    }
  }

  private async ensureLoaded(): Promise<void> {
    if (this.loaded) {
      return;
    }
    const pref: dataPreferences.Preferences | null = await this.getPreferences();
    if (pref === null) {
      return;
    }
    try {
      this.successCount = (await pref.get(KEY_SUCCESS_COUNT, 0)) as number;
      this.promptCount = (await pref.get(KEY_PROMPT_COUNT, 0)) as number;
      this.lastPromptAt = (await pref.get(KEY_LAST_PROMPT_AT, 0)) as number;
      this.reviewDone = (await pref.get(KEY_REVIEW_DONE, false)) as boolean;
      this.neverAsk = (await pref.get(KEY_NEVER_ASK, false)) as boolean;
      this.loaded = true;
    } catch (e) {
      logger.error(LogTags.APP_REVIEW, 'Failed to load review preferences', e);
    }
  }

  private async getPreferences(): Promise<dataPreferences.Preferences | null> {
    if (this.preferences !== null) {
      return this.preferences;
    }
    const ctx: common.UIAbilityContext | null = this.resolveContext();
    if (ctx === null) {
      return null;
    }
    try {
      this.preferences = await dataPreferences.getPreferences(ctx, { name: PREFS_STORE_NAME });
      return this.preferences;
    } catch (e) {
      logger.error(LogTags.APP_REVIEW, 'Failed to open preferences store', e);
      return null;
    }
  }

  private async saveValue(key: string, value: number | boolean): Promise<void> {
    const pref: dataPreferences.Preferences | null = await this.getPreferences();
    if (pref === null) {
      return;
    }
    try {
      await pref.put(key, value);
      await pref.flush();
    } catch (e) {
      logger.error(LogTags.APP_REVIEW, `Failed to persist review state: ${key}`, e);
    }
  }
}

export const appReviewService: AppReviewServiceImpl = new AppReviewServiceImpl();
