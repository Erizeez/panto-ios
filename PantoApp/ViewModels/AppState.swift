import Foundation
import Combine
import SwiftUI
import PantoShared
import NetworkExtension

public struct TrafficPoint: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let upRate: Double // KB/s
    public let downRate: Double // KB/s

    public init(timestamp: Date = Date(), upRate: Double, downRate: Double) {
        self.timestamp = timestamp
        self.upRate = upRate
        self.downRate = downRate
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var vpn: VPNManager
    @Published public var client: PantoClientProtocol
    @Published public var useMockMode: Bool = false {
        didSet {
            setupClient()
            Task { await refreshAll() }
        }
    }

    @Published public var systemStatus: SystemStatus?
    @Published public var currentMode: TunnelMode = .rule
    @Published public var globalTarget: String? = nil
    @Published public var groups: [GroupItem] = []
    @Published public var topology: TopologyData?
    @Published public var magicConflicts: [MagicIPConflictItem] = []
    @Published public var magicChoices: [MagicIPChoiceItem] = []
    @Published public var probeResults: [ProbeResultItem] = []
    @Published public var probeSites: [ProbeSite] = []
    @Published public var activeProbingId: String? = nil

    @Published public var trafficHistory: [TrafficPoint] = []
    @Published public var currentUpRate: Int64 = 0
    @Published public var currentDownRate: Int64 = 0

    @Published public var isProbing: Bool = false
    @Published public var isTestingDelays: Bool = false
    @Published public var showingConflictSheet: Bool = false
    @Published public var selectedConflict: MagicIPConflictItem? = nil
    @Published public var showingVirtualInterfacesSheet: Bool = false

    private var pollTimer: Timer?
    private var mockClient = MockPantoClient()

    public init(vpnManager: VPNManager) {
        self.vpn = vpnManager
        self.client = mockClient
        setupClient()

        // 初始填充平滑起伏的历史流量点 (供点阵频谱图展示冷暖色彩变化)
        let now = Date()
        for i in (0..<52).reversed() {
            let t = Double(52 - i)
            // 叠加正弦波与随机爆发，产生明显的峰谷与冷暖色阶变化
            let upBurst = sin(t / 4.0) * 800.0 + sin(t / 1.5) * 400.0 + 1200.0
            let downBurst = sin(t / 3.2) * 8000.0 + sin(t / 1.8) * 4000.0 + 10500.0
            let upRate = max(5.0, upBurst + Double.random(in: -100...200))
            let downRate = max(15.0, downBurst + Double.random(in: -800...1200))

            trafficHistory.append(
                TrafficPoint(
                    timestamp: now.addingTimeInterval(-Double(i)),
                    upRate: upRate,
                    downRate: downRate
                )
            )
        }

        Task {
            await refreshAll()
            startPolling()
        }
    }

    private func setupClient() {
        if useMockMode {
            self.client = mockClient
        } else {
            self.client = IPCPantoClient { [weak self] req in
                guard let self = self else { throw NSError(domain: "panto", code: -1) }
                return try await self.vpn.sendMessage(req)
            }
        }
    }

    public func refreshAll() async {
        async let statusTask = try? client.getStatus()
        async let modeTask = try? client.getMode()
        async let groupsTask = try? client.getGroups()
        async let topoTask = try? client.getTopology()
        async let conflictTask = try? client.getMagicIPPending()
        async let probeSitesTask = try? client.getProbeSites()

        if let st = await statusTask {
            self.systemStatus = st
        }
        if let md = await modeTask {
            self.currentMode = md.mode
            self.globalTarget = md.globalTarget
        }
        if let gp = await groupsTask {
            self.groups = gp.groups
        }
        if let tp = await topoTask {
            self.topology = tp
        }
        if let cf = await conflictTask {
            self.magicConflicts = cf
            if !cf.isEmpty && selectedConflict == nil {
                self.selectedConflict = cf.first
            }
        }
        if let ps = await probeSitesTask {
            self.probeSites = ps
        }
    }

    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.pollTick()
            }
        }
    }

    private func pollTick() async {
        if let stats = try? await client.getTraffic() {
            self.currentUpRate = stats.upRateBps
            self.currentDownRate = stats.downRateBps

            let upKB = Double(stats.upRateBps) / 1024.0
            let downKB = Double(stats.downRateBps) / 1024.0
            
            withAnimation(.linear(duration: 0.8)) {
                self.trafficHistory.append(TrafficPoint(timestamp: Date(), upRate: upKB, downRate: downKB))
                if self.trafficHistory.count > 60 {
                    self.trafficHistory.removeFirst()
                }
            }
        }

        if let st = try? await client.getStatus() {
            self.systemStatus = st
        }
    }

    public func toggleTunnel() async {
        if vpn.status == .connected {
            vpn.stopTunnel()
        } else {
            try? await vpn.startTunnel()
        }
        await refreshAll()
    }

    public func switchMode(_ mode: TunnelMode) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentMode = mode
        }
        _ = try? await client.setMode(mode, globalTarget: globalTarget)
    }

    public func selectGroupMember(groupId: String, memberId: String) async {
        if let updated = try? await client.selectGroupMember(groupId: groupId, memberId: memberId) {
            if let idx = groups.firstIndex(where: { $0.id == groupId }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    groups[idx] = updated
                }
            }
        }
    }

    public func testGroupDelay(groupId: String) async {
        isTestingDelays = true
        defer { isTestingDelays = false }
        if let newDelays = try? await client.testGroupDelay(groupId: groupId, url: nil, timeoutMs: 2500) {
            if let idx = groups.firstIndex(where: { $0.id == groupId }) {
                let current = groups[idx]
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    groups[idx] = GroupItem(
                        id: current.id,
                        kind: current.kind,
                        members: current.members,
                        current: current.current,
                        delays: newDelays
                    )
                }
            }
        }
    }

    public func resolveMagicIP(ip: String, endpoint: String, remember: Bool) async {
        let success = (try? await client.decideMagicIP(ip: ip, endpoint: endpoint, remember: remember)) ?? false
        if success {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                magicConflicts.removeAll(where: { $0.ip == ip })
                showingConflictSheet = false
                selectedConflict = nil
            }
        }
    }

    public func runProbeStream() async {
        isProbing = true
        probeResults = []
        if probeSites.isEmpty {
            probeSites = (try? await client.getProbeSites()) ?? []
        }
        let stream = client.streamProbeSites()
        for await result in stream {
            self.activeProbingId = result.id
            self.probeResults.append(result)
        }
        withAnimation(.easeOut(duration: 0.3)) {
            self.activeProbingId = nil
            self.isProbing = false
        }
    }
}
