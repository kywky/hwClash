import { router, promptAction } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppSettings, Subscription, createDefaultSettings } from '../model/Types';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { decodeSubscription, extractNodes } from '../utils/ConfigBuilder';

@Entry
@Component
struct SubscriptionPage {
  @State subscriptions: Subscription[] = [];
  @State inputName: string = '';
  @State inputUrl: string = '';
  @State loading: boolean = false;
  @State activeId: string = '';
  private settings: AppSettings = createDefaultSettings();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.loadState();
  }

  private async loadState(): Promise<void> {
    await PreferencesUtil.init(this.context);
    this.settings = await PreferencesUtil.loadSettings();
    this.subscriptions = await PreferencesUtil.loadSubscriptions();
    this.activeId = this.settings.activeSubscriptionId;
  }

  private async downloadConfig(url: string): Promise<string> {
    const client = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'User-Agent': 'clash.meta'
      };
      const response = await client.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 15000,
        readTimeout: 20000
      });
      if (response.responseCode !== 200) {
        throw new Error('HTTP ' + response.responseCode.toString());
      }
      return response.result as string;
    } finally {
      client.destroy();
    }
  }

  private async addSubscription(): Promise<void> {
    const url = this.inputUrl.trim();
    if (url === '') {
      promptAction.showToast({ message: '请填写订阅链接' });
      return;
    }
    if (url.indexOf('http') !== 0) {
      promptAction.showToast({ message: '订阅链接必须以 http 开头' });
      return;
    }
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      const body = await this.downloadConfig(url);
      const decoded = decodeSubscription(body);
      const nodes = extractNodes(decoded);
      if (nodes.length === 0) {
        promptAction.showToast({ message: '未解析到节点，请确认是 Clash 订阅' });
        return;
      }
      const sub: Subscription = {
        id: Date.now().toString(),
        name: this.inputName.trim() === '' ? ('订阅 ' + (this.subscriptions.length + 1).toString()) : this.inputName.trim(),
        url: url,
        updatedAt: Date.now(),
        rawConfig: decoded,
        nodes: nodes
      };
      const list = await PreferencesUtil.loadSubscriptions();
      list.push(sub);
      await PreferencesUtil.saveSubscriptions(list);
      if (this.settings.activeSubscriptionId === '') {
        this.settings.activeSubscriptionId = sub.id;
        this.settings.selectedNode = nodes[0].name;
        await PreferencesUtil.saveSettings(this.settings);
        this.activeId = sub.id;
      }
      this.subscriptions = list;
      this.inputName = '';
      this.inputUrl = '';
      promptAction.showToast({ message: '添加成功，共 ' + nodes.length.toString() + ' 个节点' });
    } catch (error) {
      const err = error as BusinessError;
      promptAction.showToast({ message: '添加失败：' + err.message });
    } finally {
      this.loading = false;
    }
  }

  private async removeSubscription(id: string): Promise<void> {
    const list = this.subscriptions.filter((item: Subscription) => item.id !== id);
    await PreferencesUtil.saveSubscriptions(list);
    if (this.settings.activeSubscriptionId === id) {
      this.settings.activeSubscriptionId = list.length > 0 ? list[0].id : '';
      this.settings.selectedNode = list.length > 0 && list[0].nodes.length > 0 ? list[0].nodes[0].name : '';
      await PreferencesUtil.saveSettings(this.settings);
      this.activeId = this.settings.activeSubscriptionId;
    }
    this.subscriptions = list;
  }

  private async setActive(id: string): Promise<void> {
    this.settings.activeSubscriptionId = id;
    for (const sub of this.subscriptions) {
      if (sub.id === id) {
        this.settings.selectedNode = sub.nodes.length > 0 ? sub.nodes[0].name : '';
        break;
      }
    }
    await PreferencesUtil.saveSettings(this.settings);
    this.activeId = id;
    promptAction.showToast({ message: '已切换当前订阅' });
  }

  private formatTime(ts: number): string {
    const date = new Date(ts);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(22)
          .fontColor('#E6EDF3')
          .padding(8)
          .onClick(() => {
            router.back();
          })
        Text('订阅管理')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#E6EDF3')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12 })

      Column() {
        TextInput({ placeholder: '名称（可选）', text: this.inputName })
          .height(42)
          .backgroundColor('#161B22')
          .fontColor('#E6EDF3')
          .placeholderColor('#484F58')
          .borderRadius(10)
          .onChange((value: string) => {
            this.inputName = value;
          })

        TextInput({ placeholder: 'Clash 订阅链接', text: this.inputUrl })
          .height(42)
          .backgroundColor('#161B22')
          .fontColor('#E6EDF3')
          .placeholderColor('#484F58')
          .borderRadius(10)
          .margin({ top: 10 })
          .onChange((value: string) => {
            this.inputUrl = value;
          })

        Button(this.loading ? '下载中...' : '添加订阅')
          .width('100%')
          .height(42)
          .margin({ top: 12 })
          .backgroundColor(this.loading ? '#21262D' : '#1F6FEB')
          .fontColor('#FFFFFF')
          .enabled(!this.loading)
          .onClick(() => {
            this.addSubscription();
          })
      }
      .width('92%')
      .padding(14)
      .margin({ top: 12 })
      .backgroundColor('#161B22')
      .borderRadius(12)

      if (this.subscriptions.length === 0) {
        Column() {
          Text('暂无订阅')
            .fontSize(15)
            .fontColor('#8B949E')
          Text('添加 Clash 订阅链接后即可选择节点')
            .fontSize(12)
            .fontColor('#484F58')
            .margin({ top: 8 })
        }
        .width('100%')
        .margin({ top: 60 })
      } else {
        List({ space: 12 }) {
          ForEach(this.subscriptions, (sub: Subscription) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Row() {
                      Text(sub.name)
                        .fontSize(15)
                        .fontColor('#E6EDF3')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      if (this.activeId === sub.id) {
                        Text('当前')
                          .fontSize(10)
                          .fontColor('#3FB950')
                          .backgroundColor('#12261E')
                          .borderRadius(4)
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .margin({ left: 8 })
                      }
                    }

                    Text(sub.nodes.length.toString() + ' 个节点 · 更新于 ' + this.formatTime(sub.updatedAt))
                      .fontSize(12)
                      .fontColor('#8B949E')
                      .margin({ top: 4 })

                    Text(sub.url)
                      .fontSize(11)
                      .fontColor('#484F58')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('删除')
                    .fontSize(12)
                    .fontColor('#F85149')
                    .padding(8)
                    .onClick(() => {
                      this.removeSubscription(sub.id);
                    })
                }
                .width('100%')

                Button(this.activeId === sub.id ? '当前订阅' : '设为当前')
                  .width('100%')
                  .height(30)
                  .fontSize(12)
                  .backgroundColor(this.activeId === sub.id ? '#21262D' : '#1F6FEB')
                  .fontColor(this.activeId === sub.id ? '#8B949E' : '#FFFFFF')
                  .enabled(this.activeId !== sub.id)
                  .margin({ top: 10 })
                  .onClick(() => {
                    this.setActive(sub.id);
                  })
              }
              .padding(14)
              .backgroundColor('#161B22')
              .borderRadius(12)
            }
          }, (sub: Subscription) => sub.id)
        }
        .width('92%')
        .layoutWeight(1)
        .margin({ top: 12 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D1117')
  }
}
