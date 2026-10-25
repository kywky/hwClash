import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppSettings, ProxyMode, createDefaultSettings, modeLabel } from '../model/Types';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { ClashApi } from '../utils/ClashApi';
import { defaultRuleList } from '../utils/ConfigBuilder';

@Entry
@Component
struct RulesPage {
  @State mode: string = ProxyMode.RULE;
  private settings: AppSettings = createDefaultSettings();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private controllerSecret: string = '';

  aboutToAppear(): void {
    this.loadState();
  }

  private async loadState(): Promise<void> {
    await PreferencesUtil.init(this.context);
    this.settings = await PreferencesUtil.loadSettings();
    this.mode = this.settings.mode;
    this.controllerSecret = await PreferencesUtil.ensureControllerSecret();
  }

  private async changeMode(value: string): Promise<void> {
    this.mode = value;
    this.settings.mode = value;
    await PreferencesUtil.saveSettings(this.settings);
    if (await ClashApi.ping(this.controllerSecret)) {
      try {
        const runtimeConfig = await PreferencesUtil.loadRuntimeConfig();
        await ClashApi.setMode(this.controllerSecret, value, runtimeConfig);
        if (this.settings.selectedNode !== '') {
          await ClashApi.selectProxy(this.controllerSecret, 'PROXY', this.settings.selectedNode);
        }
        promptAction.showToast({ message: '已切换为' + modeLabel(value) + '模式，立即生效' });
        return;
      } catch (error) {
      }
    }
    promptAction.showToast({ message: '已切换为' + modeLabel(value) + '模式，重连后生效' });
  }

  private modeHint(): string {
    if (this.mode === ProxyMode.GLOBAL) {
      return '所有流量都经过所选节点';
    }
    if (this.mode === ProxyMode.DIRECT) {
      return '所有流量不经过代理（VPN 仍会建立，便于测试）';
    }
    return '国内流量直连，其余流量经过所选节点';
  }

  @Builder
  ModeOption(title: string, value: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(this.mode === value ? '#58A6FF' : '#E6EDF3')
        Text(value === ProxyMode.RULE ? '规则分流' : (value === ProxyMode.GLOBAL ? '全局代理' : '直连'))
          .fontSize(11)
          .fontColor('#8B949E')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.mode === value ? '●' : '○')
        .fontSize(14)
        .fontColor(this.mode === value ? '#58A6FF' : '#484F58')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#161B22')
    .borderRadius(10)
    .onClick(() => {
      this.changeMode(value);
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
        Text('路由与规则')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#E6EDF3')
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      Scroll() {
        Column() {
          Column({ space: 10 }) {
            this.ModeOption('规则', ProxyMode.RULE)
            this.ModeOption('全局', ProxyMode.GLOBAL)
            this.ModeOption('直连', ProxyMode.DIRECT)
          }
          .width('100%')

          Text(this.modeHint())
            .fontSize(12)
            .fontColor('#8B949E')
            .width('100%')
            .margin({ top: 12 })

          Text('内置规则')
            .fontSize(13)
            .fontColor('#E6EDF3')
            .width('100%')
            .margin({ top: 24, bottom: 8 })

          Column() {
            ForEach(defaultRuleList(), (rule: string, index: number) => {
              Row() {
                Text((index + 1).toString())
                  .fontSize(11)
                  .fontColor('#484F58')
                  .width(24)
                Text(rule)
                  .fontSize(12)
                  .fontColor('#C9D1D9')
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 7, bottom: 7 })
            }, (rule: string) => rule)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .backgroundColor('#161B22')
          .borderRadius(10)

          Text('说明：规则由本地生成（私有网段直连 + 其余走代理）。订阅自带规则集与 GEOIP 分流将在后续版本支持。')
            .fontSize(11)
            .fontColor('#484F58')
            .width('100%')
            .margin({ top: 12, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D1117')
  }
}
