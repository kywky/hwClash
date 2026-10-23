package main

import (
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/log"
)

var (
	fdWait    sync.Map // int64 -> chan struct{}
	fdCounter int64
)

func installSocketHook() {
	dialer.DefaultSocketHook = func(network, address string, conn syscall.RawConn) error {
		return conn.Control(func(fd uintptr) {
			id := atomic.AddInt64(&fdCounter, 1)
			ch := make(chan struct{}, 1)
			fdWait.Store(id, ch)

			if cb := protectCallback; cb != nil {
				cb(id, int64(fd))
			}

			select {
			case <-ch:
			case <-time.After(5 * time.Second):
				log.Warnln("[protect] timeout waiting for VPN protect, fd=%d id=%d", fd, id)
			}
			fdWait.Delete(id)
		})
	}
}

func removeSocketHook() {
	dialer.DefaultSocketHook = nil
}

func NotifyProtected(id int64) {
	if value, ok := fdWait.Load(id); ok {
		select {
		case value.(chan struct{}) <- struct{}{}:
		default:
		}
	}
}

func notifyAllProtected() {
	fdWait.Range(func(key, value any) bool {
		select {
		case value.(chan struct{}) <- struct{}{}:
		default:
		}
		fdWait.Delete(key)
		return true
	})
}
