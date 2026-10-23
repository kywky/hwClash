import { http } from '@kit.NetworkKit';
import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DEFAULT_CONTROLLER_PORT } from '../common/Constants';

export interface CoreVersionInfo {
  version: string;
  premium: boolean;
  meta: boolean;
}

export interface TrafficSample {
  up: number;
  down: number;
}

export interface DelayResult {
  ok: boolean;
  delay: number;
}

function baseUrl(): string {
  return 'http://127.0.0.1:' + DEFAULT_CONTROLLER_PORT.toString();
}

function authHeader(secret: string): Record<string, string> {
  const headers: Record<string, string> = {
    'Authorization': 'Bearer ' + secret
  };
  return headers;
}

export class ClashApi {
  static async ping(secret: string): Promise<boolean> {
    try {
      const body = await ClashApi.request(secret, '/version', http.RequestMethod.GET, '');
      return body.length > 0;
    } catch (error) {
      return false;
    }
  }

  static async version(secret: string): Promise<string> {
    const body = await ClashApi.request(secret, '/version', http.RequestMethod.GET, '');
    const info = JSON.parse(body) as CoreVersionInfo;
    return info.version;
  }

  static async setMode(secret: string, mode: string): Promise<void> {
    await ClashApi.request(secret, '/configs', http.RequestMethod.PATCH,
      JSON.stringify({ mode: mode }));
  }

  static async selectProxy(secret: string, group: string, name: string): Promise<void> {
    const path = '/proxies/' + encodeURIComponent(group);
    await ClashApi.request(secret, path, http.RequestMethod.PUT,
      JSON.stringify({ name: name }));
  }

  static async delay(secret: string, name: string): Promise<DelayResult> {
    const path = '/proxies/' + encodeURIComponent(name) + '/delay?timeout=5000' +
      '&url=' + encodeURIComponent('http://www.gstatic.com/generate_204');
    try {
      const body = await ClashApi.request(secret, path, http.RequestMethod.GET, '');
      const parsed = JSON.parse(body) as Record<string, number>;
      const value = parsed['delay'];
      return { ok: true, delay: value === undefined ? 0 : value };
    } catch (error) {
      return { ok: false, delay: 0 };
    }
  }

  static async request(secret: string, path: string, method: http.RequestMethod, body: string): Promise<string> {
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: authHeader(secret),
        connectTimeout: 5000,
        readTimeout: 8000
      };
      if (body !== '') {
        options.extraData = body;
      }
      const response = await client.request(baseUrl() + path, options);
      if (response.responseCode >= 400) {
        throw new Error('controller HTTP ' + response.responseCode.toString());
      }
      return response.result as string;
    } finally {
      client.destroy();
    }
  }
}

export class TrafficMonitor {
  private ws: webSocket.WebSocket | undefined = undefined;
  private onUpdate: (up: number, down: number) => void;
  private secret: string = '';
  private stopped: boolean = true;
  private attempts: number = 0;
  private timerId: number = -1;

  constructor(onUpdate: (up: number, down: number) => void) {
    this.onUpdate = onUpdate;
  }

  connect(secret: string): void {
    this.close();
    this.secret = secret;
    this.stopped = false;
    this.attempts = 0;
    this.tryConnect();
  }

  private tryConnect(): void {
    if (this.stopped || this.ws !== undefined) {
      return;
    }
    this.attempts++;
    const ws = webSocket.createWebSocket();
    ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        return;
      }
      if (typeof value === 'string') {
        try {
          const sample = JSON.parse(value) as TrafficSample;
          this.onUpdate(sample.up, sample.down);
        } catch (parseError) {
        }
      }
    });
    ws.on('close', () => {
      if (this.ws === ws) {
        this.ws = undefined;
      }
      this.scheduleReconnect();
    });
    ws.on('error', () => {
    });
    const url = 'ws://127.0.0.1:' + DEFAULT_CONTROLLER_PORT.toString() + '/traffic';
    const requestOptions: webSocket.WebSocketRequestOptions = {
      header: authHeader(this.secret)
    };
    ws.connect(url, requestOptions).then((ok: boolean) => {
      if (!ok) {
        this.scheduleReconnect();
      } else if (this.ws === undefined) {
        this.ws = ws;
      }
    }).catch(() => {
      this.scheduleReconnect();
    });
  }

  private scheduleReconnect(): void {
    if (this.stopped || this.attempts >= 10 || this.timerId >= 0) {
      return;
    }
    this.timerId = setTimeout(() => {
      this.timerId = -1;
      this.tryConnect();
    }, 2000);
  }

  close(): void {
    this.stopped = true;
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    if (this.ws !== undefined) {
      try {
        this.ws.off('message');
        this.ws.close();
      } catch (error) {
      }
      this.ws = undefined;
    }
  }
}

export function formatBytes(bytes: number): string {
  if (bytes < 0) {
    bytes = 0;
  }
  const units: string[] = ['B', 'KB', 'MB', 'GB', 'TB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value = value / 1024;
    unit++;
  }
  const text = unit === 0 ? value.toFixed(0) : value.toFixed(1);
  return text + ' ' + units[unit];
}
