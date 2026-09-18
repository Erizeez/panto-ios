import Foundation
import NetworkExtension
import os.log

/// VPNManager 负责在主 App 侧管理系统级 VPN 描述文件配置、状态同步与跨进程 IPC。
@MainActor
public final class VPNManager: ObservableObject {
    private static let logger = Logger(subsystem: "org.panto.ios", category: "VPNManager")

    @Published public private(set) var status: NEVPNStatus = .disconnected
    @Published public private(set) var currentUptime: Int = 0
    @Published public private(set) var upRate: Int64 = 0
    @Published public private(set) var downRate: Int64 = 0
    @Published public private(set) var activeEndpointsCount: Int = 0

    private var providerManager: NETunnelProviderManager?
    private var pollTimer: Timer?

    public init() {
        Task {
            await loadAndCreateManager()
        }
    }

    /// 从系统首选项加载或初始化 NETunnelProviderManager。
    public func loadAndCreateManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                self.providerManager = existing
            } else {
                let newManager = NETunnelProviderManager()
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = AppGroupConstants.extensionBundleID
                proto.serverAddress = "127.0.0.1"
                newManager.protocolConfiguration = proto
                newManager.localizedDescription = AppGroupConstants.defaultTunnelName
                newManager.isEnabled = true
                try await newManager.saveToPreferences()
                self.providerManager = newManager
            }

            self.status = self.providerManager?.connection.status ?? .disconnected
            setupStatusObserver()
        } catch {
            Self.logger.error("❌ 加载系统 VPN 配置失败: \(error.localizedDescription)")
        }
    }

    /// 开启隧道连接。
    public func startTunnel() async throws {
        guard let manager = providerManager else { return }
        if !manager.isEnabled {
            manager.isEnabled = true
            try await manager.saveToPreferences()
        }
        try manager.connection.startVPNTunnel()
        startPollTimer()
    }

    /// 停止隧道连接。
    public func stopTunnel() {
        providerManager?.connection.stopVPNTunnel()
        stopPollTimer()
    }

    /// 通过 IPC 向后台 Extension 发送强类型请求。
    public func sendMessage(_ request: IPCRequest) async throws -> IPCResponse {
        guard let session = providerManager?.connection as? NETunnelProviderSession else {
            throw NSError(domain: "org.panto.ios", code: -1, userInfo: [NSLocalizedDescriptionKey: "VPN 会话未连接"])
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
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: providerManager?.connection,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.status = self.providerManager?.connection.status ?? .disconnected
            if self.status == .connected {
                self.startPollTimer()
            } else if self.status == .disconnected {
                self.stopPollTimer()
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
