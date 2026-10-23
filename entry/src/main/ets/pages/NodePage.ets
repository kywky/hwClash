import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppSettings, ProxyNode, Subscription, createDefaultSettings } from '../model/Types';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { ClashApi } from '../utils/ClashApi';

@Entry
@Component
struct NodePage {
  @State nodes: ProxyNode[] = [];
  @State delays: string[] = [];
  @State selected: string = '';
  @State subName: string = '';
  @State connected: boolean = false;
  @State testingIndex: number = -1;
  private settings: AppSettings = createDefaultSettings();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private controllerSecret: string = '';

  aboutToAppear(): void {
    this.loadState();
  }

  private async loadState(): Promise<void> {
    await PreferencesUtil.init(this.context);
    this.settings = await PreferencesUtil.loadSettings();
    this.selected = this.settings.selectedNode;
    this.controllerSecret = await PreferencesUtil.ensureControllerSecret();
    const subs = await PreferencesUtil.loadSubscriptions();
    let active: Subscription | null = null;
    for (const sub of subs) {
      if (sub.id === this.settings.activeSubscriptionId) {
        active = sub;
        break;
      }
    }
    if (active === null && subs.length > 0) {
      active = subs[0];
    }
    if (active !== null) {
      this.nodes = active.nodes;
      this.subName = active.name;
      let texts: string[] = [];
      for (let i = 0; i < active.nodes.length; i++) {
        texts.push('');
      }
      this.delays = texts;
    }
    this.connected = await ClashApi.ping(this.controllerSecret);
  }

  private async selectNode(name: string): Promise<void> {
    this.selected = name;
    this.settings.selectedNode = name;
    await PreferencesUtil.saveSettings(this.settings);
    if (this.connected) {
      ClashApi.selectProxy(this.controllerSecret, 'PROXY', name).then(() => {
        promptAction.showToast({ message: '已切换节点：' + name });
      }).catch(() => {
        promptAction.showToast({ message: '已保存，重连后生效：' + name });
      });
    } else {
      promptAction.showToast({ message: '已选择：' + name });
    }
  }

  private async testDelay(index: number): Promise<void> {
    if (this.testingIndex >= 0 || !this.connected) {
      return;
    }
    this.testingIndex = index;
    this.delays[index] = '...';
    const result = await ClashApi.delay(this.controllerSecret, this.nodes[index].name);
    if (result.ok) {
      this.delays[index] = result.delay.toString() + ' ms';
    } else {
      this.delays[index] = '超时';
    }
    this.testingIndex = -1;
  }

  @Builder
  NodeRow(item: ProxyNode, index: number) {
    Row() {
      Column() {
        Text(item.name)
          .fontSize(14)
          .fontColor(this.selected === item.name ? '#58A6FF' : '#E6EDF3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.type.toUpperCase())
          .fontSize(11)
          .fontColor('#8B949E')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.delays.length > index && this.delays[index] !== '' ? this.delays[index] : '测速')
        .fontSize(11)
        .fontColor(this.delays.length > index && this.delays[index] === '超时' ? '#F85149' : '#3FB950')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('#0D1117')
        .borderRadius(8)
        .opacity(this.testingIndex === index || !this.connected ? 0.5 : 1)
        .onClick(() => {
          this.testDelay(index);
        })

      if (this.selected === item.name) {
        Text('已选')
          .fontSize(11)
          .fontColor('#3FB950')
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#161B22')
    .borderRadius(10)
    .onClick(() => {
      this.selectNode(item.name);
    })
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
        Column() {
          Text('节点选择')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#E6EDF3')
          Text(this.connected ? '连接中，切换立即生效' : '未连接，选择将在连接时生效')
            .fontSize(11)
            .fontColor(this.connected ? '#3FB950' : '#8B949E')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      if (this.nodes.length === 0) {
        Column() {
          Text('没有可用节点')
            .fontSize(15)
            .fontColor('#8B949E')
          Button('去添加订阅')
            .height(36)
            .fontSize(13)
            .backgroundColor('#1F6FEB')
            .fontColor('#FFFFFF')
            .margin({ top: 16 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/SubscriptionPage' });
            })
        }
        .width('100%')
        .margin({ top: 80 })
      } else {
        List({ space: 10 }) {
          ForEach(this.nodes, (item: ProxyNode, index: number) => {
            ListItem() {
              this.NodeRow(item, index)
            }
          }, (item: ProxyNode, index: number) => item.name + '|' + item.type + '|' + index)
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
