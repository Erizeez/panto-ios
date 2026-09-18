# Panto for iOS (panto-ios)

<div align="center">

**现代、优雅、高性能的 iOS 多协议可编程隧道编排客户端**

[架构文档](../docs/architecture.md) | [开源协议声明](LICENSE) | [主引擎仓库](https://github.com/Erizeez/panto)

</div>

---

## 🌟 架构概览与法律防火墙

本项目是 Panto 在 iOS / iPadOS 平台上的官方原生客户端工程，设计遵循**双进程物理隔离与 IPC 防火墙架构**：

```
┌────────────────────────────────────────────────────────────────────────┐
│                        panto-ios 客户端工程架构                        │
│                                                                        │
│  【Process 1: PantoApp (主应用 - SwiftUI)】                            │
│    • 状态看板、动态折线图、策略组手动选择器                            │
│    • StoreKit 2 终身买断 Pro 状态管理 (org.panto.ios.lifetime_pro)     │
│    • 敏感配置加密与 iCloud Drive 多设备协同                            │
│    • 版权属性: 独立专有商业所有权 (或 MIT 宽松开源)                   │
│                                                                        │
│                      ▲                          │                      │
│      sendProviderMessage (IPC)           onStatusChanged / Event       │
│                      │                          ▼                      │
│                                                                        │
│  【Process 2: PantoTunnel (网络扩展 - NetworkExtension)】              │
│    • 系统级 PacketTunnelProvider 隧道接管                              │
│    • 嵌入 PantoKit.xcframework 静态库 (Go 核心引擎)                    │
│    • 15MB 内存限制主动防御看门狗 (MemoryWatchdog)                      │
│    • 版权属性: GPL-3.0 with Apple App Store Exception                  │
└────────────────────────────────────────────────────────────────────────┘
```

### 为什么这样做可以安全收费且不违背开源精神？
1. **进程级 IPC 隔离**：主 App 与 Network Extension 是两个完全独立的系统进程，仅通过系统提供的 `sendProviderMessage` 内存消息管道交换 JSON 指令。根据 FSF（自由软件基金会）准则，进程级 IPC 不会构成 GPL 传染，主 App 可以合法闭源或采用专有许可证商业销售。
2. **App Store Exception 例外条款**：在 [LICENSE](LICENSE) 中明确追加了国际通用的 App Store 例外声明，彻底消除了苹果 EULA 与 GPL 条款之间的历史法律冲突。

---

## 📁 目录结构

```
ios/
├── LICENSE                     # 双重许可与 App Store 例外条款声明
├── README.md                   # 本文件
├── Package.swift               # Swift Package Manager 依赖清单
├── Shared/                     # 双 Target 共享代码
│   ├── IPCMessage.swift        # 强类型 IPC 请求与响应协议
│   └── AppGroupConstants.swift # App Group 与 Keychain 标识符
├── PantoTunnel/                # 【Target 1: 系统网络扩展 (Extension)】
│   ├── PacketTunnelProvider.swift # 隧道生命周期管理与 IPC 路由
│   └── MemoryWatchdog.swift    # 15MB 内存看门狗与 GC 触发器
└── PantoApp/                   # 【Target 2: 主应用 (SwiftUI)】
    ├── App.swift               # 应用入口
    ├── Store/                  # StoreKit 2 一次性买断 Pro 状态模型
    ├── Tunnel/                 # VPNManager 系统隧道连接管理器
    └── Views/                  # 现代化 SwiftUI 仪表盘视图
```

---

## 🛠️ 构建与调试指南

### 1. 编译底座 PantoKit.xcframework
在项目根目录下执行脚本，通过 `gomobile bind` 生成专为 iOS 裁剪的静态框架：
```bash
./scripts/build-xcframework.sh
```
该脚本会自动将编译产物注入到 `ios/PantoKit/PantoKit.xcframework`。

### 2. 在 Xcode 中打开并运行
1. 使用 Xcode 打开 `ios/` 目录或直接将该目录作为 Swift Package 载入；
2. 为 `PantoApp` 与 `PantoTunnel` 分别配置有效的 Apple Developer 签名证书；
3. 勾选 App Sandbox 与 `Network Extensions` (`Packet Tunnel`) Capabilities；
4. 选择 iOS 真机或模拟器，一键编译运行！
