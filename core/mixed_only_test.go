//go:build linux

package main

import (
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/tunnel"
)

func TestMixedOnly(t *testing.T) {
	home := t.TempDir()
	if err := Init(home); err != nil {
		t.Fatal(err)
	}
	configPath := filepath.Join(home, "config.yaml")
	config := `mixed-port: 17891
allow-lan: false
mode: rule
log-level: info
ipv6: false

dns:
  enable: true
  ipv6: false
  listen: 127.0.0.1:11054
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5

proxies:
  - name: "direct-test"
    type: direct

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - "direct-test"

rules:
  - MATCH,PROXY
`
	if err := os.WriteFile(configPath, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	cfg, err := executor.ParseWithPath(configPath)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	hub.ApplyConfig(cfg)
	listener.ReCreateMixed(17891, tunnel.Tunnel)

	wait := 0
	if v := os.Getenv("ITEST_WAIT"); v != "" {
		wait, _ = strconv.Atoi(v)
		time.Sleep(time.Duration(wait) * time.Second)
	}

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Get("http://www.msftconnecttest.com/connecttest.txt")
	if err != nil {
		t.Fatalf("direct request: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != 200 {
		t.Fatalf("status %d", resp.StatusCode)
	}
}
