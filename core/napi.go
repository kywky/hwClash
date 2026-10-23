//go:build cgo && ohos

package main

import (
	"encoding/json"

	napi "github.com/likuai2010/ohos-napi"
	"github.com/likuai2010/ohos-napi/entry"
	"github.com/likuai2010/ohos-napi/js"
)

func init() {
	entry.Export("initCore", js.AsCallback(exportInitCore))
	entry.Export("startCore", js.AsCallback(exportStartCore))
	entry.Export("stopCore", js.AsCallback(exportStopCore))
	entry.Export("getCoreStatus", js.AsCallback(exportGetStatus))
	entry.Export("notifyProtected", js.AsCallback(exportNotifyProtected))
}

func exportInitCore(env js.Env, _ js.Value, args []js.Value) any {
	if len(args) < 1 {
		return "initCore: missing home dir"
	}
	homeDir, _ := napi.GetValueStringUtf8(env.Env, args[0].Value)
	if err := Init(homeDir); err != nil {
		return err.Error()
	}
	return ""
}

// exportStartCore runs Start on a goroutine so the ArkTS thread stays free to
// service the protect callback. Returns a Promise resolving to an error string
// (empty on success); poll getCoreStatus for the running state.
func exportStartCore(env js.Env, _ js.Value, args []js.Value) any {
	if len(args) < 3 {
		return "startCore: expected (fd, optionsJson, protectCallback)"
	}
	fd, _ := napi.GetValueInt32(env.Env, args[0].Value)
	optionsJSON, _ := napi.GetValueStringUtf8(env.Env, args[1].Value)

	var opts StartOptions
	if err := json.Unmarshal([]byte(optionsJSON), &opts); err != nil {
		return "startCore: invalid options json: " + err.Error()
	}

	promise := env.NewPromise()
	tsfn := env.CreateThreadsafeFunction(args[2], "startCore")
	go func() {
		err := Start(int(fd), opts, func(id int64, fd int64) {
			tsfn.Call(env.ValueOf(id), env.ValueOf(fd))
		})
		if err != nil {
			promise.Resolve(err.Error())
			return
		}
		promise.Resolve("")
	}()
	return promise
}

func exportStopCore(_ js.Env, _ js.Value, _ []js.Value) any {
	Stop()
	return nil
}

func exportGetStatus(_ js.Env, _ js.Value, _ []js.Value) any {
	return GetStatus()
}

func exportNotifyProtected(env js.Env, _ js.Value, args []js.Value) any {
	if len(args) < 1 {
		return nil
	}
	id, _ := napi.GetValueInt32(env.Env, args[0].Value)
	NotifyProtected(int64(id))
	return nil
}

func main() {}
