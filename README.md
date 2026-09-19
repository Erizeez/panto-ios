# Panto for iOS (panto-ios)

<div align="center">

**现代、优雅、高性能的 iOS 多协议可编程隧道编排客户端 (v0.1.0-alpha)**

[架构文档](https://github.com/Erizeez/panto) | [开源协议声明](LICENSE) | [主引擎仓库](https://github.com/Erizeez/panto)

</div>

---

## 🌟 架构概览与法律防火墙

本项目是 Panto 在 iOS / iPadOS 平台上的官方原生客户端工程，设计遵循**双进程物理隔离与 IPC 防火墙架构**：

```
┌────────────────────────────────────────────────────────────────────────┐
│                        panto-ios 客户端工程架构                        │
│                                                                        │
│  【Process 1: PantoApp (主应用 - SwiftUI)】                            │
│    • 状态看板、点阵吞吐频谱、策略组手动选择器、DAG 链路拓扑可视化     │
│    • 全球站点连通性测试 (Probe Sites)、Magic IP 冲突仲裁裁决面板       │
│    • 出站安全观测遥测授权 (Observation Consents) 确认流                │
│    • 版权属性: 独立专有商业所有权 (或 MIT 宽松开源)                   │
│                                                                        │
│                      ▲                          │                      │
│      sendProviderMessage (IPC)           onStatusChanged / Event       │
│                      │                          ▼                      │
│                                                                        │
│  【Process 2: PantoTunnel (网络扩展 - NetworkExtension)】              │
│    • 系统级 PacketTunnelProvider 隧道接管与 utun 虚拟网卡驱动          │
│    • 嵌入 PantoKit.xcframework 原生静态库 (Rust 高性能零 GC 引擎)       │
│    • 15MB 内存硬红线主动防御看门狗 (MemoryWatchdog，实测常驻仅 2~3MB)   │
│    • 版权属性: GPL-3.0 with Apple App Store Exception                  │
└────────────────────────────────────────────────────────────────────────┘
```

### 为什么这样做可以安全收费且不违背开源精神？
1. **进程级 IPC 隔离**：主 App 与 Network Extension 是两个完全独立的系统进程，仅通过系统提供的 `sendProviderMessage` 内存消息管道交换 JSON 指令。根据 FSF（自由软件基金会）准则，进程级 IPC 不会构成 GPL 传染，主 App 可以合法闭源或采用专有许可证商业销售。
2. **App Store Exception 例外条款**：在 [LICENSE](LICENSE) 中明确追加了国际通用的 App Store 例外声明，彻底消除了苹果 EULA 与 GPL 条款之间的历史法律冲突。

---

## 📱 模拟器 vs 真机运行边界

| 维度 | iOS 模拟器 (Simulator) | iPhone 真实设备 (Device) |
| :--- | :--- | :--- |
| **主 App (SwiftUI)** | ✅ 完整支持，所有界面、图表、测速完全可用 | ✅ 完整支持 |
| **开发者证书签名** | 🟢 **免签名**（无需配置 Apple Team / 证书） | 🔑 **必需** 具备 Personal Team 或付费开发者账号 |
| **数据与交互体验** | ⚡ 内置高保真 Mock 数据与平滑波形模拟，极速调试 | 🚀 联动后台 Network Extension 真实 IPC 通信 |
| **系统级 VPN 隧道接管** | ⚠️ 不支持（苹果模拟器内核无 `utun` 路由驱动限制） | ✅ **完整接管**（点亮系统状态栏 `VPN` 图标） |
| **适用场景** | 界面迭代、动画打磨、功能逻辑验证、脱机单测 | 全链路流量代理、真实网络打流、15MB 内存压力实测 |

---

## 📁 目录结构

```
panto-ios/
├── LICENSE                     # 双重许可与 App Store 例外条款声明
├── README.md                   # 本文件
├── project.yml                 # XcodeGen 工程配置文件 (生成 Panto.xcodeproj)
├── Package.swift               # Swift Package Manager (用于单元测试与 PantoShared)
├── Frameworks/
│   └── PantoKit.xcframework    # Rust 编译输出的 Apple XCFramework (支持真机与模拟器)
├── Shared/                     # 双 Target 共享代码与模型
│   ├── Models.swift            # 对齐 OpenAPI 3.0.3 规范的数据模型
│   ├── PantoClientProtocol.swift # 客户端标准服务协议
│   ├── MockPantoClient.swift   # 高保真内存 Mock 客户端 (用于脱机/预览)
│   ├── IPCPantoClient.swift    # 基于系统 IPC 的真实通信客户端
│   ├── IPCMessage.swift        # 强类型 IPC 请求与响应协议
│   └── AppGroupConstants.swift # App Group 与 Keychain 标识符
├── PantoTunnel/                # 【Target 1: 系统网络扩展 (Extension)】
│   ├── PacketTunnelProvider.swift # 隧道生命周期管理与 IPC 路由转发
│   └── MemoryWatchdog.swift    # 15MB 内存物理防御看门狗
└── PantoApp/                   # 【Target 2: 主应用 (SwiftUI)】
    ├── App.swift               # 应用主入口
    ├── Store/                  # StoreKit 2 Pro 状态管理
    ├── Tunnel/                 # VPNManager 系统隧道连接管理器
    ├── ViewModels/             # AppState 全局状态管理机
    └── Views/                  # 现代化 SwiftUI 仪表盘视图集
```

---

## 🛠️ 构建与运行指南

### 1. 命令行运行单元测试
无需启动 Xcode，在终端一秒完成模型校验与逻辑测试：
```bash
swift test
```

### 2. 生成并构建 Xcode 工程
本项目采用 `xcodegen` 管理工程配置，执行：
```bash
# 1. 重新生成 Xcode 工程
xcodegen generate

# 2. 编译 iOS 模拟器 Debug 版本 (免签名)
xcodebuild build -project Panto.xcodeproj -scheme PantoApp -destination "generic/platform=iOS Simulator" -configuration Debug ARCHS=arm64 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. 编译 iOS 真机 Release 版本
xcodebuild build -project Panto.xcodeproj -scheme PantoApp -destination "generic/platform=iOS" -configuration Release CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### 3. 在 Xcode 中运行
1. 双击打开 `Panto.xcodeproj`；
2. 选择 Scheme 为 `PantoApp`；
3. 选择任一 **iOS 模拟器**（如 iPhone 16 / iPhone 15 Pro），点击 **Run (⌘R)**，即可免签秒级启动并体验所有功能；
4. 若连接 **真机 iPhone**，请在 Target 的 `Signing & Capabilities` 中选定你的 Apple 开发者 Team，点击 **Run** 即可安装到手机并安装系统 VPN Profile。

