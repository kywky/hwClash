package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/hub/executor"
)

// The ArkTS ConfigBuilder generates this shape of YAML before handing it to
// the core; keep the two in sync by parsing the same structure here.
const generatedConfig = `mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: true
external-controller: 127.0.0.1:9090
secret: "b0c1f2a3-1111-2222-3333-444455556666"

dns:
  enable: true
  ipv6: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "localhost.ptlogin2.qq.com"
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - 223.5.5.5
    - 119.29.29.29

proxies:
  - name: "test-node"
    type: ss
    server: 192.0.2.10
    port: 8388
    cipher: aes-128-gcm
    password: "pw"

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - "test-node"

rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - MATCH,PROXY
`

func TestParseGeneratedConfig(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "runtime.yaml")
	if err := os.WriteFile(path, []byte(generatedConfig), 0o600); err != nil {
		t.Fatal(err)
	}
	cfg, err := executor.ParseWithPath(path)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if cfg.General.MixedPort != 7890 {
		t.Fatalf("mixed-port = %d", cfg.General.MixedPort)
	}
	if cfg.Controller.ExternalController != "127.0.0.1:9090" {
		t.Fatalf("external-controller = %q", cfg.Controller.ExternalController)
	}
	if _, ok := cfg.Proxies["PROXY"]; !ok {
		t.Fatalf("PROXY group missing")
	}
	if _, ok := cfg.Proxies["test-node"]; !ok {
		t.Fatalf("test-node proxy missing")
	}
	if !cfg.DNS.Enable {
		t.Fatalf("dns not enabled")
	}
}
