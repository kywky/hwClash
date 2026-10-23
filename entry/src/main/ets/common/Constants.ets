export const PREF_STORE_NAME: string = 'hwclash_prefs';
export const KEY_SUBSCRIPTIONS: string = 'subscriptions';
export const KEY_SETTINGS: string = 'settings';
export const KEY_RUNTIME_CONFIG: string = 'runtime_config';
export const KEY_VPN_ACTIVE: string = 'vpn_active';
export const KEY_CONTROLLER_SECRET: string = 'controller_secret';

export const BUNDLE_NAME: string = 'com.hwclash.app';
export const VPN_EXTENSION_NAME: string = 'HwClashVpnExtension';

export const DEFAULT_MIXED_PORT: number = 7890;
export const DEFAULT_CONTROLLER_PORT: number = 9090;
export const APP_VERSION: string = '0.2.0';

// TUN parameters must stay in sync between the VpnConfig in the VPN
// extension and the StartOptions passed to the Go core.
export const TUN_IPV4_ADDRESS: string = '172.19.0.1';
export const TUN_IPV4_PREFIX: number = 30;
export const TUN_IPV4_CIDR: string = '172.19.0.1/30';
export const TUN_IPV6_ADDRESS: string = 'fdfe:dcba:9876::1';
export const TUN_IPV6_PREFIX: number = 126;
export const TUN_IPV6_CIDR: string = 'fdfe:dcba:9876::1/126';
export const TUN_DNS_V4: string = '172.19.0.2';
export const TUN_DNS_V6: string = 'fdfe:dcba:9876::2';
export const TUN_MTU: number = 1500;
