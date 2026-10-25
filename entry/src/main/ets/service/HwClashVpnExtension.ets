import { VpnExtensionAbility, vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { initCore, startCore, stopCore, notifyProtected } from 'libhwclash.so';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import {
  DEFAULT_CONTROLLER_PORT,
  TUN_DNS_V4,
  TUN_IPV4_ADDRESS,
  TUN_IPV4_CIDR,
  TUN_IPV4_PREFIX,
  TUN_IPV6_ADDRESS,
  TUN_IPV6_CIDR,
  TUN_IPV6_PREFIX,
  TUN_MTU
} from '../common/Constants';

const TAG: string = 'HwClashVpn';
const RUNTIME_CONFIG_FILE: string = '/runtime.yaml';

interface CoreStartOptions {
  configPath: string;
  controllerAddr: string;
  secret: string;
  mtu: number;
  tunIPv4: string;
  tunIPv6: string;
  dnsHijack: string[];
}

export default class HwClashVpnExtension extends VpnExtensionAbility {
  private connection: vpnExtension.VpnConnection | undefined = undefined;
  private tunFd: number = -1;
  private coreStarted: boolean = false;

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
      const settings = await PreferencesUtil.loadSettings();
      const secret = await PreferencesUtil.ensureControllerSecret();

      const initError = initCore(this.context.filesDir);
      if (initError !== '') {
        throw new Error('initCore: ' + initError);
      }
      const configPath = this.context.filesDir + RUNTIME_CONFIG_FILE;
      this.writeTextFile(configPath, runtimeConfig);

      this.connection = vpnExtension.createVpnConnection(this.context);
      this.tunFd = await this.connection.create(this.buildVpnConfig(settings.ipv6));
      hilog.info(0x0000, TAG, 'VPN created, tun fd: %{public}d', this.tunFd);

      const options: CoreStartOptions = {
        configPath: configPath,
        controllerAddr: '127.0.0.1:' + DEFAULT_CONTROLLER_PORT.toString(),
        secret: secret,
        mtu: TUN_MTU,
        tunIPv4: TUN_IPV4_CIDR,
        tunIPv6: settings.ipv6 ? TUN_IPV6_CIDR : '',
        dnsHijack: []
      };
      const protectCallback = (id: number, fd: number): void => {
        this.protectSocket(id, fd);
      };
      const startError = await startCore(this.tunFd, JSON.stringify(options), protectCallback);
      if (startError !== '') {
        throw new Error('startCore: ' + startError);
      }
      this.coreStarted = true;
      await PreferencesUtil.setVpnActive(true);
      hilog.info(0x0000, TAG, 'Mihomo core started');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'Start VPN failed: %{public}s', err.message);
      await this.cleanup();
    }
  }

  private buildVpnConfig(ipv6: boolean): vpnExtension.VpnConfig {
    const addresses: vpnExtension.LinkAddress[] = [
      {
        address: { address: TUN_IPV4_ADDRESS, family: 1 },
        prefixLength: TUN_IPV4_PREFIX
      }
    ];
    const routes: vpnExtension.RouteInfo[] = [
      {
        interface: 'vpn-tun',
        destination: { address: { address: '0.0.0.0', family: 1 }, prefixLength: 0 },
        gateway: { address: '0.0.0.0', family: 1 },
        hasGateway: false,
        isDefaultRoute: true
      }
    ];
    const dnsAddresses: string[] = [TUN_DNS_V4];
    if (ipv6) {
      addresses.push({
        address: { address: TUN_IPV6_ADDRESS, family: 2 },
        prefixLength: TUN_IPV6_PREFIX
      });
      routes.push({
        interface: 'vpn-tun',
        destination: { address: { address: '::', family: 2 }, prefixLength: 0 },
        gateway: { address: '::', family: 2 },
        hasGateway: false,
        isDefaultRoute: true
      });
      dnsAddresses.push('fdfe:dcba:9876::2');
    }
    return {
      addresses: addresses,
      routes: routes,
      dnsAddresses: dnsAddresses,
      searchDomains: [],
      mtu: TUN_MTU,
      isIPv4Accepted: true,
      isIPv6Accepted: ipv6,
      isBlocking: false,
      trustedApplications: [],
      blockedApplications: []
    };
  }

  private writeTextFile(path: string, content: string): void {
    const file = fileIo.openSync(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, content);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private protectSocket(id: number, fd: number): void {
    if (this.connection === undefined) {
      notifyProtected(id);
      return;
    }
    this.connection.protect(fd).then(() => {
      notifyProtected(id);
    }).catch((error: BusinessError) => {
      hilog.warn(0x0000, TAG, 'protect failed: %{public}s', error.message);
      notifyProtected(id);
    });
  }

  private async cleanup(): Promise<void> {
    try {
      if (this.coreStarted) {
        stopCore();
        this.coreStarted = false;
      }
      if (this.connection !== undefined) {
        await this.connection.destroy();
        this.connection = undefined;
      }
      this.tunFd = -1;
      await PreferencesUtil.setVpnActive(false);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'Cleanup failed: %{public}s', err.message);
    }
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'VPN extension onDestroy');
    this.cleanup();
  }
}
