import { ConnectionProfile } from '../model/ConnectionProfile';
import { ThemeColors, LightColors, DarkColors } from '../utils/ThemeConstants';
import { i18n } from '../utils/I18n';
import { showKeyboardForField } from '../utils/KeyboardHelper';

interface ResolutionPreset {
  label: string;
  width: number;
  height: number;
}

const RESOLUTION_PRESETS: ResolutionPreset[] = [
  { label: 'resolution_1920x1080', width: 1920, height: 1080 },
  { label: 'resolution_2560x1440', width: 2560, height: 1440 },
  { label: 'resolution_3840x2160', width: 3840, height: 2160 },
  { label: 'resolution_1280x720', width: 1280, height: 720 }
];

@Component
export struct ConnectionForm {
  @Prop @Watch('onProfileChanged') profile: ConnectionProfile;
  @Prop canConnect: boolean;
  @Prop rememberPassword: boolean;
  @StorageLink('__app_is_dark_mode__') @Watch('onThemeChanged') isDark: boolean = false;
  @StorageLink('__app_language__') appLanguage: string = 'system';
  @State colors: ThemeColors = LightColors;
  @State gatewayExpanded: boolean = false;
  @State resolutionExpanded: boolean = false;
  @State connectionName: string = '';
  @State hostAddress: string = '';
  @State portNumber: string = '3389';
  @State userName: string = '';
  @State domainName: string = '';
  @State passwordValue: string = '';
  @State gatewayAddress: string = '';
  @State gatewayUserName: string = '';
  @State gatewayPasswordValue: string = '';
  @State gatewayDomainName: string = '';
  onNameChange: (value: string) => void = (_value: string): void => {};
  onHostChange: (value: string) => void = (_value: string): void => {};
  onPortChange: (value: string) => void = (_value: string): void => {};
  onUserChange: (value: string) => void = (_value: string): void => {};
  onDomainChange: (value: string) => void = (_value: string): void => {};
  onPasswordChange: (value: string) => void = (_value: string): void => {};
  onRememberPasswordChange: (value: boolean) => void = (_value: boolean): void => {};
  onGatewayChange: (value: string) => void = (_value: string): void => {};
  onGatewayUserChange: (value: string) => void = (_value: string): void => {};
  onGatewayPasswordChange: (value: string) => void = (_value: string): void => {};
  onGatewayDomainChange: (value: string) => void = (_value: string): void => {};
  onClipboardChange: (value: boolean) => void = (_value: boolean): void => {};
  onResolutionChange: (width: number, height: number) => void = (_w: number, _h: number): void => {};
  onNew: () => void = (): void => {};
  onSave: () => void = (): void => {};
  onConnect: () => void = (): void => {};

  onThemeChanged(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
  }

  onProfileChanged(): void {
    if (this.connectionName !== this.profile.name) {
      this.connectionName = this.profile.name;
    }
    if (this.hostAddress !== this.profile.host) {
      this.hostAddress = this.profile.host;
    }
    const portStr = `${this.profile.port}`;
    if (this.portNumber !== portStr) {
      this.portNumber = portStr;
    }
    if (this.userName !== this.profile.username) {
      this.userName = this.profile.username;
    }
    if (this.domainName !== this.profile.domain) {
      this.domainName = this.profile.domain;
    }
    if (this.passwordValue !== this.profile.password) {
      this.passwordValue = this.profile.password;
    }
    if (this.gatewayAddress !== this.profile.gateway) {
      this.gatewayAddress = this.profile.gateway;
    }
    if (this.gatewayUserName !== this.profile.gatewayUsername) {
      this.gatewayUserName = this.profile.gatewayUsername;
    }
    if (this.gatewayPasswordValue !== this.profile.gatewayPassword) {
      this.gatewayPasswordValue = this.profile.gatewayPassword;
    }
    if (this.gatewayDomainName !== this.profile.gatewayDomain) {
      this.gatewayDomainName = this.profile.gatewayDomain;
    }
  }

  aboutToAppear(): void {
    this.colors = this.isDark ? DarkColors : LightColors;
    this.syncFromProfile();
  }

  private syncFromProfile(): void {
    this.connectionName = this.profile.name;
    this.hostAddress = this.profile.host;
    this.portNumber = `${this.profile.port}`;
    this.userName = this.profile.username;
    this.domainName = this.profile.domain;
    this.passwordValue = this.profile.password;
    this.gatewayAddress = this.profile.gateway;
    this.gatewayUserName = this.profile.gatewayUsername;
    this.gatewayPasswordValue = this.profile.gatewayPassword;
    this.gatewayDomainName = this.profile.gatewayDomain;
  }

  private hasGatewayConfig(): boolean {
    return !!(this.profile.gateway || this.profile.gatewayUsername ||
      this.profile.gatewayPassword || this.profile.gatewayDomain);
  }

  private getCurrentResolutionLabel(): string {
    const w: number = this.profile.desktopWidth;
    const h: number = this.profile.desktopHeight;
    for (const preset of RESOLUTION_PRESETS) {
      if (preset.width === w && preset.height === h) {
        return i18n.get(this.appLanguage, preset.label);
      }
    }
    return `${w} × ${h}`;
  }

  private isPresetSelected(preset: ResolutionPreset): boolean {
    return this.profile.desktopWidth === preset.width && this.profile.desktopHeight === preset.height;
  }

  build() {
    Column({ space: 18 }) {
      Row() {
        Text(i18n.get(this.appLanguage, 'connection_settings'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.foreground)
          .layoutWeight(1)

        Button(i18n.get(this.appLanguage, 'new_connection'))
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(38)
          .backgroundColor(this.colors.muted)
          .fontColor(this.colors.mutedForeground)
          .borderRadius(10)
          .padding({ left: 16, right: 16 })
          .onClick(() => this.onNew())
      }
      .width('100%')

      Column({ space: 14 }) {
        TextInput({ placeholder: i18n.get(this.appLanguage, 'connection_name_placeholder'), text: $$this.connectionName })
          .backgroundColor(this.colors.inputBackground)
          .borderRadius(12)
          .border({ width: 1, color: this.colors.inputBorder })
          .fontSize(16)
          .height(50)
          .padding({ left: 16, right: 16 })
          .placeholderColor(this.colors.mutedForeground)
          .fontColor(this.colors.foreground)
          .focusOnTouch(false)
          .id('connectionForm_name')
          .onClick(() => {
            showKeyboardForField(this.getUIContext(),'connectionForm_name');
          })
          .onChange((v) => {
            this.connectionName = v;
            this.onNameChange(v);
          });

        TextInput({ placeholder: i18n.get(this.appLanguage, 'server_address_placeholder'), text: $$this.hostAddress })
          .backgroundColor(this.colors.inputBackground)
          .borderRadius(12)
          .border({ width: 1, color: this.colors.inputBorder })
          .fontSize(16)
          .height(50)
          .padding({ left: 16, right: 16 })
          .placeholderColor(this.colors.mutedForeground)
          .fontColor(this.colors.foreground)
          .focusOnTouch(false)
          .id('connectionForm_host')
          .onClick(() => {
            showKeyboardForField(this.getUIContext(),'connectionForm_host');
          })
          .onChange((v) => {
            this.hostAddress = v;
            this.onHostChange(v);
          });

        Row({ space: 12 }) {
          TextInput({ placeholder: i18n.get(this.appLanguage, 'port_placeholder'), text: $$this.portNumber })
            .type(InputType.Number)
            .backgroundColor(this.colors.inputBackground)
            .borderRadius(12)
            .border({ width: 1, color: this.colors.inputBorder })
            .fontSize(16)
            .height(50)
            .padding({ left: 16, right: 16 })
            .placeholderColor(this.colors.mutedForeground)
            .fontColor(this.colors.foreground)
            .layoutWeight(1)
            .focusOnTouch(false)
            .id('connectionForm_port')
            .onClick(() => {
              showKeyboardForField(this.getUIContext(),'connectionForm_port');
            })
            .onChange((v) => {
              this.portNumber = v;
              this.onPortChange(v);
            });
        }

        TextInput({ placeholder: i18n.get(this.appLanguage, 'username_placeholder'), text: $$this.userName })
          .backgroundColor(this.colors.inputBackground)
          .borderRadius(12)
          .border({ width: 1, color: this.colors.inputBorder })
          .fontSize(16)
          .height(50)
          .padding({ left: 16, right: 16 })
          .placeholderColor(this.colors.mutedForeground)
          .fontColor(this.colors.foreground)
          .focusOnTouch(false)
          .id('connectionForm_user')
          .onClick(() => {
            showKeyboardForField(this.getUIContext(),'connectionForm_user');
          })
          .onChange((v) => {
            this.userName = v;
            this.onUserChange(v);
          });

        TextInput({ placeholder: i18n.get(this.appLanguage, 'domain_optional_placeholder'), text: $$this.domainName })
          .backgroundColor(this.colors.inputBackground)
          .borderRadius(12)
          .border({ width: 1, color: this.colors.inputBorder })
          .fontSize(16)
          .height(50)
          .padding({ left: 16, right: 16 })
          .placeholderColor(this.colors.mutedForeground)
          .fontColor(this.colors.foreground)
          .focusOnTouch(false)
          .id('connectionForm_domain')
          .onClick(() => {
            showKeyboardForField(this.getUIContext(),'connectionForm_domain');
          })
          .onChange((v) => {
            this.domainName = v;
            this.onDomainChange(v);
          });

        Row() {
          Text(i18n.get(this.appLanguage, 'remember_password'))
            .fontSize(16)
            .fontColor(this.colors.foreground)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.rememberPassword })
            .onChange((value: boolean) => this.onRememberPasswordChange(value))
        }
        .width('100%')
        .padding({ left: 4, right: 4, top: 8, bottom: 8 })

        TextInput({ placeholder: i18n.get(this.appLanguage, 'password_placeholder'), text: $$this.passwordValue })
          .type(InputType.Password)
          .backgroundColor(this.rememberPassword ? this.colors.inputBackground : this.colors.muted)
          .borderRadius(12)
          .border({ width: 1, color: this.colors.inputBorder })
          .fontSize(16)
          .height(50)
          .padding({ left: 16, right: 16 })
          .placeholderColor(this.colors.mutedForeground)
          .fontColor(this.rememberPassword ? this.colors.foreground : this.colors.mutedForeground)
          .enabled(this.rememberPassword)
          .focusOnTouch(false)
          .id('connectionForm_password')
          .onClick(() => {
            showKeyboardForField(this.getUIContext(),'connectionForm_password');
          })
          .onChange((v) => {
            this.passwordValue = v;
            this.onPasswordChange(v);
          });

        if (this.profile.username.length === 0 || this.profile.password.length === 0) {
          Row({ space: 10 }) {
            Text('i')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.hintOrange)
              .width(22)
              .height(22)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.colors.hintOrangeBg)
              .borderRadius(11)
            Text(i18n.get(this.appLanguage, 'empty_credentials_hint'))
              .fontSize(14)
              .fontColor(this.colors.hintOrange)
              .lineHeight(20)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.colors.hintOrangeBg)
          .borderRadius(12)
        }
      }

      Column({ space: 0 }) {
        Row() {
          Row({ space: 10 }) {
            Text(this.gatewayExpanded ? '▾' : '▸')
              .fontSize(14)
              .fontColor(this.colors.primary);
            Text(i18n.get(this.appLanguage, 'gateway_settings'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.foreground);
          }
          .onClick(() => { this.gatewayExpanded = !this.gatewayExpanded; })
          Blank()
          if (this.hasGatewayConfig()) {
            Text(i18n.get(this.appLanguage, 'gateway_configured'))
              .fontSize(13)
              .fontColor(this.colors.connectedGreen)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.colors.tagBackground)
              .borderRadius(999)
          }
        }
        .width('100%')
        .padding(16)
        .onClick(() => { this.gatewayExpanded = !this.gatewayExpanded; });

        if (this.gatewayExpanded) {
          Column({ space: 14 }) {
            TextInput({ placeholder: i18n.get(this.appLanguage, 'gateway_address_placeholder'), text: $$this.gatewayAddress })
              .backgroundColor(this.colors.inputBackground)
              .borderRadius(12)
              .border({ width: 1, color: this.colors.inputBorder })
              .fontSize(16)
              .height(50)
              .padding({ left: 16, right: 16 })
              .placeholderColor(this.colors.mutedForeground)
              .fontColor(this.colors.foreground)
              .focusOnTouch(false)
              .id('connectionForm_gw_addr')
              .onClick(() => {
                showKeyboardForField(this.getUIContext(),'connectionForm_gw_addr');
              })
              .onChange((v) => {
                this.gatewayAddress = v;
                this.onGatewayChange(v);
              });
            TextInput({ placeholder: i18n.get(this.appLanguage, 'gateway_username_placeholder'), text: $$this.gatewayUserName })
              .backgroundColor(this.colors.inputBackground)
              .borderRadius(12)
              .border({ width: 1, color: this.colors.inputBorder })
              .fontSize(16)
              .height(50)
              .padding({ left: 16, right: 16 })
              .placeholderColor(this.colors.mutedForeground)
              .fontColor(this.colors.foreground)
              .focusOnTouch(false)
              .id('connectionForm_gw_user')
              .onClick(() => {
                showKeyboardForField(this.getUIContext(),'connectionForm_gw_user');
              })
              .onChange((v) => {
                this.gatewayUserName = v;
                this.onGatewayUserChange(v);
              });
            TextInput({ placeholder: i18n.get(this.appLanguage, 'gateway_domain_placeholder'), text: $$this.gatewayDomainName })
              .backgroundColor(this.colors.inputBackground)
              .borderRadius(12)
              .border({ width: 1, color: this.colors.inputBorder })
              .fontSize(16)
              .height(50)
              .padding({ left: 16, right: 16 })
              .placeholderColor(this.colors.mutedForeground)
              .fontColor(this.colors.foreground)
              .focusOnTouch(false)
              .id('connectionForm_gw_domain')
              .onClick(() => {
                showKeyboardForField(this.getUIContext(),'connectionForm_gw_domain');
              })
              .onChange((v) => {
                this.gatewayDomainName = v;
                this.onGatewayDomainChange(v);
              });
            TextInput({ placeholder: i18n.get(this.appLanguage, 'gateway_password_placeholder'), text: $$this.gatewayPasswordValue })
              .type(InputType.Password)
              .backgroundColor(this.colors.inputBackground)
              .borderRadius(12)
              .border({ width: 1, color: this.colors.inputBorder })
              .fontSize(16)
              .height(50)
              .padding({ left: 16, right: 16 })
              .placeholderColor(this.colors.mutedForeground)
              .fontColor(this.colors.foreground)
              .focusOnTouch(false)
              .id('connectionForm_gw_pass')
              .onClick(() => {
                showKeyboardForField(this.getUIContext(),'connectionForm_gw_pass');
              })
              .onChange((v) => {
                this.gatewayPasswordValue = v;
                this.onGatewayPasswordChange(v);
              });
          }
          .width('100%')
          .padding({ top: 4, bottom: 16 })
          .animation({ duration: 200, curve: Curve.EaseInOut })
        }
      }
      .width('100%')
      .backgroundColor(this.colors.surfaceElevated)
      .border({ width: 1, color: this.colors.surfaceElevatedBorder })
      .borderRadius(16)

      Row() {
        Text(i18n.get(this.appLanguage, 'clipboard_bidirectional'))
          .fontSize(16)
          .fontColor(this.colors.foreground)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.profile.enableClipboard })
          .onChange((value: boolean) => this.onClipboardChange(value))
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 8, bottom: 8 })

      Column({ space: 0 }) {
        Row() {
          Row({ space: 10 }) {
            Text(this.resolutionExpanded ? '▾' : '▸')
              .fontSize(14)
              .fontColor(this.colors.primary);
            Text(i18n.get(this.appLanguage, 'resolution_settings'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.foreground);
          }
          Blank()
          Text(this.getCurrentResolutionLabel())
            .fontSize(14)
            .fontColor(this.colors.primary)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.colors.tagBackground)
            .borderRadius(999)
        }
        .width('100%')
        .padding(16)
        .onClick(() => { this.resolutionExpanded = !this.resolutionExpanded; });

        if (this.resolutionExpanded) {
          Column({ space: 8 }) {
            ForEach(RESOLUTION_PRESETS, (preset: ResolutionPreset) => {
              Row() {
                Text(i18n.get(this.appLanguage, preset.label))
                  .fontSize(15)
                  .fontColor(this.isPresetSelected(preset) ? this.colors.primary : this.colors.foreground)
                  .layoutWeight(1)
                if (this.isPresetSelected(preset)) {
                  Text('✓')
                    .fontSize(16)
                    .fontColor(this.colors.primary)
                    .fontWeight(FontWeight.Bold)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(10)
              .backgroundColor(this.isPresetSelected(preset) ? this.colors.tagBackground : Color.Transparent)
              .onClick(() => {
                this.onResolutionChange(preset.width, preset.height);
              })
            }, (preset: ResolutionPreset, index: number) => `${preset.label}-${index}`)
          }
          .width('100%')
          .padding({ top: 4, bottom: 16 })
          .animation({ duration: 200, curve: Curve.EaseInOut })
        }
      }
      .width('100%')
      .backgroundColor(this.colors.surfaceElevated)
      .border({ width: 1, color: this.colors.surfaceElevatedBorder })
      .borderRadius(16)

      Row({ space: 14 }) {
        Button(i18n.get(this.appLanguage, 'save_config'))
          .layoutWeight(1)
          .type(ButtonType.Normal)
          .height(52)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.colors.muted)
          .fontColor(this.colors.foreground)
          .borderRadius(14)
          .onClick(() => this.onSave())

        Button(i18n.get(this.appLanguage, 'connect_desktop'))
          .layoutWeight(2)
          .type(ButtonType.Normal)
          .height(52)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.canConnect ? this.colors.primary : this.colors.muted)
          .fontColor(this.canConnect ? this.colors.primaryForeground : this.colors.mutedForeground)
          .borderRadius(14)
          .enabled(this.canConnect)
          .onClick(() => this.onConnect())
      }
      .width('100%')
    }
    .width('100%')
  }
}
