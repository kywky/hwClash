import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppSettings, ProxyNode, Subscription, createDefaultSettings } from '../model/Types';
import { PreferencesUtil } from '../utils/PreferencesUtil';

@Entry
@Component
struct NodePage {
  @State nodes: ProxyNode[] = [];
  @State selected: string = '';
  @State subName: string = '';
  private settings: AppSettings = createDefaultSettings();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.loadState();
  }

  private async loadState(): Promise<void> {
    await PreferencesUtil.init(this.context);
    this.settings = await PreferencesUtil.loadSettings();
    this.selected = this.settings.selectedNode;
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
    }
  }

  private async selectNode(name: string): Promise<void> {
    this.selected = name;
    this.settings.selectedNode = name;
    await PreferencesUtil.saveSettings(this.settings);
    promptAction.showToast({ message: '已选择：' + name });
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
          if (this.subName !== '') {
            Text(this.subName)
              .fontSize(11)
              .fontColor('#8B949E')
              .margin({ top: 2 })
          }
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
          ForEach(this.nodes, (item: ProxyNode) => {
            ListItem() {
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

                if (this.selected === item.name) {
                  Text('已选')
                    .fontSize(11)
                    .fontColor('#3FB950')
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
          }, (item: ProxyNode) => item.name + '|' + item.type)
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
