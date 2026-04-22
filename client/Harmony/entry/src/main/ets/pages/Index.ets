import { ConnectionForm } from '../components/ConnectionForm';
import { BookmarkList } from '../components/BookmarkList';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State homeViewModel: HomeViewModel = new HomeViewModel();
  @State pageWidth: number = 1280;

  private isPhoneLayout(): boolean {
    return this.pageWidth < 840;
  }

  private isTabletLayout(): boolean {
    return this.pageWidth >= 840 && this.pageWidth < 1440;
  }

  private layoutSpacing(): number {
    return this.isPhoneLayout() ? 16 : 24;
  }

  private horizontalPadding(): number {
    if (this.isPhoneLayout()) {
      return 16;
    }
    if (this.isTabletLayout()) {
      return 24;
    }
    return 32;
  }

  private contentMaxWidth(): number {
    if (this.isPhoneLayout()) {
      return 960;
    }
    return 800;
  }

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void this.homeViewModel.initialize(context);
  }

  build() {
    Navigation() {
      Scroll() {
        Column() {
          Column({ space: this.layoutSpacing() }) {
            Row() {
              Column() {
                Text('碧虎远程桌面')
                  .fontSize(this.isPhoneLayout() ? 26 : 36)
                  .fontWeight(FontWeight.Bold)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('HarmonyOS')
                .fontSize(12)
                .fontColor('#1D4ED8')
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor('#DBEAFE')
                .borderRadius(999)
            }
            .alignItems(VerticalAlign.Top)

            Column({ space: 16 }) {
              Column({ space: 12 }) {
                Text('连接工作台')
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#111827')
                  .alignSelf(ItemAlign.Start)
              }
              .padding(24)
              .backgroundColor('#FFFFFF')
              .borderRadius(24)
              .shadow({ radius: 32, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 8 })

              Column({ space: 16 }) {
                ConnectionForm({
                  profile: this.homeViewModel.profile,
                  rememberPassword: this.homeViewModel.profile.rememberPassword,
                  onNameChange: (value: string) => this.homeViewModel.updateName(value),
                  onHostChange: (value: string) => this.homeViewModel.updateHost(value),
                  onPortChange: (value: string) => this.homeViewModel.updatePort(value),
                  onUserChange: (value: string) => this.homeViewModel.updateUsername(value),
                  onDomainChange: (value: string) => this.homeViewModel.updateDomain(value),
                  onPasswordChange: (value: string) => this.homeViewModel.updatePassword(value),
                  onRememberPasswordChange: (value: boolean) => this.homeViewModel.toggleRememberPassword(value),
                  onGatewayChange: (value: string) => this.homeViewModel.updateGateway(value),
                  onGatewayUserChange: (value: string) => this.homeViewModel.updateGatewayUsername(value),
                  onGatewayPasswordChange: (value: string) => this.homeViewModel.updateGatewayPassword(value),
                  onGatewayDomainChange: (value: string) => this.homeViewModel.updateGatewayDomain(value),
                  onSecurityModeChange: (value: string) => this.homeViewModel.updateSecurityMode(value),
                  onClipboardChange: (value: boolean) => this.homeViewModel.toggleClipboard(value),
                  onNew: () => { this.homeViewModel.createNewProfile(); },
                  onSave: () => { void this.homeViewModel.saveCurrentProfile(); },
                  canConnect: this.homeViewModel.canConnect,
                  onConnect: async () => {
                    const profile = this.homeViewModel.profile;
                    this.homeViewModel.lastMessage = '正在连接远程桌面...';
                    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
                    AppStorage.setOrCreate<string>('sessionWantPayload', JSON.stringify({
                      id: profile.id,
                      name: profile.name,
                      host: profile.host,
                      port: profile.port,
                      clientHostname: profile.clientHostname.length > 0
                        ? profile.clientHostname
                        : context.abilityInfo.bundleName,
                      username: profile.username,
                      password: profile.password,
                      rememberPassword: profile.rememberPassword,
                      domain: profile.domain,
                      gateway: profile.gateway,
                      gatewayUsername: profile.gatewayUsername,
                      gatewayPassword: profile.gatewayPassword,
                      gatewayDomain: profile.gatewayDomain,
                      securityMode: profile.securityMode,
                      appDataDir: context.filesDir,
                      enableClipboard: profile.enableClipboard,
                      enableAudio: profile.enableAudio,
                      enableDrive: profile.enableDrive
                    }));
                    try {
                      router.pushUrl({ url: 'pages/Session' });
                    } catch (e) {
                      this.homeViewModel.lastMessage = '启动连接失败: ' + (e as Error).message;
                    }
                  }
                })

                BookmarkList({
                  items: this.homeViewModel.bookmarks,
                  onSelect: (profile) => {
                    this.homeViewModel.applyBookmark(profile);
                  },
                  onDelete: (profileId) => {
                    void this.homeViewModel.deleteBookmark(profileId);
                  }
                })
              }
              .padding(20)
              .backgroundColor('#FFFFFF')
              .borderRadius(24)

              Text(this.homeViewModel.lastMessage)
                .fontSize(12)
                .fontColor('#6B7280')
                .alignSelf(ItemAlign.Start)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .width(this.contentMaxWidth())
          .margin({ left: 'auto', right: 'auto' })
          .padding({
            left: this.horizontalPadding(),
            right: this.horizontalPadding(),
            top: this.isPhoneLayout() ? 24 : 40,
            bottom: 40
          })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F9FAFB')
      .onAreaChange((_, newValue) => {
        this.pageWidth = Number(newValue.width);
      })
    }
    .hideTitleBar(true)
    .navBarWidth(this.isPhoneLayout() ? '100%' : '30%')
    .mode(NavigationMode.Stack)
  }
}
