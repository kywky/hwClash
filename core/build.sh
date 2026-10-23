#!/usr/bin/env bash
# Cross-compile the Go proxy core into a NAPI shared library for HarmonyOS NEXT.
#
# Requirements:
#   1. Patched OHOS Go toolchain (supports -tlsmodegd):
#        git clone https://gitee.com/wefuture/golang_go
#        # build it once with a bootstrap Go (1.20.x), then use its bin/go
#   2. HarmonyOS native SDK (NDK), e.g.
#        <command-line-tools>/sdk/default/openharmony/native
#
# Usage:
#   GO_OHOS=/path/to/go-ohos/bin/go \
#   OHOS_NATIVE_HOME=/path/to/openharmony/native \
#   ./build.sh
#
# ARCH env vars (default arm64 / arm64-v8a):
#   ARCH=arm64 ABI=arm64-v8a
#   ARCH=x86_64 ABI=x86_64   # emulator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GO_BIN="${GO_OHOS:-go}"
OHOS_NATIVE_HOME="${OHOS_NATIVE_HOME:?set OHOS_NATIVE_HOME to the HarmonyOS native SDK}"

ARCH="${ARCH:-arm64}"
ABI="${ABI:-arm64-v8a}"
case "$ARCH" in
  arm64)  TRIPLE="aarch64-linux-ohos" ;;
  x86_64) TRIPLE="x86_64-linux-ohos" ;;
  *) echo "unsupported ARCH: $ARCH" >&2; exit 1 ;;
esac

TOOLCHAIN="$OHOS_NATIVE_HOME/llvm"
SYSROOT="$OHOS_NATIVE_HOME/sysroot"
OUT="libhwclash.so"

export CGO_ENABLED=1
export GOOS=linux
export GOARCH="$ARCH"
export GOARM=""
export CC="$TOOLCHAIN/bin/clang"
export CXX="$TOOLCHAIN/bin/clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export LD="$TOOLCHAIN/bin/clang"
export CGO_CFLAGS="-Wno-error -D__MUSL__ --target=$TRIPLE --sysroot=$SYSROOT"
export CGO_LDFLAGS="--target=$TRIPLE --sysroot=$SYSROOT"

# -tlsmodegd is specific to the patched toolchain. Without it the .so links
# but crashes on load under OHOS musl TLS.
TLSMODE_FLAG="${TLSMODE_FLAG:--tlsmodegd}"

"$GO_BIN" build $TLSMODE_FLAG \
  -buildmode=c-shared \
  -tags "ohos with_gvisor" \
  -trimpath \
  -ldflags="-s -w" \
  -o "$OUT" .

mkdir -p "$SCRIPT_DIR/../entry/libs/$ABI"
cp -f "$OUT" "$SCRIPT_DIR/../entry/libs/$ABI/$OUT"
rm -f "$OUT" libhwclash.h

echo "built entry/libs/$ABI/$OUT"
