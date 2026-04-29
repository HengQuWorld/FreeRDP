import { SessionEvent } from '../model/SessionModels';

@CustomDialog
export struct AuthDialog {
  controller: CustomDialogController;
  event: SessionEvent | null = null;
  username: string = '';
  password: string = '';
  domain: string = '';
  onConfirm: (username: string, password: string, domain: string) => void = () => {};

  build() {
    Column() {
      Text('需要身份验证')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 10 })

      Text('远程桌面服务器需要您的凭据。')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ bottom: 20 })

      TextInput({ placeholder: '用户名', text: this.username })
        .onChange((value: string) => {
          this.username = value;
        })
        .margin({ bottom: 10 })

      TextInput({ placeholder: '密码', text: this.password })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.password = value;
        })
        .margin({ bottom: 10 })

      TextInput({ placeholder: '域 (可选)', text: this.domain })
        .onChange((value: string) => {
          this.domain = value;
        })
        .margin({ bottom: 20 })

      Row() {
        Button('取消')
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => {
            this.onConfirm('', '', '');
            this.controller.close();
          })
          .margin({ right: 10 })
          .layoutWeight(1)

        Button('确定')
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
          .onClick(() => {
            this.onConfirm(this.username, this.password, this.domain);
            this.controller.close();
          })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .padding(20)
    .width('90%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}
