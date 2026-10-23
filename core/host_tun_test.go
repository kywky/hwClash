//go:build linux

package main

import (
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"testing"
	"time"
	"unsafe"
)

// Exercises the full data path on a Linux host: real TUN fd -> sing-tun ->
// mixed inbound -> protected outbound socket. Requires root; skipped
// everywhere else (CI runners are unprivileged).
func TestStartCoreOnHostTun(t *testing.T) {
	if os.Geteuid() != 0 {
		t.Skip("requires root to create a TUN device")
	}
	if _, err := os.Stat("/dev/net/tun"); err != nil {
		t.Skipf("no /dev/net/tun: %v", err)
	}
	if err := exec.Command("ip", "tuntap", "add", "dev", "hwclash-itest", "mode", "tun").Run(); err != nil {
		t.Skipf("cannot create TUN device: %v", err)
	}
	defer exec.Command("ip", "tuntap", "del", "dev", "hwclash-itest", "mode", "tun").Run()

	tunFd, err := openTun("hwclash-itest")
	if err != nil {
		t.Fatalf("open tun: %v", err)
	}
	defer syscall.Close(tunFd)

	home := t.TempDir()
	if err := Init(home); err != nil {
		t.Fatalf("init: %v", err)
	}

	configPath := filepath.Join(home, "runtime.yaml")
	config := `mixed-port: 17890
allow-lan: false
mode: rule
log-level: info
ipv6: false
external-controller: 127.0.0.1:19090
secret: "itest-secret"

dns:
  enable: true
  ipv6: false
  listen: 127.0.0.1:11053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver:
    - 223.5.5.5
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

	opts := StartOptions{
		ConfigPath:     configPath,
		ControllerAddr: "127.0.0.1:19090",
		Secret:         "itest-secret",
		MTU:            1500,
		TunIPv4:        "10.99.0.1/30",
		DNSHijack:      []string{},
	}
	protect := func(id int64, fd int64) {
		NotifyProtected(id)
	}
	if err := Start(tunFd, opts, protect); err != nil {
		t.Fatalf("start: %v", err)
	}
	defer Stop()

	time.Sleep(200 * time.Millisecond)
	status := GetStatus()
	t.Logf("status: %s", status)
	if want := `"running":true`; !contains(status, want) {
		t.Fatalf("core not running: %s", status)
	}

	client := &http.Client{
		Timeout: 15 * time.Second,
		Transport: &http.Transport{
			Proxy: http.ProxyURL(mustURL(t, "http://127.0.0.1:17890")),
		},
	}
	resp, err := client.Get("https://example.com/")
	if err != nil {
		t.Fatalf("request through mixed port: %v", err)
	}
	defer resp.Body.Close()
	t.Logf("example.com status: %d", resp.StatusCode)
	if resp.StatusCode != 200 {
		t.Fatalf("unexpected status %d", resp.StatusCode)
	}

	controller := &http.Client{Timeout: 5 * time.Second}
	req, _ := http.NewRequest("GET", "http://127.0.0.1:19090/version", nil)
	req.Header.Set("Authorization", "Bearer itest-secret")
	resp2, err := controller.Do(req)
	if err != nil {
		t.Fatalf("controller request: %v", err)
	}
	resp2.Body.Close()
	if resp2.StatusCode != 200 {
		t.Fatalf("controller status %d", resp2.StatusCode)
	}
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || indexOf(s, sub) >= 0)
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

func mustURL(t *testing.T, raw string) *url.URL {
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse url: %v", err)
	}
	return u
}

const (
	ifreqSize = 40
	tunsetIFF = 0x400454ca
	iffTun    = 0x0001
	iffNoPI   = 0x1000
)

func openTun(name string) (int, error) {
	dev, err := os.OpenFile("/dev/net/tun", os.O_RDWR, 0)
	if err != nil {
		return -1, err
	}
	var ifreq [ifreqSize]byte
	copy(ifreq[0:16], name)
	flags := iffTun | iffNoPI
	ifreq[16] = byte(flags)
	ifreq[17] = byte(flags >> 8)
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, dev.Fd(), tunsetIFF,
		uintptr(unsafe.Pointer(&ifreq[0])))
	if errno != 0 {
		dev.Close()
		return -1, fmt.Errorf("TUNSETIFF: %v", errno)
	}
	return int(dev.Fd()), nil
}
