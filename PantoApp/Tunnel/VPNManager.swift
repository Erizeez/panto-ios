import Foundation
import NetworkExtension
import os.log
import PantoShared

/// VPNManager 负责在主 App 侧管理系统级 VPN 描述文件配置、权限申请、状态同步与跨进程 IPC。
@MainActor
public final class VPNManager: ObservableObject {
    nonisolated private static let logger = Logger(subsystem: "org.panto.ios", category: "VPNManager")

    @Published public private(set) var status: NEVPNStatus = .disconnected
    @Published public private(set) var currentUptime: Int = 0
    @Published public private(set) var upRate: Int64 = 0
    @Published public private(set) var downRate: Int64 = 0
    @Published public private(set) var activeEndpointsCount: Int = 0
    @Published public var lastError: String? = nil

    private var providerManager: NETunnelProviderManager?
    private var pollTimer: Timer?

    public init() {
        Task {
            await refreshManager()
        }
    }

    /// 从系统首选项刷新或读取 NETunnelProviderManager。
    public func refreshManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                self.providerManager = existing
                self.status = existing.connection.status
                setupStatusObserver()
            }
        } catch {
            Self.logger.error("❌ 查询系统 VPN 配置失败: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }
    }

    /// 显式获取或创建系统 VPN 描述文件（触发系统授权弹窗）
    public func prepareTunnelManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let manager = managers.first ?? NETunnelProviderManager()
        
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppGroupConstants.extensionBundleID
        proto.serverAddress = "10.201.0.1"
        proto.providerConfiguration = ["AppGroup": AppGroupConstants.appGroupID]
        manager.protocolConfiguration = proto
        manager.localizedDescription = AppGroupConstants.defaultTunnelName
        manager.isEnabled = true

        // 这一步调用 saveToPreferences() 会在首次时触发 iOS 系统 VPN 授权弹窗！
        try await manager.saveToPreferences()
        // 重新从首选项加载以刷新系统级连接对象
        try await manager.loadFromPreferences()

        self.providerManager = manager
        self.status = manager.connection.status
        setupStatusObserver()
        return manager
    }

    /// 开启隧道连接。
    public func startTunnel() async throws {
        self.lastError = nil
        let manager: NETunnelProviderManager
        if let current = providerManager {
            manager = current
        } else {
            manager = try await prepareTunnelManager()
        }

        // 确保描述文件指向最新的 Extension Bundle ID 和正确的网关地址
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        if !manager.isEnabled || proto.providerBundleIdentifier != AppGroupConstants.extensionBundleID || proto.serverAddress != "10.201.0.1" {
            proto.providerBundleIdentifier = AppGroupConstants.extensionBundleID
            proto.serverAddress = "10.201.0.1"
            proto.providerConfiguration = ["AppGroup": AppGroupConstants.appGroupID]
            manager.protocolConfiguration = proto
            manager.localizedDescription = AppGroupConstants.defaultTunnelName
            manager.isEnabled = true
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
        }

        do {
            try manager.connection.startVPNTunnel()
            startPollTimer()
        } catch {
            Self.logger.warning("⚠️ 首次启动隧道异常，尝试重新加载首选项: \(error.localizedDescription)")
            try await manager.loadFromPreferences()
            try manager.connection.startVPNTunnel()
            startPollTimer()
        }
    }

    /// 停止隧道连接。
    public func stopTunnel() {
        providerManager?.connection.stopVPNTunnel()
        stopPollTimer()
    }

    /// 通过 IPC 向后台 Extension 发送强类型请求。
    public func sendMessage(_ request: IPCRequest) async throws -> IPCResponse {
        guard let session = providerManager?.connection as? NETunnelProviderSession else {
            throw NSError(domain: "org.panto.ios", code: -1, userInfo: [NSLocalizedDescriptionKey: "VPN 尚未启动"])
        }

        if session.status != .connected {
            throw NSError(domain: "org.panto.ios", code: -2, userInfo: [NSLocalizedDescriptionKey: "VPN 会话非连接态 (\(session.status.rawValue))"])
        }

        let encoded = try JSONEncoder().encode(request)
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(encoded) { responseData in
                    guard let data = responseData else {
                        continuation.resume(returning: IPCResponse(success: false, error: "无响应数据"))
                        return
                    }
                    if let resp = try? JSONDecoder().decode(IPCResponse.self, from: data) {
                        continuation.resume(returning: resp)
                    } else {
                        continuation.resume(returning: IPCResponse(success: true, data: data))
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func setupStatusObserver() {
        NotificationCenter.default.removeObserver(self, name: .NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: providerManager?.connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.status = self.providerManager?.connection.status ?? .disconnected
                if self.status == .connected {
                    self.startPollTimer()
                } else if self.status == .disconnected {
                    self.stopPollTimer()
                }
            }
        }
    }

    private func startPollTimer() {
        stopPollTimer()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.queryLiveStats()
            }
        }
    }

    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func queryLiveStats() async {
        guard status == .connected else { return }
        // 1. 查询状态
        if let resp = try? await sendMessage(.status()), resp.success, let data = resp.data {
            if let st = try? JSONDecoder().decode(StatusPayload.self, from: data) {
                self.currentUptime = st.uptimeSeconds
                self.activeEndpointsCount = st.activeEndpoints
            }
        }
        // 2. 查询流量
        if let resp = try? await sendMessage(.traffic()), resp.success, let data = resp.data {
            if let tf = try? JSONDecoder().decode(TrafficPayload.self, from: data) {
                self.upRate = tf.upRate
                self.downRate = tf.downRate
            }
        }
    }
}
