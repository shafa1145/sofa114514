import { webview } from '@kit.ArkWeb';

/**
 * 内嵌浏览器，用于打开资讯与资料链接。样式对齐主界面顶栏。
 */
@Entry
@Component
struct WebBrowserPage {
  @State openUrl: string = '';
  @State titleText: string = '详情';
  @State statusText: string = '加载中…';
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params: Object | undefined = this.getUIContext().getRouter().getParams();
    if (params !== undefined && params !== null) {
      const record = params as Record<string, string>;
      if (record['openUrl'] !== undefined) {
        this.openUrl = String(record['openUrl']);
      }
      if (record['title'] !== undefined && String(record['title']).length > 0) {
        this.titleText = String(record['title']);
      }
    }
    if (this.openUrl.length === 0) {
      this.statusText = '无有效链接';
    }
  }

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(15)
          .fontColor('#1B6FD1')
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
        Text(this.titleText)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#14213D')
          .margin({ left: 12 })
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      Text(this.statusText)
        .fontSize(12)
        .fontColor('#6B7A90')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.openUrl.length > 0) {
        Web({ src: this.openUrl, controller: this.webController })
          .layoutWeight(1)
          .width('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.All)
          .onPageBegin(() => {
            this.statusText = '加载中…';
          })
          .onPageEnd(() => {
            this.statusText = this.openUrl;
          })
          .onErrorReceive((_event) => {
            this.statusText = '页面加载失败，请检查网络后重试';
          })
      } else {
        Text('未提供要打开的链接')
          .fontColor('#6B7A90')
          .margin({ top: 40 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7FC')
  }
}
