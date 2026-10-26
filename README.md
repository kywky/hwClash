# hwClash

HarmonyOS NEXT 上的 Clash 客户端（开发中）。

> 当前版本已接入 Mihomo 核心：VPN 扩展把 TUN fd 交给内置的 Go 核心（libhwclash.so），流量经 Mihomo 分流转发；UI 通过 Mihomo 外部控制器（127.0.0.1:9090）实现实时速率、在线切节点、切模式与延迟测速。待真机验证。

## 功能状态

| 功能 | 状态 |
|------|------|
| 主界面 / 连接开关 | 已实现 |
| 订阅添加、下载、Base64 解码、节点解析 | 已实现 |
| Mihomo 核心集成（TUN + socket protect） | 已实现（本机 Linux 全链路测试通过），待真机验证 |
| VPN 扩展调用核心 | 已实现 |
| 实时上传 / 下载速率 | 已实现（控制器 /traffic WebSocket） |
| 在线切换节点、切换模式 | 已实现（连接中立即生效） |
| 节点延迟测速 | 已实现（控制器 delay 接口） |
| 规则 / 全局 / 直连模式 | 已实现（本地生成规则，暂无 GEOIP 分流） |
| 设置（端口、局域网、IPv6）持久化 | 已实现 |

## 目录结构

```
hwClash/
├── .github/workflows/build.yml          # GitHub Actions 云端编译
├── AppScope/                            # 应用级配置与图标
├── core/                                # Go 代理核心，编译为 libhwclash.so
│   ├── core.go                          # Mihomo 启停 / TUN / 状态
│   ├── protect.go                       # socket protect 等待队列
│   ├── napi.go                          # ArkTS NAPI 导出
│   ├── build.sh                         # OHOS NDK 交叉编译
│   ├── config_test.go / host_tun_test.go / mixed_only_test.go  # 核心测试
│   └── third_party/                     # mihomo / gvisor 的 OHOS fork
├── entry/
│   ├── build-profile.json5
│   ├── obfuscation-rules.txt
│   └── src/main/
│       ├── module.json5                 # UIAbility + VPN 扩展声明
│       ├── ets/
│       │   ├── entry/HwClashAbility.ets
│       │   ├── service/HwClashVpnExtension.ets
│       │   ├── model/Types.ets
│       │   ├── utils/PreferencesUtil.ets
│       │   ├── utils/ConfigBuilder.ets  # Clash YAML 生成
│       │   ├── common/Constants.ets
│       │   └── pages/                   # Index / 订阅 / 节点 / 规则 / 设置
│       └── resources/
├── hvigor/hvigor-config.json5
├── build-profile.json5
├── oh-package.json5
└── hvigorfile.ts
```

## 云端编译（不用装 DevEco Studio）

1. 在 GitHub 新建仓库，把本项目推上去。
2. 打开仓库的 **Actions** 页面，选择 `Build HAP`，push 或手动 `Run workflow`。
3. 编译完成后在 run 的 **Artifacts** 中下载 `hwclash-hap`。

Workflow 使用：

- `ErBWs/setup-ohos@v2` 安装 HarmonyOS 命令行工具 `6.0.0.858`（API 20）
- `actions/setup-go` 安装 bootstrap Go 1.22.12
- 从 [gitee.com/wefuture/golang_go](https://gitee.com/wefuture/golang_go)（`feature/tlsgd_mode_support` 分支）编译带 `-tlsmodegd` 的 OHOS Go 工具链（已缓存）
- 先跑 `go test` 做宿主机核心测试（含真实 TUN 全链路测试，非 root 自动跳过）
- `core/build.sh` 用 OHOS NDK 交叉编译出 `entry/libs/arm64-v8a/libhwclash.so`
- `hvigorw assembleHap` 产出未签名 HAP

编译环境：Ubuntu runner（7GB 内存），无需 macOS。

### 签名与安装

CI 默认产出**未签名** HAP。配置一个仓库 Secret 后，CI 会自动输出**已签名** HAP（`hwclash-hap-signed` 产物）：

- Secret 名：`HWCLASH_SIGNING_BUNDLE`
- 值：`tar.gz`（含 `hwclash.p12` / `tools.cer` / `toolsRelease.p7b` / `keystore.password`）的 base64
- 签名工具：[OpenHarmony developtools_hapsigner](https://github.com/openharmony/developtools_hapsigner)（构建时自动拉取）

本地签名（代替 DevEco）：

```sh
java -jar hap-sign-tool.jar sign-app \
  -keyAlias hwclash-debug -signAlg SHA256withECDSA -mode localSign \
  -appCertFile tools.cer -profileFile toolsRelease.p7b \
  -keystoreFile hwclash.p12 -keystorePwd "$(cat keystore.password)" \
  -inFile entry-default-unsigned.hap -outFile hwclash-signed.hap
```

证书申请：`hap-sign-tool.jar generate-keypair` + `generate-csr` 生成密钥与 CSR → AGC 签发证书与 Profile。证书文件不要提交进仓库。

## 本地开发

- DevEco Studio 6.0.0 Release（6.0.0.858）或更高
- SDK：HarmonyOS 6.0.0（API 20）
- 真机：HarmonyOS NEXT 设备（VPN 功能需要真机验证）

打开工程后直接运行 `entry` 模块即可。首次点击「连接」时系统会弹出 VPN 授权对话框。

### 构建 Go 核心

`libhwclash.so` 不提交仓库，构建 HAP 前需要先生成：

1. 准备带 `-tlsmodegd` 的 OHOS Go 工具链：[gitee.com/wefuture/golang_go](https://gitee.com/wefuture/golang_go) 的 `feature/tlsgd_mode_support` 分支，用 Go 1.22+ 作为 bootstrap 执行 `src/make.bash`
2. 设置 `OHOS_NATIVE_HOME` 指向 HarmonyOS SDK 的 `native` 目录
3. 运行：

```sh
GO_OHOS=/path/to/go-ohos/bin/go \
OHOS_NATIVE_HOME=/path/to/openharmony/native \
./core/build.sh
```

产物会复制到 `entry/libs/arm64-v8a/libhwclash.so`，再由 hvigor 打包进 HAP。

## 已知限制

- 首次授权弹窗可能丢失 `Want.parameters`（系统行为）。因此运行配置通过 Preferences 传给 VPN 扩展，而不是 `Want`。
- 订阅解析目前只提取 `proxies` 段和节点名/类型；`proxy-providers`、订阅自带规则、策略组暂不生效。
- 规则由本地生成（私有网段直连 + 其余走代理），暂无 GEOIP/GEOSITE 分流（需随包分发 GeoIP 数据）。
- 延迟测速与速率依赖核心的外部控制器（仅监听 127.0.0.1，带随机 secret）。
- 所有功能均未在真机上验证。

## 后续路线

1. 真机验证：VPN 授权、TUN 转发、socket protect、速率显示
2. 完整配置生成：保留订阅的 `proxy-groups` / `rules` / `rule-providers`，内置 GeoIP 数据实现国内直连
3. 连接列表、日志页面（控制器 `/connections`、`/logs`）
4. 自动连接、通知栏状态、开机自启
5. CI 自动签名与 Release 发布

## 参考

- [HarmonyOS VpnExtensionAbility](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-vpnextensionability)
- [HarmonyOS VPN 连接指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/net-vpnextension)
- [ErBWs/setup-ohos](https://github.com/ErBWs/setup-ohos)
- [Mihomo](https://github.com/MetaCubeX/mihomo)

## 许可

计划采用 GPL-3.0（与 Mihomo 保持一致）。本项目仅用于学习与合法的网络代理场景，请遵守当地法律法规。
