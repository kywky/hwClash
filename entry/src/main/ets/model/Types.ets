import { DEFAULT_MIXED_PORT } from '../common/Constants';

export interface ProxyNode {
  name: string;
  type: string;
}

export interface Subscription {
  id: string;
  name: string;
  url: string;
  updatedAt: number;
  rawConfig: string;
  nodes: ProxyNode[];
}

export interface AppSettings {
  mode: string;
  selectedNode: string;
  activeSubscriptionId: string;
  allowLan: boolean;
  ipv6: boolean;
  mixedPort: number;
  autoConnect: boolean;
}

export class ProxyMode {
  static readonly RULE: string = 'rule';
  static readonly GLOBAL: string = 'global';
  static readonly DIRECT: string = 'direct';
}

export function modeLabel(mode: string): string {
  if (mode === ProxyMode.GLOBAL) {
    return '全局';
  }
  if (mode === ProxyMode.DIRECT) {
    return '直连';
  }
  return '规则';
}

export function createDefaultSettings(): AppSettings {
  return {
    mode: ProxyMode.RULE,
    selectedNode: '',
    activeSubscriptionId: '',
    allowLan: false,
    ipv6: true,
    mixedPort: DEFAULT_MIXED_PORT,
    autoConnect: false
  };
}
