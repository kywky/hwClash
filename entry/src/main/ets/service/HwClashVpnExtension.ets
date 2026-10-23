import { VpnExtensionAbility, vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreferencesUtil } from '../utils/PreferencesUtil';

const TAG: string = 'HwClashVpn';

export default class HwClashVpnExtension extends VpnExtensionAbility {
  private connection: vpnExtension.VpnConnection | undefined = undefined;
  private tunFd: number = -1;

  onCreate(want: Want): void {
    hilog.info(0x0000, TAG, 'VPN extension onCreate');
    this.startVpn();
  }

  private async startVpn(): Promise<void> {
    try {
      await PreferencesUtil.init(this.context);
      const runtimeConfig = await PreferencesUtil.loadRuntimeConfig();
      if (runtimeConfig === '') {
        hilog.error(0x0000, TAG, 'No runtime config, abort VPN creation');
        return;
      }

      this.connection = vpnExtension.createVpnConnection(this.context);
      const vpnConfig: vpnExtension.VpnConfig = {
        addresses: [
          {
            address: { address: '198.18.0.1', family: 1 },
            prefixLength: 30
          }
        ],
        routes: [
          {
            interface: 'vpn-tun',
            destination: { address: { address: '0.0.0.0', family: 1 }, prefixLength: 0 },
            gateway: { address: '0.0.0.0', family: 1 },
            hasGateway: false,
            isDefaultRoute: true
          }
        ],
        dnsAddresses: ['223.5.5.5', '119.29.29.29'],
        searchDomains: [],
        mtu: 1500,
        isIPv4Accepted: true,
        isIPv6Accepted: true,
        isBlocking: false,
        trustedApplications: [],
        blockedApplications: []
      };
      this.tunFd = await this.connection.create(vpnConfig);
      await PreferencesUtil.setVpnActive(true);
      hilog.info(0x0000, TAG, 'VPN created, tun fd: %{public}d', this.tunFd);

      // TODO: hand tunFd and runtimeConfig to the Mihomo core once the native
      // library is integrated. Until then the VPN interface carries no traffic.
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'Create VPN failed: %{public}d %{public}s', err.code, err.message);
      await PreferencesUtil.setVpnActive(false);
    }
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'VPN extension onDestroy');
    this.destroyVpn();
  }

  private async destroyVpn(): Promise<void> {
    try {
      if (this.connection !== undefined) {
        await this.connection.destroy();
        this.connection = undefined;
      }
      this.tunFd = -1;
      await PreferencesUtil.setVpnActive(false);
      hilog.info(0x0000, TAG, 'VPN destroyed');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'Destroy VPN failed: %{public}d %{public}s', err.code, err.message);
    }
  }
}
