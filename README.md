# hwClash

HarmonyOS NEXT 上的 Clash 客户端（开发中）。

> 当前版本是可运行的 UI 与 VPN 框架，**Mihomo 代理核心尚未集成**。VPN 虚拟网卡可以建立，但暂时不转发/代理流量。

## 功能状态

| 功能 | 状态 |
|------|------|
| 主界面 / 连接开关 | 已实现 |
| 订阅添加、下载、Base64 解码、节点解析 | 已实现 |
| 节点列表与选择 | 已实现 |
| 规则 / 全局 / 直连模式 | 已实现（本地生成规则） |
| 设置（端口、局域网、IPv6）持久化 | 已实现 |
| VpnExtensionAbility + TUN 创建 | 已实现，待真机验证 |
| Mihomo 核心（实际代理） | 未集成 |
| 流量统计 / 延迟测速 | 未实现 |

## 目录结构

```
hwClash/
├── .github/workflows/build.yml          # GitHub Actions 云端编译
├── AppScope/                            # 应用级配置与图标
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
- `hvigorw assembleHap` 产出未签名 HAP

编译环境：Ubuntu runner（7GB 内存），无需 macOS。

### 签名与安装

CI 产出的是**未签名** HAP，不能直接安装到真机。两种方式签名：

1. **DevEco Studio（推荐）**：用 DevEco Studio 6.0.0 打开项目，`File > Project Structure > Signing Configs` 勾选自动签名（需登录华为开发者账号），再运行到真机。
2. **命令行**：准备 `.p12` / `.cer` / `.p7b`，使用 DevEco 工具链中的 `hap-sign-tool` 对 HAP 签名。证书文件不要提交进仓库。

如果要在 CI 里自动签名，可以把证书内容存为 GitHub Secrets，在构建后新增签名步骤（注意 `.gitignore` 已排除证书文件）。

## 本地开发

- DevEco Studio 6.0.0 Release（6.0.0.858）或更高
- SDK：HarmonyOS 6.0.0（API 20）
- 真机：HarmonyOS NEXT 设备（VPN 功能需要真机验证）

打开工程后直接运行 `entry` 模块即可。首次点击「连接」时系统会弹出 VPN 授权对话框。

## 已知限制

- 首次授权弹窗可能丢失 `Want.parameters`（系统行为）。因此运行配置通过 Preferences 传给 VPN 扩展，而不是 `Want`。
- 订阅解析目前只提取 `proxies` 段和节点名/类型；`proxy-providers`、订阅自带规则、策略组暂不生效。
- 未集成核心时，VPN 建立后没有数据通路。
- 流量统计为占位显示。

## 后续路线

1. **集成 Mihomo 核心**
   - 用 HarmonyOS NDK 交叉编译 Mihomo 为 `arm64-v8a` 的 `libmihomo.so`
   - 通过 NAPI 暴露 start / stop / traffic / select 接口
   - 在 VPN 扩展中把 TUN fd 交给核心，出站 socket 调用 `VpnConnection.protect()`
2. 完整配置生成：保留订阅的 `proxy-groups` / `rules` / `rule-providers`
3. 流量统计、节点延迟测速
4. 自动连接、通知栏状态、开机自启
5. CI 自动签名与 Release 发布

## 参考

- [HarmonyOS VpnExtensionAbility](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-vpnextensionability)
- [HarmonyOS VPN 连接指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/net-vpnextension)
- [ErBWs/setup-ohos](https://github.com/ErBWs/setup-ohos)
- [Mihomo](https://github.com/MetaCubeX/mihomo)

## 许可

计划采用 GPL-3.0（与 Mihomo 保持一致）。本项目仅用于学习与合法的网络代理场景，请遵守当地法律法规。
