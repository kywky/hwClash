import { router, promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppSettings, ProxyMode, Subscription, createDefaultSettings, modeLabel } from '../model/Types';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { buildRuntimeConfig } from '../utils/ConfigBuilder';
import { BUNDLE_NAME, VPN_EXTENSION_NAME } from '../common/Constants';

@Entry
@Component
struct Index {
  @State connected: boolean = false;
  @State busy: boolean = false;
  @State mode: string = ProxyMode.RULE;
  @State selectedNode: string = '';
  @State subCount: number = 0;
  @State nodeCount: number = 0;
  private settings: AppSettings = createDefaultSettings();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.initState();
  }

  onPageShow(): void {
    this.refreshSummary();
  }

  private async initState(): Promise<void> {
    await PreferencesUtil.init(this.context);
    this.settings = await PreferencesUtil.loadSettings();
    this.mode = this.settings.mode;
    this.connected = await PreferencesUtil.isVpnActive();
    await this.refreshSummary();
  }

  private async refreshSummary(): Promise<void> {
    const subs = await PreferencesUtil.loadSubscriptions();
    this.subCount = subs.length;
    let total = 0;
    for (const sub of subs) {
      total += sub.nodes.length;
    }
    this.nodeCount = total;

    const active = this.findActive(subs);
    if (active !== null && active.nodes.length > 0) {
      let names: string[] = [];
      for (const node of active.nodes) {
        names.push(node.name);
      }
      if (this.settings.selectedNode === '' || names.indexOf(this.settings.selectedNode) < 0) {
        this.settings.selectedNode = active.nodes[0].name;
        await PreferencesUtil.saveSettings(this.settings);
      }
      this.selectedNode = this.settings.selectedNode;
    } else {
      this.selectedNode = '';
    }
  }

  private findActive(subs: Subscription[]): Subscription | null {
    if (subs.length === 0) {
      return null;
    }
    for (const sub of subs) {
      if (sub.id === this.settings.activeSubscriptionId) {
        return sub;
      }
    }
    return subs[0];
  }

  private currentModeLabel(): string {
    return modeLabel(this.mode);
  }

  private changeMode(value: string): void {
    if (this.mode === value) {
      return;
    }
    this.mode = value;
    this.settings.mode = value;
    PreferencesUtil.saveSettings(this.settings);
    if (this.connected) {
      promptAction.showToast({ message: '模式已保存，重连后生效' });
    }
  }

  private async toggleVpn(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const want: Want = {
      bundleName: BUNDLE_NAME,
      abilityName: VPN_EXTENSION_NAME
    };
    try {
      if (this.connected) {
        await vpnExtension.stopVpnExtensionAbility(want);
        this.connected = false;
        await PreferencesUtil.setVpnActive(false);
        promptAction.showToast({ message: '已断开连接' });
        return;
      }

      const subs = await PreferencesUtil.loadSubscriptions();
      const active = this.findActive(subs);
      if (active === null || active.nodes.length === 0) {
        promptAction.showToast({ message: '请先添加订阅' });
        return;
      }
      const runtimeConfig = buildRuntimeConfig(active.rawConfig, this.settings.mode, this.settings.selectedNode,
        this.settings.mixedPort, this.settings.allowLan, this.settings.ipv6);
      await PreferencesUtil.saveRuntimeConfig(runtimeConfig);
      await PreferencesUtil.setVpnActive(false);

      await vpnExtension.startVpnExtensionAbility(want);
      this.connected = true;
      await PreferencesUtil.setVpnActive(true);
      promptAction.showToast({ message: 'VPN 已启动' });
    } catch (error) {
      const err = error as BusinessError;
      this.connected = await PreferencesUtil.isVpnActive();
      promptAction.showToast({ message: '操作失败：' + err.message });
    } finally {
      this.busy = false;
    }
  }

  @Builder
  ModeChip(label: string, value: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.mode === value ? '#FFFFFF' : '#8B949E')
      .backgroundColor(this.mode === value ? '#1F6FEB' : Color.Transparent)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .borderRadius(9)
      .onClick(() => {
        this.changeMode(value);
      })
  }

  @Builder
  StatItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#E6EDF3')
      Text(label)
        .fontSize(11)
        .fontColor('#8B949E')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  NavCard(title: string, subtitle: string, url: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor('#E6EDF3')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#8B949E')
          .margin({ top: 3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('>')
        .fontSize(15)
        .fontColor('#484F58')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .onClick(() => {
      router.pushUrl({ url: url });
    })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('hwClash')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E6EDF3')
          Text(this.connected ? 'VPN 已连接' : 'VPN 未连接')
            .fontSize(13)
            .fontColor(this.connected ? '#3FB950' : '#8B949E')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.currentModeLabel())
          .fontSize(12)
          .fontColor('#58A6FF')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#161B22')
          .borderRadius(8)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20 })

      Button() {
        Column() {
          Text(this.busy ? '处理中...' : (this.connected ? '断开' : '连接'))
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
          Text(this.selectedNode === '' ? '无可用节点' : this.selectedNode)
            .fontSize(12)
            .fontColor('#C9D1D9')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 160 })
            .margin({ top: 8 })
        }
      }
      .width(176)
      .height(176)
      .borderRadius(88)
      .backgroundColor(this.connected ? '#1F6FEB' : '#21262D')
      .borderWidth(2)
      .borderColor(this.connected ? '#58A6FF' : '#30363D')
      .enabled(!this.busy)
      .onClick(() => {
        this.toggleVpn();
      })
      .margin({ top: 28, bottom: 24 })

      Row() {
        this.ModeChip('规则', ProxyMode.RULE)
        this.ModeChip('全局', ProxyMode.GLOBAL)
        this.ModeChip('直连', ProxyMode.DIRECT)
      }
      .width('90%')
      .padding(4)
      .backgroundColor('#161B22')
      .borderRadius(12)

      Row() {
        this.StatItem('上传', '0 B')
        Divider()
          .vertical(true)
          .height(28)
          .color('#30363D')
        this.StatItem('下载', '0 B')
        Divider()
          .vertical(true)
          .height(28)
          .color('#30363D')
        this.StatItem('节点', this.nodeCount.toString())
      }
      .width('90%')
      .margin({ top: 16 })
      .padding({ top: 14, bottom: 14 })
      .backgroundColor('#161B22')
      .borderRadius(12)

      Column() {
        this.NavCard('节点选择', this.selectedNode === '' ? '尚未选择' : this.selectedNode, 'pages/NodePage')
        this.NavCard('订阅管理',
          this.subCount.toString() + ' 个订阅 · ' + this.nodeCount.toString() + ' 个节点',
          'pages/SubscriptionPage')
        this.NavCard('路由与规则', '当前模式：' + this.currentModeLabel(), 'pages/RulesPage')
        this.NavCard('设置', '端口、局域网、IPv6', 'pages/SettingsPage')
      }
      .width('90%')
      .margin({ top: 16 })
      .padding({ left: 4, right: 4 })
      .backgroundColor('#161B22')
      .borderRadius(12)

      Text('核心：Mihomo（尚未集成）')
        .fontSize(11)
        .fontColor('#484F58')
        .margin({ top: 16 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D1117')
  }
}
