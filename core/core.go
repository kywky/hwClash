package main

import (
	"encoding/json"
	"fmt"
	"net/netip"
	"sync"
	"time"

	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/listener"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

// StartOptions is passed from ArkTS as JSON. The TUN addresses must match
// the addresses configured on the VpnConnection in the VPN extension.
type StartOptions struct {
	ConfigPath     string   `json:"configPath"`
	ControllerAddr string   `json:"controllerAddr"`
	Secret         string   `json:"secret"`
	MTU            uint32   `json:"mtu"`
	TunIPv4        string   `json:"tunIPv4"`
	TunIPv6        string   `json:"tunIPv6"`
	DNSHijack      []string `json:"dnsHijack"`
}

type Status struct {
	Running   bool   `json:"running"`
	StartedAt int64  `json:"startedAt"`
	Version   string `json:"version"`
	Error     string `json:"error"`
}

var (
	coreMu          sync.Mutex
	coreRunning     bool
	coreStartedAt   time.Time
	coreLastError   string
	tunListener     *sing_tun.Listener
	protectCallback func(id int64, fd int64)
)

func Init(homeDir string) error {
	if homeDir != "" {
		constant.SetHomeDir(homeDir)
	}
	return nil
}

func Start(fd int, opts StartOptions, protect func(id int64, fd int64)) error {
	coreMu.Lock()
	defer coreMu.Unlock()

	if coreRunning {
		return fmt.Errorf("core already running")
	}
	if opts.ConfigPath == "" {
		return fmt.Errorf("config path is empty")
	}
	if opts.TunIPv4 == "" {
		return fmt.Errorf("tun ipv4 address is empty")
	}
	if protect == nil {
		return fmt.Errorf("protect callback is nil")
	}

	protectCallback = protect
	installSocketHook()

	cfg, err := executor.ParseWithPath(opts.ConfigPath)
	if err != nil {
		removeSocketHook()
		coreLastError = err.Error()
		return fmt.Errorf("parse config: %w", err)
	}
	if opts.ControllerAddr != "" {
		cfg.Controller.ExternalController = opts.ControllerAddr
	}
	if opts.Secret != "" {
		cfg.Controller.Secret = opts.Secret
	}

	// This fork comments out updateListeners in executor.ApplyConfig, so the
	// inbound allow/skip-auth lists never receive the config defaults
	// (0.0.0.0/0, ::/0) and every inbound connection would be rejected.
	inbound.SetSkipAuthPrefixes(cfg.General.SkipAuthPrefixes)
	inbound.SetAllowedIPs(cfg.General.LanAllowedIPs)
	inbound.SetDisAllowedIPs(cfg.General.LanDisAllowedIPs)

	hub.ApplyConfig(cfg)

	// executor.ApplyConfig in this Mihomo fork intentionally leaves inbound
	// listeners to the embedder, so start the mixed listener ourselves.
	listener.SetAllowLan(cfg.General.AllowLan)
	listener.SetBindAddress(cfg.General.BindAddress)
	listener.ReCreateMixed(cfg.General.MixedPort, tunnel.Tunnel)

	prefix4, err := netip.ParsePrefix(opts.TunIPv4)
	if err != nil {
		stopLocked()
		return fmt.Errorf("invalid tun ipv4: %w", err)
	}
	var prefixes6 []netip.Prefix
	if opts.TunIPv6 != "" {
		prefix6, err := netip.ParsePrefix(opts.TunIPv6)
		if err != nil {
			stopLocked()
			return fmt.Errorf("invalid tun ipv6: %w", err)
		}
		prefixes6 = append(prefixes6, prefix6)
	}

	mtu := opts.MTU
	if mtu == 0 {
		mtu = 9000
	}
	dnsHijack := opts.DNSHijack
	if len(dnsHijack) == 0 {
		dnsHijack = []string{"172.19.0.2:53"}
	}

	l, err := sing_tun.New(LC.Tun{
		Enable:              true,
		Device:              "hwclash-tun",
		Stack:               constant.TunGvisor,
		DNSHijack:           dnsHijack,
		AutoRoute:           false,
		AutoDetectInterface: false,
		Inet4Address:        []netip.Prefix{prefix4},
		Inet6Address:        prefixes6,
		MTU:                 mtu,
		FileDescriptor:      fd,
	}, tunnel.Tunnel)
	if err != nil {
		stopLocked()
		coreLastError = err.Error()
		return fmt.Errorf("start tun: %w", err)
	}

	tunListener = l
	coreRunning = true
	coreStartedAt = time.Now()
	coreLastError = ""
	log.Infoln("hwClash core started, tun address: %v", l.Address())
	return nil
}

func Stop() {
	coreMu.Lock()
	defer coreMu.Unlock()
	stopLocked()
}

func stopLocked() {
	coreRunning = false
	if tunListener != nil {
		_ = tunListener.Close()
		tunListener = nil
	}
	removeSocketHook()
	listener.StopListener()
	executor.Shutdown()
	route.ReCreateServer(&route.Config{})
	notifyAllProtected()
}

func GetStatus() string {
	coreMu.Lock()
	defer coreMu.Unlock()
	status := Status{
		Running: coreRunning,
		Version: constant.Version,
		Error:   coreLastError,
	}
	if !coreStartedAt.IsZero() {
		status.StartedAt = coreStartedAt.UnixMilli()
	}
	data, _ := json.Marshal(status)
	return string(data)
}
