import Foundation

/// MockPantoClient 是符合 PantoClientProtocol 的高保真内存模拟实现。
/// 用于脱机独立开发、交互测试以及 SwiftUI Previews。
public final class MockPantoClient: PantoClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var currentMode: TunnelMode = .rule
    private var globalTarget: String? = "🇸🇬 新加坡 01"
    private var isRunning: Bool = true
    private var startTimestamp: Date = Date().addingTimeInterval(-3720) // 1 hour ago
    
    private var groups: [GroupItem] = [
        GroupItem(
            id: "⚡ 节点选择 (Proxy)",
            kind: "select",
            members: ["🇸🇬 新加坡 01", "🇯🇵 东京 02", "🇭🇰 香港 01", "🇺🇸 圣何塞 03", "DIRECT"],
            current: "🇸🇬 新加坡 01",
            delays: ["🇸🇬 新加坡 01": 42, "🇯🇵 东京 02": 68, "🇭🇰 香港 01": 28, "🇺🇸 圣何塞 03": 145, "DIRECT": 5]
        ),
        GroupItem(
            id: "🚀 自动选优 (Auto)",
            kind: "url-test",
            members: ["🇸🇬 新加坡 01", "🇯🇵 东京 02", "🇭🇰 香港 01"],
            current: "🇭🇰 香港 01",
            delays: ["🇸🇬 新加坡 01": 42, "🇯🇵 东京 02": 68, "🇭🇰 香港 01": 28]
        ),
        GroupItem(
            id: "🏫 校园与企业内网 (Campus)",
            kind: "select",
            members: ["🏢 IKEv2 网关", "🌐 Tailscale 网格", "DIRECT"],
            current: "🏢 IKEv2 网关",
            delays: ["🏢 IKEv2 网关": 12, "🌐 Tailscale 网格": 18, "DIRECT": 6]
        ),
        GroupItem(
            id: "🛡️ 容灾备用 (Fallback)",
            kind: "fallback",
            members: ["🇸🇬 新加坡 01", "DIRECT"],
            current: "🇸🇬 新加坡 01",
            delays: ["🇸🇬 新加坡 01": 42, "DIRECT": 5]
        )
    ]

    private var topologyNodes: [TopologyNodeItem] = [
        TopologyNodeItem(
            id: "DIRECT",
            kind: "direct",
            underlay: nil,
            effectiveMtu: 1500,
            overhead: 0,
            dependents: ["🏢 IKEv2 网关", "🇸🇬 新加坡 01", "DIRECT-LAN"],
            path: ["DIRECT"]
        ),
        TopologyNodeItem(
            id: "🏢 IKEv2 网关",
            kind: "ikev2",
            underlay: "DIRECT",
            effectiveMtu: 1420,
            overhead: 80,
            dependents: ["🌐 Tailscale 网格"],
            path: ["DIRECT", "🏢 IKEv2 网关"]
        ),
        TopologyNodeItem(
            id: "🌐 Tailscale 网格",
            kind: "tailscale",
            underlay: "🏢 IKEv2 网关",
            effectiveMtu: 1280,
            overhead: 140,
            dependents: ["ExitNode-Tokyo"],
            path: ["DIRECT", "🏢 IKEv2 网关", "🌐 Tailscale 网格"]
        ),
        TopologyNodeItem(
            id: "ExitNode-Tokyo",
            kind: "wireguard",
            underlay: "🌐 Tailscale 网格",
            effectiveMtu: 1240,
            overhead: 40,
            dependents: nil,
            path: ["DIRECT", "🏢 IKEv2 网关", "🌐 Tailscale 网格", "ExitNode-Tokyo"]
        ),
        TopologyNodeItem(
            id: "🇸🇬 新加坡 01",
            kind: "shadowsocks",
            underlay: "DIRECT",
            effectiveMtu: 1460,
            overhead: 40,
            dependents: nil,
            path: ["DIRECT", "🇸🇬 新加坡 01"]
        )
    ]

    private var magicConflicts: [MagicIPConflictItem] = [
        MagicIPConflictItem(
            ip: "100.64.0.18",
            candidates: [
                MagicIPCandidate(endpointId: "ep-work-mbp", priority: 10, hostname: "Work-MacBook-Pro", dnsName: "work-mbp.ts.net", online: true),
                MagicIPCandidate(endpointId: "ep-home-nas", priority: 5, hostname: "Home-Synology-NAS", dnsName: "home-nas.ts.net", online: true)
            ],
            detectedAt: "2026-09-19T10:15:00Z",
            lastUsedEndpoint: "Work-MacBook-Pro"
        )
    ]

    private var magicChoices: [MagicIPChoiceItem] = []

    private var rules: [RuleItem] = [
        RuleItem(type: "domain-suffix", payload: "apple.com", target: "DIRECT"),
        RuleItem(type: "domain-suffix", payload: "icloud.com", target: "DIRECT"),
        RuleItem(type: "domain-suffix", payload: "google.com", target: "⚡ 节点选择 (Proxy)"),
        RuleItem(type: "domain-suffix", payload: "github.com", target: "⚡ 节点选择 (Proxy)"),
        RuleItem(type: "domain-suffix", payload: "openai.com", target: "⚡ 节点选择 (Proxy)"),
        RuleItem(type: "ip-cidr", payload: "100.64.0.0/10", target: "🌐 Tailscale 网格"),
        RuleItem(type: "geoip", payload: "CN", target: "DIRECT"),
        RuleItem(type: "match", payload: "", target: "⚡ 节点选择 (Proxy)")
    ]

    private var observationConsents: [ObservationConsentItem] = [
        ObservationConsentItem(
            endpointId: "ep-corporate-proxy",
            endpointName: "🏢 企业合规审计节点",
            targetDomain: "internal.enterprise.corp",
            requestedAt: "2026-09-19T11:00:00Z",
            reason: "检测到企业内网流量，远端网关请求出站观测与遥测授权"
        )
    ]

    private var probeSites: [ProbeSite] = ProbeSiteCatalog.defaultSites

    public init() {}

    public func getVersion() async throws -> VersionInfo {
        return VersionInfo(version: "2.4.0-ios-release", os: "darwin", arch: "arm64", compiler: "rustc 1.88.0")
    }

    public func getStatus() async throws -> SystemStatus {
        let uptime = Int(Date().timeIntervalSince(startTimestamp))
        let virtualInterfaces = [
            VirtualInterfaceItem(
                name: "Tailscale Mesh",
                type: .tailscale,
                ipv4: "100.86.32.14",
                ipv6: "fd7a:115c:a1e0:ab12::3214",
                subnetMask: "100.64.0.0/10",
                descriptionText: "Tailnet 设备全局唯一 Magic IP，用于跨网穿透、SSH 与局域网服务互访",
                isPrimaryMesh: true
            ),
            VirtualInterfaceItem(
                name: "Tokyo-WG-01",
                type: .underlay,
                ipv4: "10.14.0.5",
                ipv6: nil,
                subnetMask: "10.14.0.0/24",
                descriptionText: "当前活动出站节点在远端 VPN 协议中分配的隧道内网地址",
                isPrimaryMesh: false
            ),
            VirtualInterfaceItem(
                name: "iOS 系统网卡 (utun)",
                type: .utun,
                ipv4: "10.201.0.2",
                ipv6: nil,
                subnetMask: "255.255.255.0",
                descriptionText: "iOS NetworkExtension 唯一分配的系统虚拟槽位，负责将系统出站流量转入 Panto",
                isPrimaryMesh: false
            )
        ]

        return SystemStatus(
            running: isRunning,
            uptimeSeconds: uptime,
            mixedPort: 9090,
            mode: currentMode.rawValue,
            globalTarget: globalTarget,
            activeEndpoints: 14,
            activeGroups: groups.count,
            activeRules: 128,
            assignedIp: "10.201.0.2",
            virtualInterfaces: virtualInterfaces
        )
    }

    public func getMode() async throws -> ModeInfo {
        return ModeInfo(mode: currentMode, globalExit: globalTarget)
    }

    public func setMode(_ mode: TunnelMode, globalExit: String?) async throws -> ModeInfo {
        self.currentMode = mode
        self.globalTarget = globalExit
        return ModeInfo(mode: mode, globalExit: globalExit)
    }

    public func getTopology() async throws -> TopologyData {
        return TopologyData(nodes: topologyNodes)
    }

    public func getGroups() async throws -> GroupsData {
        return GroupsData(groups: groups)
    }

    public func selectGroupMember(groupId: String, memberId: String) async throws -> GroupItem {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else {
            throw NSError(domain: "org.panto.mock", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        let updated = GroupItem(
            id: groups[idx].id,
            kind: groups[idx].kind,
            members: groups[idx].members,
            current: memberId,
            delays: groups[idx].delays
        )
        groups[idx] = updated
        return updated
    }

    public func testGroupDelay(groupId: String, url: String?, timeoutMs: Int?) async throws -> [String: Int] {
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms 模拟测速
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else {
            return [:]
        }
        var newDelays: [String: Int] = [:]
        for m in groups[idx].members {
            if m == "DIRECT" {
                newDelays[m] = Int.random(in: 4...12)
            } else {
                newDelays[m] = Int.random(in: 25...160)
            }
        }
        let updated = GroupItem(
            id: groups[idx].id,
            kind: groups[idx].kind,
            members: groups[idx].members,
            current: groups[idx].current,
            delays: newDelays
        )
        groups[idx] = updated
        return newDelays
    }

    public func getTraffic() async throws -> TrafficStats {
        let baseUp = Int64.random(in: 80_000...450_000)
        let baseDown = Int64.random(in: 400_000...3_800_000)
        return TrafficStats(
            upBytes: 1024 * 1024 * 142 + baseUp,
            downBytes: 1024 * 1024 * 892 + baseDown,
            upRateBps: baseUp,
            downRateBps: baseDown
        )
    }

    public func getTailscaleExitNodes() async throws -> [TailscaleExitNodeItem] {
        return [
            TailscaleExitNodeItem(id: "node-1", hostname: "tokyo-exit-node", dnsName: "tokyo-exit.tailnet.ts.net", ips: ["100.64.0.2"], online: true, selected: true),
            TailscaleExitNodeItem(id: "node-2", hostname: "us-west-exit", dnsName: "us-west.tailnet.ts.net", ips: ["100.64.0.3"], online: true, selected: false)
        ]
    }

    public func setTailscaleExitNode(nodeId: String) async throws -> String {
        return nodeId
    }

    public func getMagicIPPending() async throws -> [MagicIPConflictItem] {
        return magicConflicts
    }

    public func getMagicIPChoices() async throws -> [MagicIPChoiceItem] {
        return magicChoices
    }

    public func decideMagicIP(ip: String, endpoint: String, remember: Bool) async throws -> Bool {
        magicConflicts.removeAll(where: { $0.ip == ip })
        if remember {
            magicChoices.append(MagicIPChoiceItem(ip: ip, endpoint: endpoint, peerHostname: endpoint, remember: true, updatedAt: "2026-09-19T11:50:00Z"))
        }
        return true
    }

    public func getRules() async throws -> [RuleItem] {
        return rules
    }

    public func matchRule(domain: String?, ip: String?, port: Int?, network: String?) async throws -> RuleMatchResult {
        if let domain = domain {
            if domain.contains("apple") || domain.contains("icloud") {
                return RuleMatchResult(rule: "DOMAIN-SUFFIX,apple.com,DIRECT", target: "DIRECT", matched: true)
            }
            if domain.contains("google") || domain.contains("github") || domain.contains("openai") {
                return RuleMatchResult(rule: "DOMAIN-SUFFIX,\(domain),⚡ 节点选择 (Proxy)", target: "⚡ 节点选择 (Proxy)", matched: true)
            }
        }
        if let ip = ip, ip.hasPrefix("100.") {
            return RuleMatchResult(rule: "IP-CIDR,100.64.0.0/10,🌐 Tailscale 网格", target: "🌐 Tailscale 网格", matched: true)
        }
        return RuleMatchResult(rule: "MATCH,DIRECT", target: "DIRECT", matched: true)
    }

    public func getObservationConsents() async throws -> [ObservationConsentItem] {
        return observationConsents
    }

    public func decideObservationConsent(endpointId: String, allow: Bool, remember: Bool) async throws -> Bool {
        observationConsents.removeAll(where: { $0.endpointId == endpointId })
        return true
    }

    public func getProbeSites() async throws -> [ProbeSite] {
        return probeSites
    }

    public func testProbeSites(siteId: String?) async throws -> [ProbeResultItem] {
        var results: [ProbeResultItem] = []
        let targets = siteId != nil ? probeSites.filter { $0.id == siteId } : probeSites
        for site in targets {
            let isDirect = site.category.contains("国内")
            results.append(
                ProbeResultItem(
                    id: site.id,
                    domain: site.domain,
                    ruleTarget: isDirect ? "DIRECT" : "⚡ 节点选择 (Proxy)",
                    selectedEndpoint: isDirect ? "DIRECT" : "🇸🇬 新加坡 01",
                    chain: isDirect ? ["DIRECT"] : ["DIRECT", "🇸🇬 新加坡 01"],
                    latencyMs: isDirect ? Int.random(in: 10...30) : Int.random(in: 40...120),
                    status: "200 OK",
                    error: nil
                )
            )
        }
        return results
    }

    public func streamProbeSites() -> AsyncStream<ProbeResultItem> {
        let sites = self.probeSites
        return AsyncStream { continuation in
            Task {
                for (_, site) in sites.enumerated() {
                    try? await Task.sleep(nanoseconds: 40_000_000) // 40ms 逐个高速流式返回
                    let isDirect = site.category.contains("国内") || site.category.contains("校园")
                    let isFailed = (site.id == "site-telegram" || site.id == "site-hetzner" || site.id == "site-wsj") // 模拟故障红格节点
                    let isTimeout = (site.id == "site-netflix")
                    
                    let item: ProbeResultItem
                    if isFailed {
                        item = ProbeResultItem(
                            id: site.id,
                            domain: site.domain,
                            ruleTarget: "⚡ 节点选择 (Proxy)",
                            selectedEndpoint: "🇸🇬 新加坡 01",
                            chain: ["DIRECT", "🇸🇬 新加坡 01"],
                            latencyMs: -1,
                            status: site.id == "site-hetzner" ? "502 Bad Gateway" : "504 Gateway Timeout",
                            error: site.id == "site-hetzner" ? "欧洲边缘路由不可达 (Host Unreachable)" : "连接超时 (2500ms)"
                        )
                    } else if isTimeout {
                        item = ProbeResultItem(
                            id: site.id,
                            domain: site.domain,
                            ruleTarget: "⚡ 节点选择 (Proxy)",
                            selectedEndpoint: "🇸🇬 新加坡 01",
                            chain: ["DIRECT", "🇸🇬 新加坡 01"],
                            latencyMs: 380,
                            status: "403 Forbidden",
                            error: "地区限制解锁失败"
                        )
                    } else {
                        item = ProbeResultItem(
                            id: site.id,
                            domain: site.domain,
                            ruleTarget: isDirect ? "DIRECT" : "⚡ 节点选择 (Proxy)",
                            selectedEndpoint: isDirect ? "DIRECT" : "🇸🇬 新加坡 01",
                            chain: isDirect ? ["DIRECT"] : ["DIRECT", "🇸🇬 新加坡 01"],
                            latencyMs: isDirect ? Int.random(in: 12...35) : Int.random(in: 45...140),
                            status: "200 OK",
                            error: nil
                        )
                    }
                    continuation.yield(item)
                }
                continuation.finish()
            }
        }
    }
}
