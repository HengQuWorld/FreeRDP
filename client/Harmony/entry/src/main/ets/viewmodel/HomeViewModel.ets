import { ConnectionProfile, createEmptyProfile, cloneProfile } from '../model/ConnectionProfile';
import { BookmarkService } from '../service/BookmarkService';
import { IdGenerator } from '../utils/IdGenerator';
import { i18n } from '../utils/I18n';
import { logger, LogTags } from '../utils/Logger';
import common from '@ohos.app.ability.common';

@Observed
export class HomeViewModel {
  profile: ConnectionProfile;
  bookmarks: ConnectionProfile[] = [];
  lastMessage: string = i18n.get(i18n.currentLocale(), 'waiting_connect');
  private isEditingBookmark: boolean = false;

  private bookmarkService: BookmarkService = new BookmarkService();
  private context: common.UIAbilityContext | null = null;

  constructor() {
    this.profile = createEmptyProfile(IdGenerator.next('profile'));
    this.bookmarks = [];
  }

  private copyProfile(profile: ConnectionProfile): ConnectionProfile {
    return cloneProfile(profile);
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    logger.info(LogTags.HOME_VIEWMODEL, 'Initializing HomeViewModel');
    this.context = context;
    
    try {
      const fallbackId: string = this.profile.id.length > 0 ? this.profile.id : IdGenerator.next('profile');
      this.profile = await this.bookmarkService.loadDraft(context, fallbackId);
      this.bookmarks = await this.bookmarkService.list(context);
      logger.info(LogTags.HOME_VIEWMODEL, `Loaded ${this.bookmarks.length} bookmarks`);
    } catch (e) {
      logger.error(LogTags.HOME_VIEWMODEL, 'Failed to initialize bookmarks', e);
      this.lastMessage = i18n.get(i18n.currentLocale(), 'error.bookmark_load_failed');
    }
  }

  private persistDraft(): void {
    const context = this.context;
    if (context === null) {
      return;
    }
    void this.bookmarkService.saveDraft(context, this.profile);
  }

  updateName(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.name = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  tryApplyCertificateName(certCommonName: string): void {
    if (certCommonName.length === 0) {
      return;
    }

    const isAutoName: boolean = this.profile.name.length === 0 ||
      this.profile.name === this.profile.host;
    if (!isAutoName) {
      return;
    }

    this.updateName(certCommonName);

    if (this.isEditingBookmark) {
      void this.saveCurrentProfile();
    }
  }

  updateHost(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.host = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updatePort(value: string): void {
    const parsed: number = Number(value);
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.port = Number.isFinite(parsed) && parsed > 0 ? parsed : 3389;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updateUsername(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.username = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updateDomain(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.domain = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updatePassword(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.password = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  toggleRememberPassword(value: boolean): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.rememberPassword = value;
    if (!value) {
      nextProfile.password = '';
    }
    this.profile = nextProfile;
    this.persistDraft();
  }

  updateGateway(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.gateway = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updateGatewayUsername(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.gatewayUsername = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updateGatewayPassword(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.gatewayPassword = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updateGatewayDomain(value: string): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.gatewayDomain = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  toggleClipboard(value: boolean): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.enableClipboard = value;
    this.profile = nextProfile;
    this.persistDraft();
  }

  updateResolution(width: number, height: number): void {
    const nextProfile: ConnectionProfile = this.copyProfile(this.profile);
    nextProfile.desktopWidth = width;
    nextProfile.desktopHeight = height;
    this.profile = nextProfile;
    this.persistDraft();
  }

  createNewProfile(): void {
    this.profile = createEmptyProfile(IdGenerator.next('profile'));
    this.isEditingBookmark = false;
    this.persistDraft();
  }

  async deleteBookmark(profileId: string): Promise<void> {
    if (this.context === null) {
      logger.warn(LogTags.HOME_VIEWMODEL, 'Context is null, cannot delete bookmark');
      return;
    }
    
    try {
      logger.info(LogTags.HOME_VIEWMODEL, `Deleting bookmark: ${profileId}`);
      await this.bookmarkService.delete(this.context, profileId);
      this.bookmarks = await this.bookmarkService.list(this.context);
      this.lastMessage = i18n.get(i18n.currentLocale(), 'bookmark_deleted');
      logger.info(LogTags.HOME_VIEWMODEL, 'Bookmark deleted successfully');
    } catch (e) {
      logger.error(LogTags.HOME_VIEWMODEL, 'Failed to delete bookmark', e);
      this.lastMessage = i18n.get(i18n.currentLocale(), 'error.bookmark_delete_failed');
    }
  }

  applyBookmark(profile: ConnectionProfile): void {
    this.profile = this.copyProfile(profile);
    this.isEditingBookmark = true;
    this.persistDraft();
    this.lastMessage = `${i18n.get(i18n.currentLocale(), 'loaded_profile_prefix')} ${profile.name}`;
  }

  get canConnect(): boolean {
    return this.profile.host.trim().length > 0 && this.profile.username.trim().length > 0;
  }

  async saveCurrentProfile(): Promise<void> {
    const context = this.context;
    if (context === null) {
      logger.warn(LogTags.HOME_VIEWMODEL, 'Context is null, cannot save bookmark');
      this.lastMessage = i18n.get(i18n.currentLocale(), 'bookmark_service_not_initialized');
      return;
    }
    
    try {
      logger.info(LogTags.HOME_VIEWMODEL, `Saving bookmark: ${this.profile.name}`);
      const saved: ConnectionProfile = this.copyProfile(this.profile);
      saved.id = this.isEditingBookmark ? this.profile.id : IdGenerator.next('bookmark');
      saved.name = this.profile.name.length > 0 ? this.profile.name : this.profile.host;
      await this.bookmarkService.save(context, saved);
      this.isEditingBookmark = true;
      this.bookmarks = await this.bookmarkService.list(context);
      this.profile = this.copyProfile(saved);
      this.persistDraft();
      this.lastMessage = i18n.get(i18n.currentLocale(), 'bookmark_saved');
      logger.info(LogTags.HOME_VIEWMODEL, 'Bookmark saved successfully');
    } catch (e) {
      logger.error(LogTags.HOME_VIEWMODEL, 'Failed to save bookmark', e);
      this.lastMessage = i18n.get(i18n.currentLocale(), 'error.bookmark_save_failed');
    }
  }
}
