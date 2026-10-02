import { common } from '@kit.AbilityKit';
import { AgentMemory, ChatMessage } from './ChatModels';
import { AgentService } from './AgentService';
import { LlmKeyStore } from './LlmKeyStore';

const COLOR_PRIMARY: string = '#2E86E8';
const COLOR_CARD: string = '#FFFFFF';
const COLOR_TEXT_PRIMARY: string = '#14213D';
const COLOR_TEXT_SECONDARY: string = '#6B7A90';
const COLOR_NAV_ACTIVE: string = '#E3EEFC';
const COLOR_NAV_ACTIVE_TEXT: string = '#1B6FD1';

/**
 * AI 对话页。气泡与输入栏沿用主界面的白卡片和主色，对话逻辑来自参考工程 AgentPage。
 */
@Component
export struct AgentPane {
  @State messages: ChatMessage[] = [];
  @State input: string = '';
  @State sending: boolean = false;
  @State settingsOpen: boolean = false;
  @State provider: string = 'deepseek';
  @State apiKey: string = '';
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    if (AgentMemory.messages.length === 0) {
      AgentMemory.messages = [{
        id: 'welcome',
        role: 'assistant',
        content: '你好，我是 HITA AI。可以问我今天课表、明天的安排、课程和教师，或让我添加一个活动。',
        timestamp: Date.now()
      }];
    }
    this.messages = AgentMemory.messages;
    const ctx: common.Context = this.getUIContext().getHostContext() as common.Context;
    await LlmKeyStore.init(ctx);
    this.provider = await LlmKeyStore.getProvider();
    this.apiKey = await LlmKeyStore.getApiKey();
  }

  private async sendText(text: string): Promise<void> {
    const value: string = text.trim();
    if (value.length === 0 || this.sending) {
      return;
    }
    this.sending = true;
    this.input = '';
    const ctx: common.Context = this.getUIContext().getHostContext() as common.Context;
    const produced: ChatMessage[] = await AgentService.handleUserMessage(ctx, this.messages, value);
    const next: ChatMessage[] = [];
    for (let i: number = 0; i < this.messages.length; i++) {
      next.push(this.messages[i]);
    }
    for (let i: number = 0; i < produced.length; i++) {
      next.push(produced[i]);
    }
    this.messages = next;
    AgentMemory.messages = next;
    this.sending = false;
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 80);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.header();
        Scroll(this.scroller) {
          Column({ space: 10 }) {
            ForEach(this.messages, (item: ChatMessage) => {
              this.bubble(item);
            }, (item: ChatMessage) => item.id)
            if (this.messages.length === 1) {
              this.suggestions();
            }
            if (this.sending) {
              Text('思考中…')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SECONDARY)
                .width('100%')
                .padding({ left: 4, top: 4 });
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, bottom: 12 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        Row() {
          TextInput({ placeholder: '问课表、课程、教师…', text: this.input })
            .layoutWeight(1)
            .height(44)
            .backgroundColor(COLOR_CARD)
            .fontColor(COLOR_TEXT_PRIMARY)
            .placeholderColor(COLOR_TEXT_SECONDARY)
            .borderRadius(22)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.input = value;
            })
            .onSubmit(() => {
              this.sendText(this.input);
            })
          Button(this.sending ? '…' : '发送')
            .height(44)
            .fontSize(15)
            .backgroundColor(COLOR_PRIMARY)
            .fontColor('#FFFFFF')
            .borderRadius(22)
            .margin({ left: 8 })
            .enabled(!this.sending)
            .onClick(() => {
              this.sendText(this.input);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }
      .width('100%')
      .height('100%')

      if (this.settingsOpen) {
        Column() {
          Column()
            .layoutWeight(1)
            .width('100%')
            .onClick(() => {
              this.settingsOpen = false;
            })
          this.settingsSheet();
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(20,33,61,0.24)')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  header() {
    Row() {
      Column() {
        Text('AI')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT_PRIMARY)
        Text('课表 · 课程 · 校园问答')
          .fontSize(13)
          .fontColor(COLOR_TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Text('模型')
        .fontSize(13)
        .fontColor(COLOR_NAV_ACTIVE_TEXT)
        .backgroundColor(COLOR_NAV_ACTIVE)
        .borderRadius(14)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .onClick(() => {
          this.settingsOpen = true;
        })
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 14, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  suggestions() {
    Row({ space: 8 }) {
      this.chip('今天课表');
      this.chip('明天安排');
      this.chip('校园资讯');
    }
    .width('100%')
    .margin({ top: 4 })
  }

  @Builder
  chip(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(COLOR_NAV_ACTIVE_TEXT)
      .backgroundColor(COLOR_CARD)
      .borderRadius(16)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .onClick(() => {
        this.sendText(label);
      })
  }

  @Builder
  bubble(item: ChatMessage) {
    Column({ space: 4 }) {
      if (item.toolName !== undefined && item.toolName.length > 0) {
        Text('工具 · ' + item.toolName)
          .fontSize(11)
          .fontColor(COLOR_NAV_ACTIVE_TEXT)
      }
      Text(item.content)
        .fontSize(14)
        .fontColor(item.role === 'user' ? '#FFFFFF' : COLOR_TEXT_PRIMARY)
        .lineHeight(22)
    }
    .constraintSize({ maxWidth: '86%' })
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(16)
    .backgroundColor(item.role === 'user' ? COLOR_PRIMARY :
      (item.role === 'tool' ? COLOR_NAV_ACTIVE : COLOR_CARD))
    .alignSelf(item.role === 'user' ? ItemAlign.End : ItemAlign.Start)
  }

  @Builder
  settingsSheet() {
    Column() {
      Text('模型设置')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT_PRIMARY)
        .width('100%')
      Text('不填写也可以使用本地课表问答。填写后，本地工具无法回答的问题会发给对应模型。')
        .fontSize(12)
        .fontColor(COLOR_TEXT_SECONDARY)
        .width('100%')
        .margin({ top: 6 })
      Row({ space: 8 }) {
        this.providerChip('DeepSeek', 'deepseek');
        this.providerChip('智谱', 'bigmodel');
      }
      .width('100%')
      .margin({ top: 14 })
      TextInput({ placeholder: 'API Key', text: this.apiKey })
        .width('100%')
        .height(44)
        .margin({ top: 12 })
        .backgroundColor(COLOR_CARD)
        .borderRadius(12)
        .type(InputType.Password)
        .onChange((value: string) => {
          this.apiKey = value;
        })
      Button('保存')
        .width('100%')
        .height(44)
        .margin({ top: 14 })
        .backgroundColor(COLOR_PRIMARY)
        .fontColor('#FFFFFF')
        .onClick(() => {
          const ctx: common.Context = this.getUIContext().getHostContext() as common.Context;
          LlmKeyStore.init(ctx).then(() => {
            return LlmKeyStore.save(this.provider, this.apiKey);
          }).then(() => {
            this.settingsOpen = false;
            this.getUIContext().getPromptAction().showToast({ message: '模型设置已保存' });
          })
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 24 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#F4F7FC')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  @Builder
  providerChip(label: string, code: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.provider === code ? '#FFFFFF' : COLOR_TEXT_SECONDARY)
      .backgroundColor(this.provider === code ? COLOR_PRIMARY : COLOR_CARD)
      .borderRadius(16)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .onClick(() => {
        this.provider = code;
      })
  }
}
