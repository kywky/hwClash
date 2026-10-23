import { util } from '@kit.ArkTS';
import { ProxyNode } from '../model/Types';

const TOP_LEVEL_OVERRIDE_KEYS: string[] = [
  'mixed-port',
  'port',
  'socks-port',
  'allow-lan',
  'mode',
  'log-level',
  'ipv6'
];

export function decodeSubscription(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed === '') {
    return raw;
  }
  if (trimmed.indexOf('proxies:') >= 0 || trimmed.indexOf('proxy-groups:') >= 0 ||
    trimmed.indexOf('rules:') >= 0) {
    return raw;
  }
  const compact = trimmed.replace(/\s/g, '');
  if (!/^[A-Za-z0-9+/=]+$/.test(compact)) {
    return raw;
  }
  try {
    const helper = new util.Base64Helper();
    const bytes: Uint8Array = helper.decodeSync(compact);
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  } catch (error) {
    return raw;
  }
}

export function extractSection(config: string, key: string): string {
  const lines = config.split('\n');
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(key + ':')) {
      start = i;
      break;
    }
  }
  if (start < 0) {
    return '';
  }
  const output: string[] = [];
  for (let i = start; i < lines.length; i++) {
    const line = lines[i];
    if (i > start) {
      if (line.trim() === '') {
        output.push(line);
        continue;
      }
      const indented = line.startsWith(' ') || line.startsWith('\t') || line.startsWith('-');
      if (!indented) {
        break;
      }
    }
    output.push(line);
  }
  return output.join('\n');
}

function parseQuotedOrPlain(entry: string, key: string): string {
  const quoted = entry.match(new RegExp(key + ':\\s*["\']([^"\'\\n\\r]+)["\']'));
  if (quoted !== null && quoted.length > 1) {
    return quoted[1].trim();
  }
  const plain = entry.match(new RegExp(key + ':\\s*([^"\'\\n\\r,}]+)'));
  if (plain !== null && plain.length > 1) {
    return plain[1].trim();
  }
  return '';
}

export function extractNodes(config: string): ProxyNode[] {
  const nodes: ProxyNode[] = [];
  const block = extractSection(config, 'proxies');
  if (block === '') {
    return nodes;
  }
  const entries = block.split(/\n(?=\s*-\s+)/);
  for (let i = 0; i < entries.length; i++) {
    let entry = entries[i];
    if (i === 0) {
      const newlineIndex = entry.indexOf('\n');
      if (newlineIndex < 0) {
        continue;
      }
      entry = entry.substring(newlineIndex + 1);
    }
    if (entry.trim() === '') {
      continue;
    }
    const name = parseQuotedOrPlain(entry, 'name');
    if (name === '') {
      continue;
    }
    let type = parseQuotedOrPlain(entry, 'type');
    if (type === '') {
      type = 'unknown';
    }
    nodes.push({ name: name, type: type });
  }
  return nodes;
}

function yamlQuote(value: string): string {
  return '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

function stripTopLevelKeys(config: string, keys: string[]): string {
  const lines = config.split('\n');
  const output: string[] = [];
  for (const line of lines) {
    let drop = false;
    for (const key of keys) {
      if (line.startsWith(key + ':')) {
        drop = true;
        break;
      }
    }
    if (!drop) {
      output.push(line);
    }
  }
  return output.join('\n');
}

function orderNodes(nodes: ProxyNode[], selectedNode: string): ProxyNode[] {
  const ordered: ProxyNode[] = [];
  let selected: ProxyNode | null = null;
  for (const node of nodes) {
    if (node.name === selectedNode) {
      selected = node;
    } else {
      ordered.push(node);
    }
  }
  if (selected !== null) {
    ordered.unshift(selected);
  }
  return ordered;
}

export function defaultRuleList(): string[] {
  return [
    'DOMAIN-SUFFIX,local,DIRECT',
    'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve',
    'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
    'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
    'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
    'GEOIP,CN,DIRECT',
    'MATCH,PROXY'
  ];
}

export function buildRuntimeConfig(rawConfig: string, mode: string, selectedNode: string, port: number,
  allowLan: boolean, ipv6: boolean): string {
  const decoded = decodeSubscription(rawConfig);
  const overrides: string[] = [
    'mixed-port: ' + port.toString(),
    'allow-lan: ' + (allowLan ? 'true' : 'false'),
    'mode: rule',
    'log-level: info',
    'ipv6: ' + (ipv6 ? 'true' : 'false')
  ];
  const proxiesBlock = extractSection(decoded, 'proxies');
  const nodes = extractNodes(decoded);

  if (proxiesBlock === '' || nodes.length === 0) {
    const stripped = stripTopLevelKeys(decoded, TOP_LEVEL_OVERRIDE_KEYS);
    return overrides.join('\n') + '\n' + stripped;
  }

  const lines: string[] = [];
  for (const line of overrides) {
    lines.push(line);
  }
  lines.push('');
  lines.push(proxiesBlock);
  lines.push('');
  lines.push('proxy-groups:');
  lines.push('  - name: PROXY');
  lines.push('    type: select');
  lines.push('    proxies:');
  const ordered = orderNodes(nodes, selectedNode);
  for (const node of ordered) {
    lines.push('      - ' + yamlQuote(node.name));
  }
  lines.push('');
  lines.push('rules:');
  if (mode === 'direct') {
    lines.push('  - MATCH,DIRECT');
  } else if (mode === 'global') {
    lines.push('  - MATCH,PROXY');
  } else {
    const rules = defaultRuleList();
    for (const rule of rules) {
      lines.push('  - ' + rule);
    }
  }
  return lines.join('\n');
}
