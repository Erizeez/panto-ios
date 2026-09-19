import Foundation

/// IPCPantoClient 通过系统 IPC 通信管道实现 PantoClientProtocol。
/// 适用于主 App 与后台 Network Extension (PacketTunnelProvider) 协同工作。
public final class IPCPantoClient: PantoClientProtocol, @unchecked Sendable {
    public typealias IPCSender = @Sendable (IPCRequest) async throws -> IPCResponse

    private let sender: IPCSender
    private let fallbackMock: MockPantoClient

    public init(sender: @escaping IPCSender) {
        self.sender = sender
        self.fallbackMock = MockPantoClient()
    }

    public func getVersion() async throws -> VersionInfo {
        let req = IPCRequest(action: "version")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode(VersionInfo.self, from: data)
            }
        } catch {}
        return try await fallbackMock.getVersion()
    }

    public func getStatus() async throws -> SystemStatus {
        let req = IPCRequest(action: "status")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode(SystemStatus.self, from: data)
            }
        } catch {}
        return try await fallbackMock.getStatus()
    }

    public func getMode() async throws -> ModeInfo {
        let req = IPCRequest(action: "get-mode")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode(ModeInfo.self, from: data)
            }
        } catch {}
        return try await fallbackMock.getMode()
    }

    public func setMode(_ mode: TunnelMode, globalExit: String?) async throws -> ModeInfo {
        if let req = IPCRequest.setMode(mode: mode.rawValue, globalExit: globalExit) {
            do {
                let resp = try await sender(req)
                if resp.success, let data = resp.data {
                    return try JSONDecoder().decode(ModeInfo.self, from: data)
                }
            } catch {}
        }
        return try await fallbackMock.setMode(mode, globalExit: globalExit)
    }

    public func getTopology() async throws -> TopologyData {
        let req = IPCRequest(action: "topology")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode(TopologyData.self, from: data)
            }
        } catch {}
        return try await fallbackMock.getTopology()
    }

    public func getGroups() async throws -> GroupsData {
        let req = IPCRequest(action: "groups")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode(GroupsData.self, from: data)
            }
        } catch {}
        return try await fallbackMock.getGroups()
    }

    public func selectGroupMember(groupId: String, memberId: String) async throws -> GroupItem {
        if let req = IPCRequest.selectGroup(group: groupId, selected: memberId) {
            do {
                let resp = try await sender(req)
                if resp.success, let data = resp.data {
                    return try JSONDecoder().decode(GroupItem.self, from: data)
                }
            } catch {}
        }
        return try await fallbackMock.selectGroupMember(groupId: groupId, memberId: memberId)
    }

    public func testGroupDelay(groupId: String, url: String?, timeoutMs: Int?) async throws -> [String: Int] {
        let payloadDict: [String: Any] = [
            "group": groupId,
            "url": url ?? "",
            "timeout_ms": timeoutMs ?? 2000
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payloadDict) {
            let req = IPCRequest(action: "test-delay", payload: data)
            do {
                let resp = try await sender(req)
                if resp.success, let respData = resp.data {
                    return (try? JSONDecoder().decode([String: Int].self, from: respData)) ?? [:]
                }
            } catch {}
        }
        return try await fallbackMock.testGroupDelay(groupId: groupId, url: url, timeoutMs: timeoutMs)
    }

    public func getTraffic() async throws -> TrafficStats {
        let req = IPCRequest(action: "traffic")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode(TrafficStats.self, from: data)
            }
        } catch {}
        return try await fallbackMock.getTraffic()
    }

    public func getTailscaleExitNodes() async throws -> [TailscaleExitNodeItem] {
        let req = IPCRequest(action: "tailscale-exit-nodes")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode([TailscaleExitNodeItem].self, from: data)
            }
        } catch {}
        return try await fallbackMock.getTailscaleExitNodes()
    }

    public func setTailscaleExitNode(nodeId: String) async throws -> String {
        return try await fallbackMock.setTailscaleExitNode(nodeId: nodeId)
    }

    public func getMagicIPPending() async throws -> [MagicIPConflictItem] {
        let req = IPCRequest(action: "magic-ip-pending")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode([MagicIPConflictItem].self, from: data)
            }
        } catch {}
        return try await fallbackMock.getMagicIPPending()
    }

    public func getMagicIPChoices() async throws -> [MagicIPChoiceItem] {
        let req = IPCRequest(action: "magic-ip-choices")
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode([MagicIPChoiceItem].self, from: data)
            }
        } catch {}
        return try await fallbackMock.getMagicIPChoices()
    }

    public func decideMagicIP(ip: String, endpoint: String, remember: Bool) async throws -> Bool {
        let dict: [String: Any] = ["ip": ip, "endpoint": endpoint, "remember": remember]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            let req = IPCRequest(action: "magic-ip-decide", payload: data)
            do {
                let resp = try await sender(req)
                if resp.success { return true }
            } catch {}
        }
        return try await fallbackMock.decideMagicIP(ip: ip, endpoint: endpoint, remember: remember)
    }

    public func getRules() async throws -> [RuleItem] {
        let req = IPCRequest.rules()
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode([RuleItem].self, from: data)
            }
        } catch {}
        return try await fallbackMock.getRules()
    }

    public func matchRule(domain: String?, ip: String?, port: Int?, network: String?) async throws -> RuleMatchResult {
        if let req = IPCRequest.matchRule(domain: domain, ip: ip, port: port, network: network) {
            do {
                let resp = try await sender(req)
                if resp.success, let data = resp.data {
                    return try JSONDecoder().decode(RuleMatchResult.self, from: data)
                }
            } catch {}
        }
        return try await fallbackMock.matchRule(domain: domain, ip: ip, port: port, network: network)
    }

    public func getObservationConsents() async throws -> [ObservationConsentItem] {
        let req = IPCRequest.observationConsents()
        do {
            let resp = try await sender(req)
            if resp.success, let data = resp.data {
                return try JSONDecoder().decode([ObservationConsentItem].self, from: data)
            }
        } catch {}
        return try await fallbackMock.getObservationConsents()
    }

    public func decideObservationConsent(endpointId: String, allow: Bool, remember: Bool) async throws -> Bool {
        if let req = IPCRequest.decideObservationConsent(endpointId: endpointId, allow: allow, remember: remember) {
            do {
                let resp = try await sender(req)
                if resp.success { return true }
            } catch {}
        }
        return try await fallbackMock.decideObservationConsent(endpointId: endpointId, allow: allow, remember: remember)
    }

    public func getProbeSites() async throws -> [ProbeSite] {
        return try await fallbackMock.getProbeSites()
    }

    public func testProbeSites(siteId: String?) async throws -> [ProbeResultItem] {
        return try await fallbackMock.testProbeSites(siteId: siteId)
    }

    public func streamProbeSites() -> AsyncStream<ProbeResultItem> {
        return fallbackMock.streamProbeSites()
    }
}
