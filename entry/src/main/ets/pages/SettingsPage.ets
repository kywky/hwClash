import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppSettings, createDefaultSettings } from '../model/Types';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { APP_VERSION, DEFAULT_MIXED_PORT } from '../common/Constants';

@Entry
@Component
struct SettingsPage {
  @State allowLan: boolean = false;
  @State ipv6: boolean = true;
  @State autoConnect: boolean = false;
  @State portText: string = DEFAULT_MIXED_PORT.toString();
  private settings: AppSettings = createDefaultSettings();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.loadState();
  }

  private async loadState(): Promise<void> {
    await PreferencesUtil.init(this.context);
    this.settings = await PreferencesUtil.loadSettings();
    this.allowLan = this.settings.allowLan;
    this.ipv6 = this.settings.ipv6;
    this.autoConnect = this.settings.autoConnect;
    this.portText = this.settings.mixedPort.toString();
  }

  private async save(): Promise<void> {
    const port = Number.parseInt(this.portText);
    if (!(port >= 1024 && port <= 65535)) {
      promptAction.showToast({ message: '端口需在 1024 - 65535 之间' });
      return;
    }
    this.settings.allowLan = this.allowLan;
    this.settings.ipv6 = this.ipv6;
    this.settings.autoConnect = this.autoConnect;
    this.settings.mixedPort = port;
    await PreferencesUtil.saveSettings(this.settings);
    promptAction.showToast({ message: '设置已保存' });
  }

  @Builder
  SwitchRow(title: string, subtitle: string, key: string, isOn: boolean) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor('#E6EDF3')
        Text(subtitle)
          .fontSize(11)
          .fontColor('#8B949E')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#1F6FEB')
        .onChange((value: boolean) => {
          if (key === 'allowLan') {
            this.allowLan = value;
          } else if (key === 'ipv6') {
            this.ipv6 = value;
          } else {
            this.autoConnect = value;
          }
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#161B22')
    .borderRadius(10)
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
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#E6EDF3')
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      Scroll() {
        Column() {
          this.SwitchRow('允许局域网连接', '允许同一局域网内的设备使用代理（需核心支持）', 'allowLan', this.allowLan)

          this.SwitchRow('IPv6', '在代理配置中启用 IPv6 支持', 'ipv6', this.ipv6)

          this.SwitchRow('自动连接', '启动应用时自动建立 VPN（后续版本支持）', 'autoConnect', this.autoConnect)

          Row() {
            Column() {
              Text('混合端口')
                .fontSize(15)
                .fontColor('#E6EDF3')
              Text('HTTP / SOCKS5 共用端口')
                .fontSize(11)
                .fontColor('#8B949E')
                .margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            TextInput({ text: this.portText })
              .width(90)
              .height(36)
              .type(InputType.Number)
              .backgroundColor('#0D1117')
              .fontColor('#E6EDF3')
              .textAlign(TextAlign.End)
              .borderRadius(8)
              .onChange((value: string) => {
                this.portText = value;
              })
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor('#161B22')
          .borderRadius(10)
          .margin({ top: 10 })

          Button('保存设置')
            .width('100%')
            .height(42)
            .margin({ top: 20 })
            .backgroundColor('#1F6FEB')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.save();
            })

          Column() {
            Text('关于 hwClash')
              .fontSize(13)
              .fontColor('#E6EDF3')
              .width('100%')
            Text('版本：' + APP_VERSION)
              .fontSize(12)
              .fontColor('#8B949E')
              .width('100%')
              .margin({ top: 8 })
            Text('代理核心：Mihomo（尚未集成）')
              .fontSize(12)
              .fontColor('#8B949E')
              .width('100%')
              .margin({ top: 4 })
            Text('本应用仅用于学习与合法的网络代理场景，请遵守当地法律法规。')
              .fontSize(11)
              .fontColor('#484F58')
              .width('100%')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(14)
          .margin({ top: 24, bottom: 24 })
          .backgroundColor('#161B22')
          .borderRadius(10)
        }
        .width('92%')
        .padding({ top: 8 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D1117')
  }
}
