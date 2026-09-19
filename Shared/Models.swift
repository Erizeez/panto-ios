import Foundation

// MARK: - Core System Models

public struct VersionInfo: Codable, Sendable {
    public let version: String
    public let os: String
    public let arch: String
    public let compiler: String

    public init(version: String, os: String = "iOS", arch: String = "arm64", compiler: String = "rustc 1.95 (Zero-GC Edition)") {
        self.version = version
        self.os = os
        self.arch = arch
        self.compiler = compiler
    }
}

public struct VirtualInterfaceItem: Codable, Identifiable, Sendable {
    public var id: String { name + ipv4 }
    public let name: String
    public let type: InterfaceType
    public let ipv4: String
    public let ipv6: String?
    public let subnetMask: String?
    public let descriptionText: String
    public let isPrimaryMesh: Bool

    public enum InterfaceType: String, Codable, Sendable {
        case tailscale = "tailscale"
        case underlay = "underlay"
        case utun = "utun"

        public var iconName: String {
            switch self {
            case .tailscale: return "point.3.filled.connected.trianglepath.dotted"
            case .underlay: return "network"
            case .utun: return "shield.lefthalf.filled"
            }
        }

        public var displayName: String {
            switch self {
            case .tailscale: return "Tailscale CGNAT"
            case .underlay: return "Underlay 隧道"
            case .utun: return "iOS 系统网卡"
            }
        }
    }

    public init(
        name: String,
        type: InterfaceType,
        ipv4: String,
        ipv6: String? = nil,
        subnetMask: String? = nil,
        descriptionText: String,
        isPrimaryMesh: Bool = false
    ) {
        self.name = name
        self.type = type
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.subnetMask = subnetMask
        self.descriptionText = descriptionText
        self.isPrimaryMesh = isPrimaryMesh
    }

    enum CodingKeys: String, CodingKey {
        case name, type, ipv4, ipv6
        case subnetMask = "subnet_mask"
        case descriptionText = "description_text"
        case isPrimaryMesh = "is_primary_mesh"
    }
}

public struct SystemStatus: Codable, Sendable {
    public let running: Bool
    public let uptimeSeconds: Int
    public let mixedPort: Int
    public let mode: String
    public let globalExit: String?
    public let activeEndpoints: Int
    public let activeGroups: Int
    public let activeRules: Int
    public let assignedIp: String?
    public let virtualInterfaces: [VirtualInterfaceItem]?
    public let traffic: TrafficStats?

    public var globalTarget: String? {
        globalExit
    }

    public var primaryVirtualIp: String {
        if let ts = virtualInterfaces?.first(where: { $0.type == .tailscale }) {
            return ts.ipv4
        }
        if let underlay = virtualInterfaces?.first(where: { $0.type == .underlay }) {
            return underlay.ipv4
        }
        return assignedIp ?? "10.201.0.2"
    }

    public init(
        running: Bool,
        uptimeSeconds: Int,
        mixedPort: Int,
        mode: String,
        globalExit: String? = nil,
        globalTarget: String? = nil,
        activeEndpoints: Int = 0,
        activeGroups: Int = 0,
        activeRules: Int = 0,
        assignedIp: String? = nil,
        virtualInterfaces: [VirtualInterfaceItem]? = nil,
        traffic: TrafficStats? = nil
    ) {
        self.running = running
        self.uptimeSeconds = uptimeSeconds
        self.mixedPort = mixedPort
        self.mode = mode
        self.globalExit = globalExit ?? globalTarget
        self.activeEndpoints = activeEndpoints
        self.activeGroups = activeGroups
        self.activeRules = activeRules
        self.assignedIp = assignedIp
        self.virtualInterfaces = virtualInterfaces
        self.traffic = traffic
    }

    enum CodingKeys: String, CodingKey {
        case running
        case uptimeSeconds = "uptime_seconds"
        case mixedPort = "mixed_port"
        case mode
        case globalExit = "global_exit"
        case activeEndpoints = "active_endpoints"
        case activeGroups = "active_groups"
        case activeRules = "active_rules"
        case assignedIp = "assigned_ip"
        case virtualInterfaces = "virtual_interfaces"
        case traffic
    }
}

public enum TunnelMode: String, Codable, CaseIterable, Sendable {
    case rule = "rule"
    case global = "global"
    case direct = "direct"

    public var displayName: String {
        switch self {
        case .rule: return "规则分流"
        case .global: return "全局代理"
        case .direct: return "直连模式"
        }
    }

    public var iconName: String {
        switch self {
        case .rule: return "arrow.triangle.branch"
        case .global: return "globe.asia.australia.fill"
        case .direct: return "arrow.up.right"
        }
    }
}

public struct ModeInfo: Codable, Sendable {
    public let mode: TunnelMode
    public let globalExit: String?

    public var globalTarget: String? {
        globalExit
    }

    public init(mode: TunnelMode, globalExit: String? = nil) {
        self.mode = mode
        self.globalExit = globalExit
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case globalExit = "global_exit"
    }
}

// MARK: - Traffic Statistics

public struct TrafficStats: Codable, Sendable {
    public let uploadTotal: Int64
    public let downloadTotal: Int64
    public let uploadRateBps: Int64?
    public let downloadRateBps: Int64?

    public var upBytes: Int64 { uploadTotal }
    public var downBytes: Int64 { downloadTotal }
    public var upRateBps: Int64 { uploadRateBps ?? 0 }
    public var downRateBps: Int64 { downloadRateBps ?? 0 }

    public init(
        uploadTotal: Int64,
        downloadTotal: Int64,
        uploadRateBps: Int64? = nil,
        downloadRateBps: Int64? = nil
    ) {
        self.uploadTotal = uploadTotal
        self.downloadTotal = downloadTotal
        self.uploadRateBps = uploadRateBps
        self.downloadRateBps = downloadRateBps
    }

    // Convenience initializer matching legacy naming
    public init(upBytes: Int64, downBytes: Int64, upRateBps: Int64 = 0, downRateBps: Int64 = 0) {
        self.uploadTotal = upBytes
        self.downloadTotal = downBytes
        self.uploadRateBps = upRateBps
        self.downloadRateBps = downRateBps
    }

    enum CodingKeys: String, CodingKey {
        case uploadTotal = "upload_total"
        case downloadTotal = "download_total"
        case uploadRateBps = "upload_rate_bps"
        case downloadRateBps = "download_rate_bps"

        // 备选别名
        case upBytes = "up_bytes"
        case downBytes = "down_bytes"
        case uploadSpeed = "upload_speed"
        case downloadSpeed = "download_speed"
        case upRate = "up_rate"
        case downRate = "down_rate"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 解码 uploadTotal
        if let val = try? container.decode(Int64.self, forKey: .uploadTotal) {
            self.uploadTotal = val
        } else if let val = try? container.decode(Int64.self, forKey: .upBytes) {
            self.uploadTotal = val
        } else {
            self.uploadTotal = 0
        }

        // 解码 downloadTotal
        if let val = try? container.decode(Int64.self, forKey: .downloadTotal) {
            self.downloadTotal = val
        } else if let val = try? container.decode(Int64.self, forKey: .downBytes) {
            self.downloadTotal = val
        } else {
            self.downloadTotal = 0
        }

        // 解码 uploadRateBps
        if let val = try? container.decodeIfPresent(Int64.self, forKey: .uploadRateBps) {
            self.uploadRateBps = val
        } else if let val = try? container.decodeIfPresent(Int64.self, forKey: .uploadSpeed) {
            self.uploadRateBps = val
        } else if let val = try? container.decodeIfPresent(Int64.self, forKey: .upRate) {
            self.uploadRateBps = val
        } else {
            self.uploadRateBps = nil
        }

        // 解码 downloadRateBps
        if let val = try? container.decodeIfPresent(Int64.self, forKey: .downloadRateBps) {
            self.downloadRateBps = val
        } else if let val = try? container.decodeIfPresent(Int64.self, forKey: .downloadSpeed) {
            self.downloadRateBps = val
        } else if let val = try? container.decodeIfPresent(Int64.self, forKey: .downRate) {
            self.downloadRateBps = val
        } else {
            self.downloadRateBps = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uploadTotal, forKey: .uploadTotal)
        try container.encode(downloadTotal, forKey: .downloadTotal)
        try container.encodeIfPresent(uploadRateBps, forKey: .uploadRateBps)
        try container.encodeIfPresent(downloadRateBps, forKey: .downloadRateBps)
    }
}

// MARK: - Topology Models

public struct TopologyNodeItem: Codable, Identifiable, Sendable {
    public let id: String
    public let kind: String
    public let underlay: String?
    public let effectiveMtu: Int
    public let overhead: Int
    public let dependents: [String]?
    public let path: [String]

    public init(
        id: String,
        kind: String,
        underlay: String? = nil,
        effectiveMtu: Int,
        overhead: Int,
        dependents: [String]? = nil,
        path: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.underlay = underlay
        self.effectiveMtu = effectiveMtu
        self.overhead = overhead
        self.dependents = dependents
        self.path = path
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, underlay
        case effectiveMtu = "effective_mtu"
        case overhead, dependents, path
    }
}

public struct TopologyData: Codable, Sendable {
    public let nodes: [TopologyNodeItem]

    public init(nodes: [TopologyNodeItem]) {
        self.nodes = nodes
    }
}

// MARK: - Strategy Group Models

public struct GroupItem: Codable, Identifiable, Sendable {
    public let id: String
    public let kind: String
    public let members: [String]
    public let current: String
    public let delays: [String: Int]?

    public init(id: String, kind: String, members: [String], current: String, delays: [String: Int]? = nil) {
        self.id = id
        self.kind = kind
        self.members = members
        self.current = current
        self.delays = delays
    }
}

public struct GroupsData: Codable, Sendable {
    public let groups: [GroupItem]

    public init(groups: [GroupItem]) {
        self.groups = groups
    }
}

// MARK: - Tailscale & Magic IP Models

public struct TailscaleExitNodeItem: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let ip: String
    public let online: Bool
    public let active: Bool
    public let location: String?

    // Convenience compatibility properties for UI
    public var hostname: String { name }
    public var dnsName: String { "\(name).ts.net" }
    public var ips: [String] { [ip] }
    public var selected: Bool { active }

    public init(
        id: String,
        name: String,
        ip: String,
        online: Bool,
        active: Bool,
        location: String? = nil
    ) {
        self.id = id
        self.name = name
        self.ip = ip
        self.online = online
        self.active = active
        self.location = location
    }

    public init(
        id: String,
        hostname: String,
        dnsName: String = "",
        ips: [String] = [],
        online: Bool = true,
        selected: Bool = false,
        location: String? = nil
    ) {
        self.id = id
        self.name = hostname
        self.ip = ips.first ?? dnsName
        self.online = online
        self.active = selected
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case id, name, ip, online, active, location
    }
}

public struct MagicIPCandidate: Codable, Sendable {
    public let ip: String
    public let deviceName: String
    public let source: String

    public var hostname: String { deviceName }
    public var endpointId: String { source }
    public var dnsName: String? { ip.isEmpty ? nil : ip }
    public var priority: Int { 10 }
    public var online: Bool { true }

    public init(ip: String, deviceName: String, source: String) {
        self.ip = ip
        self.deviceName = deviceName
        self.source = source
    }

    public init(
        endpointId: String,
        priority: Int = 10,
        hostname: String,
        dnsName: String = "",
        online: Bool = true
    ) {
        self.ip = dnsName
        self.deviceName = hostname
        self.source = endpointId
    }

    enum CodingKeys: String, CodingKey {
        case ip
        case deviceName = "device_name"
        case source
    }
}

public struct MagicIPConflictItem: Codable, Identifiable, Sendable {
    public var id: String { conflictIp }
    public let conflictIp: String
    public let candidates: [MagicIPCandidate]

    public var ip: String { conflictIp }
    public var lastUsedEndpoint: String { candidates.first?.hostname ?? "" }

    public init(conflictIp: String, candidates: [MagicIPCandidate]) {
        self.conflictIp = conflictIp
        self.candidates = candidates
    }

    public init(
        ip: String,
        candidates: [MagicIPCandidate],
        detectedAt: String? = nil,
        lastUsedEndpoint: String? = nil
    ) {
        self.conflictIp = ip
        self.candidates = candidates
    }

    enum CodingKeys: String, CodingKey {
        case conflictIp = "conflict_ip"
        case candidates
    }
}

public struct MagicIPChoiceItem: Codable, Sendable {
    public let ip: String
    public let chosenDevice: String

    public var endpoint: String { chosenDevice }
    public var peerHostname: String? { chosenDevice }

    public init(ip: String, chosenDevice: String) {
        self.ip = ip
        self.chosenDevice = chosenDevice
    }

    public init(
        ip: String,
        endpoint: String,
        peerHostname: String? = nil,
        remember: Bool = true,
        updatedAt: String? = nil
    ) {
        self.ip = ip
        self.chosenDevice = peerHostname ?? endpoint
    }

    enum CodingKeys: String, CodingKey {
        case ip
        case chosenDevice = "chosen_device"
    }
}

// MARK: - Global Probe Site Models

public struct ProbeSite: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let domain: String
    public let port: Int
    public let category: String
    public let icon: String
    public let description: String

    public init(id: String, name: String, domain: String, port: Int, category: String, icon: String, description: String) {
        self.id = id
        self.name = name
        self.domain = domain
        self.port = port
        self.category = category
        self.icon = icon
        self.description = description
    }
}

public struct ProbeResultItem: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let domain: String
    public let category: String?
    public let latencyMs: Int
    public let status: String
    public let error: String?

    // UI convenience mappings
    public var ruleTarget: String { category ?? "DIRECT" }
    public var selectedEndpoint: String { id }
    public var chain: [String] { [id] }

    public init(
        id: String,
        name: String? = nil,
        domain: String,
        category: String? = nil,
        latencyMs: Int,
        status: String,
        error: String? = nil
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.category = category
        self.latencyMs = latencyMs
        self.status = status
        self.error = error
    }

    public init(
        id: String,
        name: String? = nil,
        domain: String,
        category: String? = nil,
        ruleTarget: String? = nil,
        selectedEndpoint: String? = nil,
        chain: [String]? = nil,
        latencyMs: Int,
        status: String,
        error: String? = nil
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.category = category ?? ruleTarget
        self.latencyMs = latencyMs
        self.status = status
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case id, name, domain, category
        case latencyMs = "latency_ms"
        case status, error
    }
}

// MARK: - Routing Rule Models

public struct RuleItem: Codable, Sendable {
    public let raw: String
    public let matcher: String
    public let target: String

    public var type: String { matcher }
    public var payload: String {
        let parts = raw.split(separator: ",").map(String.init)
        if parts.count >= 2 {
            return parts[1]
        }
        return ""
    }

    public init(raw: String, matcher: String, target: String) {
        self.raw = raw
        self.matcher = matcher
        self.target = target
    }

    public init(type: String, payload: String, target: String) {
        self.matcher = type
        self.target = target
        if payload.isEmpty {
            self.raw = "\(type.uppercased()),\(target)"
        } else {
            self.raw = "\(type.uppercased()),\(payload),\(target)"
        }
    }
}

public struct RulesResponse: Codable, Sendable {
    public let total: Int
    public let rules: [RuleItem]

    public init(total: Int, rules: [RuleItem]) {
        self.total = total
        self.rules = rules
    }
}

public struct RuleMatchRequest: Codable, Sendable {
    public let domain: String?
    public let ip: String?
    public let port: Int?
    public let protocolName: String?

    public init(domain: String? = nil, ip: String? = nil, port: Int? = nil, protocolName: String? = nil) {
        self.domain = domain
        self.ip = ip
        self.port = port
        self.protocolName = protocolName
    }

    enum CodingKeys: String, CodingKey {
        case domain, ip, port
        case protocolName = "protocol"
    }
}

public struct RuleMatchResponse: Codable, Sendable {
    public let matched: Bool
    public let rule: String?
    public let target: String?

    public init(matched: Bool, rule: String? = nil, target: String? = nil) {
        self.matched = matched
        self.rule = rule
        self.target = target
    }

    public init(rule: String?, target: String?, matched: Bool) {
        self.matched = matched
        self.rule = rule
        self.target = target
    }
}

public typealias RuleMatchResult = RuleMatchResponse

// MARK: - Observation Telemetry Models

public struct ObservationConsentItem: Codable, Identifiable, Sendable {
    public var id: String { nodeId }
    public let nodeId: String
    public let providerName: String?
    public let url: String
    public let status: String
    public let requestedAtMs: Int64
    public let decidedAtMs: Int64?

    public var endpointId: String { nodeId }
    public var endpointName: String { providerName ?? nodeId }
    public var targetDomain: String { url }
    public var reason: String { "出站网关观测遥测授权" }

    public init(
        nodeId: String,
        providerName: String? = nil,
        url: String,
        status: String = "pending",
        requestedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        decidedAtMs: Int64? = nil
    ) {
        self.nodeId = nodeId
        self.providerName = providerName
        self.url = url
        self.status = status
        self.requestedAtMs = requestedAtMs
        self.decidedAtMs = decidedAtMs
    }

    public init(
        endpointId: String,
        endpointName: String? = nil,
        targetDomain: String,
        requestedAt: String? = nil,
        reason: String? = nil
    ) {
        self.nodeId = endpointId
        self.providerName = endpointName
        self.url = targetDomain
        self.status = "pending"
        self.requestedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        self.decidedAtMs = nil
    }

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case providerName = "provider_name"
        case url, status
        case requestedAtMs = "requested_at_ms"
        case decidedAtMs = "decided_at_ms"
    }
}
