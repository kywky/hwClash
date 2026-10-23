import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AppSettings, ProxyMode, Subscription, createDefaultSettings } from '../model/Types';
import {
  DEFAULT_MIXED_PORT,
  KEY_CONTROLLER_SECRET,
  KEY_RUNTIME_CONFIG,
  KEY_SETTINGS,
  KEY_SUBSCRIPTIONS,
  KEY_VPN_ACTIVE,
  PREF_STORE_NAME
} from '../common/Constants';

export class PreferencesUtil {
  private static store: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (PreferencesUtil.store === null) {
      PreferencesUtil.store = await preferences.getPreferences(context, PREF_STORE_NAME);
    }
  }

  private static async ensureStore(): Promise<preferences.Preferences> {
    if (PreferencesUtil.store === null) {
      throw new Error('PreferencesUtil.init must be called first');
    }
    return PreferencesUtil.store;
  }

  static async loadSubscriptions(): Promise<Subscription[]> {
    const store = await PreferencesUtil.ensureStore();
    const raw = await store.get(KEY_SUBSCRIPTIONS, '[]') as string;
    try {
      return JSON.parse(raw) as Subscription[];
    } catch (error) {
      return [];
    }
  }

  static async saveSubscriptions(list: Subscription[]): Promise<void> {
    const store = await PreferencesUtil.ensureStore();
    await store.put(KEY_SUBSCRIPTIONS, JSON.stringify(list));
    await store.flush();
  }

  static async loadSettings(): Promise<AppSettings> {
    const store = await PreferencesUtil.ensureStore();
    const raw = await store.get(KEY_SETTINGS, '') as string;
    const defaults = createDefaultSettings();
    if (raw === '') {
      return defaults;
    }
    try {
      const stored = JSON.parse(raw) as AppSettings;
      return {
        mode: stored.mode ? stored.mode : ProxyMode.RULE,
        selectedNode: stored.selectedNode ? stored.selectedNode : '',
        activeSubscriptionId: stored.activeSubscriptionId ? stored.activeSubscriptionId : '',
        allowLan: stored.allowLan === true,
        ipv6: stored.ipv6 !== false,
        mixedPort: stored.mixedPort ? stored.mixedPort : DEFAULT_MIXED_PORT,
        autoConnect: stored.autoConnect === true
      };
    } catch (error) {
      return defaults;
    }
  }

  static async saveSettings(settings: AppSettings): Promise<void> {
    const store = await PreferencesUtil.ensureStore();
    await store.put(KEY_SETTINGS, JSON.stringify(settings));
    await store.flush();
  }

  static async saveRuntimeConfig(config: string): Promise<void> {
    const store = await PreferencesUtil.ensureStore();
    await store.put(KEY_RUNTIME_CONFIG, config);
    await store.flush();
  }

  static async loadRuntimeConfig(): Promise<string> {
    const store = await PreferencesUtil.ensureStore();
    return await store.get(KEY_RUNTIME_CONFIG, '') as string;
  }

  static async loadControllerSecret(): Promise<string> {
    const store = await PreferencesUtil.ensureStore();
    return await store.get(KEY_CONTROLLER_SECRET, '') as string;
  }

  static async saveControllerSecret(secret: string): Promise<void> {
    const store = await PreferencesUtil.ensureStore();
    await store.put(KEY_CONTROLLER_SECRET, secret);
    await store.flush();
  }

  static async setVpnActive(active: boolean): Promise<void> {
    const store = await PreferencesUtil.ensureStore();
    await store.put(KEY_VPN_ACTIVE, active);
    await store.flush();
  }

  static async isVpnActive(): Promise<boolean> {
    const store = await PreferencesUtil.ensureStore();
    return await store.get(KEY_VPN_ACTIVE, false) as boolean;
  }

  static async ensureControllerSecret(): Promise<string> {
    const store = await PreferencesUtil.ensureStore();
    let secret = await store.get(KEY_CONTROLLER_SECRET, '') as string;
    if (secret === '') {
      secret = util.generateRandomUUID(false);
      await store.put(KEY_CONTROLLER_SECRET, secret);
      await store.flush();
    }
    return secret;
  }
}
