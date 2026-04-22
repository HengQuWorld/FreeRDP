import { SessionEvent } from '../model/SessionModels';

@CustomDialog
export struct CertDialog {
  controller: CustomDialogController;
  event: SessionEvent | null = null;
  onConfirm: (accept: boolean) => void = () => {};

  build() {
    Column() {
      Text('证书验证')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 10 })

      Text('无法验证此远程计算机的身份。是否仍要连接？')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ bottom: 20 })

      if (this.event) {
        Column() {
          Text(`主机: ${this.event.certHost}`)
            .fontSize(12)
            .margin({ bottom: 5 })
          Text(`主题: ${this.event.certSubject}`)
            .fontSize(12)
            .margin({ bottom: 5 })
          Text(`颁发者: ${this.event.certIssuer}`)
            .fontSize(12)
            .margin({ bottom: 5 })
          Text(`指纹: ${this.event.certFingerprint}`)
            .fontSize(12)
            .margin({ bottom: 10 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(10)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .margin({ bottom: 20 })
      }

      Row() {
        Button('拒绝')
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => {
            this.onConfirm(false);
            this.controller.close();
          })
          .margin({ right: 10 })
          .layoutWeight(1)

        Button('接受并连接')
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
          .onClick(() => {
            this.onConfirm(true);
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
