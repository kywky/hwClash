//go:build !ohos

package main

// Host-side stub so `go build`/`go vet` type-check the core on a normal
// Linux toolchain. The real entry point lives in napi.go (build tag
// `cgo && ohos`, compiled by core/build.sh with -tags ohos).
func main() {}
