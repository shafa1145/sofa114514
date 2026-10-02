import { CampusNotice, BlogService, URL_GRADER, URL_HOA, URL_TODAY_HIT } from './BlogService';

const COLOR_PRIMARY: string = '#2E86E8';
const COLOR_CARD: string = '#FFFFFF';
const COLOR_TEXT_PRIMARY: string = '#14213D';
const COLOR_TEXT_SECONDARY: string = '#6B7A90';
const COLOR_NAV_ACTIVE: string = '#E3EEFC';
const COLOR_NAV_ACTIVE_TEXT: string = '#1B6FD1';

/**
 * 资讯页。栏目结构来自参考工程 BlogPage：博客占位 + 今日哈工大通知。
 */
@Component
export struct NewsPane {
  @State tab: number = 1;
  @State notices: CampusNotice[] = [];
  @State loading: boolean = false;
  @State statusText: string = '';

  aboutToAppear(): void {
    if (this.notices.length === 0) {
      this.loadNotices();
    }
  }

  private async loadNotices(): Promise<void> {
    this.loading = true;
    this.statusText = '正在拉取校园通知…';
    const portals: CampusNotice[] = [
      {
        id: 'portal_today',
        title: '今日哈工大 · 官网首页',
        source: 'today.hit.edu.cn',
        date: '入口',
        url: URL_TODAY_HIT
      },
      {
        id: 'portal_hoa',
        title: 'HOA 课程资料 / 攻略',
        source: 'hoa.moe',
        date: '入口',
        url: URL_HOA
      },
      {
        id: 'portal_grader',
        title: '成绩服务 grader.hitsz.edu.cn',
        source: 'grader.hitsz.edu.cn',
        date: '入口',
        url: URL_GRADER
      }
    ];
    try {
      const list: CampusNotice[] = await BlogService.fetchTodayHitNotices(0);
      const merged: CampusNotice[] = [];
      for (let i: number = 0; i < portals.length; i++) {
        merged.push(portals[i]);
      }
      for (let i: number = 0; i < list.length; i++) {
        merged.push(list[i]);
      }
      this.notices = merged;
      this.statusText = '校园通知 ' + list.length.toString() + ' 条 · 可点击打开';
    } catch (_e) {
      this.notices = portals;
      this.statusText = '网络异常，已显示入口';
    }
    this.loading = false;
  }

  private openLink(url: string, title: string): void {
    if (url.length === 0) {
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/WebBrowserPage',
      params: { 'openUrl': url, 'title': title }
    });
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('资讯')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY)
          Text('博客 · 校园通知')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SECONDARY)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(this.loading ? '加载中' : '刷新')
          .fontSize(13)
          .fontColor(COLOR_NAV_ACTIVE_TEXT)
          .backgroundColor(COLOR_NAV_ACTIVE)
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.loadNotices();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 14, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Column() {
          this.seg('博客', 0);
        }
        .layoutWeight(1)

        Column() {
          this.seg('校园通知', 1);
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      if (this.tab === 0) {
        this.blogEmpty();
      } else {
        this.noticeList();
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  seg(label: string, index: number) {
    Text(label)
      .fontSize(14)
      .fontColor(this.tab === index ? COLOR_NAV_ACTIVE_TEXT : COLOR_TEXT_SECONDARY)
      .fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Regular)
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding({ top: 8, bottom: 8 })
      .borderRadius(18)
      .backgroundColor(this.tab === index ? COLOR_NAV_ACTIVE : COLOR_CARD)
      .onClick(() => {
        this.tab = index;
        if (index === 1 && this.notices.length === 0) {
          this.loadNotices();
        }
      })
  }

  @Builder
  blogEmpty() {
    Column({ space: 8 }) {
      Text('暂无内容')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT_PRIMARY)
      Text('博客栏目即将上线，校园资讯请切换到「校园通知」。')
        .fontSize(13)
        .fontColor(COLOR_TEXT_SECONDARY)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .margin({ left: 16, right: 16, top: 12 })
    .borderRadius(16)
    .backgroundColor(COLOR_CARD)
  }

  @Builder
  noticeList() {
    Column() {
      Text(this.statusText)
        .fontSize(12)
        .fontColor(COLOR_TEXT_SECONDARY)
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 4 })
      if (this.loading && this.notices.length === 0) {
        Column() {
          LoadingProgress().width(36).height(36).color(COLOR_PRIMARY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.notices, (item: CampusNotice) => {
            ListItem() {
              Column({ space: 6 }) {
                Text(item.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_TEXT_PRIMARY)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(item.source + ' · ' + item.date)
                  .fontSize(12)
                  .fontColor(COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(14)
              .borderRadius(16)
              .backgroundColor(COLOR_CARD)
              .onClick(() => {
                this.openLink(item.url, item.title);
              })
            }
          }, (item: CampusNotice) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Off)
      }
    }
    .layoutWeight(1)
    .width('100%')
  }
}
