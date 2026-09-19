import Foundation

/// PantoClientProtocol 是 Panto 客户端契约接口，对齐官方 OpenAPI 3.0.3 规范。
public protocol PantoClientProtocol: Sendable {
    /// 获取内核版本与编译架构 (GET /version)
    func getVersion() async throws -> VersionInfo

    /// 获取系统实时运行状态 (GET /status)
    func getStatus() async throws -> SystemStatus

    /// 获取当前运行模式与全局出口 (GET /mode)
    func getMode() async throws -> ModeInfo

    /// 切换运行模式 (rule / global / direct) (POST /mode)
    func setMode(_ mode: TunnelMode, globalExit: String?) async throws -> ModeInfo

    /// 获取链路有向图 (Underlay DAG) 拓扑 (GET /topology)
    func getTopology() async throws -> TopologyData

    /// 获取所有策略调度组 (GET /groups)
    func getGroups() async throws -> GroupsData

    /// 切换指定策略组的手动出站节点 (POST /groups/{group}/select)
    func selectGroupMember(groupId: String, memberId: String) async throws -> GroupItem

    /// 并发测试策略组内各节点的延迟 (POST /groups/{group}/delay)
    func testGroupDelay(groupId: String, url: String?, timeoutMs: Int?) async throws -> [String: Int]

    /// 获取当前上下行流量与瞬时吞吐 (GET /traffic)
    func getTraffic() async throws -> TrafficStats

    /// 获取系统分流规则列表 (GET /rules)
    func getRules() async throws -> [RuleItem]

    /// 匹配规则测试 (GET /rules/match)
    func matchRule(domain: String?, ip: String?, port: Int?, network: String?) async throws -> RuleMatchResult

    /// 获取 Tailnet 远端 Exit Node 列表 (GET /tailscale/exit-nodes)
    func getTailscaleExitNodes() async throws -> [TailscaleExitNodeItem]

    /// 设置消费的 Tailscale Exit Node (POST /tailscale/exit-nodes/select)
    func setTailscaleExitNode(nodeId: String) async throws -> String

    /// 获取待裁决的 Tailscale Magic IP 冲突列表 (GET /tailscale/magic-ip/pending)
    func getMagicIPPending() async throws -> [MagicIPConflictItem]

    /// 获取已记住的 Magic IP 决策 (GET /tailscale/magic-ip/choices)
    func getMagicIPChoices() async throws -> [MagicIPChoiceItem]

    /// 提交用户对特定冲突 IP 的单点路由决策 (POST /tailscale/magic-ip/decide)
    func decideMagicIP(ip: String, endpoint: String, remember: Bool) async throws -> Bool

    /// 获取待授权的出站观察请求 (GET /observation/consents)
    func getObservationConsents() async throws -> [ObservationConsentItem]

    /// 决策出站观察授权 (POST /observation/consents/decide)
    func decideObservationConsent(endpointId: String, allow: Bool, remember: Bool) async throws -> Bool

    /// 获取预置全球测试站点列表
    func getProbeSites() async throws -> [ProbeSite]

    /// 执行站点连通性与分流链路测试
    func testProbeSites(siteId: String?) async throws -> [ProbeResultItem]

    /// 实时流式测速事件流 (SSE 抽象)
    func streamProbeSites() -> AsyncStream<ProbeResultItem>
}

public extension PantoClientProtocol {
    /// 兼容旧代码使用 globalTarget 命名的重载方法
    func setMode(_ mode: TunnelMode, globalTarget: String?) async throws -> ModeInfo {
        return try await setMode(mode, globalExit: globalTarget)
    }

    /// 缺省全局出口时的重载方法
    func setMode(_ mode: TunnelMode) async throws -> ModeInfo {
        return try await setMode(mode, globalExit: nil)
    }

    func matchRule(domain: String? = nil, ip: String? = nil, port: Int? = nil, network: String? = nil) async throws -> RuleMatchResult {
        return try await matchRule(domain: domain, ip: ip, port: port, network: network)
    }

    func getRules() async throws -> [RuleItem] {
        return []
    }

    func getObservationConsents() async throws -> [ObservationConsentItem] {
        return []
    }

    func decideObservationConsent(endpointId: String, allow: Bool, remember: Bool) async throws -> Bool {
        return true
    }
}
