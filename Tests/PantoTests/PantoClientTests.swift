import XCTest
@testable import PantoShared

final class PantoClientTests: XCTestCase {
    func testMockClientBasicStatus() async throws {
        let client = MockPantoClient()
        let version = try await client.getVersion()
        XCTAssertFalse(version.version.isEmpty)
        XCTAssertEqual(version.arch, "arm64")

        let status = try await client.getStatus()
        XCTAssertTrue(status.running)
        XCTAssertEqual(status.mode, "rule")
        XCTAssertEqual(status.activeEndpoints, 14)
    }

    func testMockClientModeSwitch() async throws {
        let client = MockPantoClient()
        var modeInfo = try await client.getMode()
        XCTAssertEqual(modeInfo.mode, .rule)

        modeInfo = try await client.setMode(.global, globalTarget: "🇸🇬 新加坡 01")
        XCTAssertEqual(modeInfo.mode, .global)
        XCTAssertEqual(modeInfo.globalTarget, "🇸🇬 新加坡 01")

        modeInfo = try await client.setMode(.direct, globalTarget: nil)
        XCTAssertEqual(modeInfo.mode, .direct)
    }

    func testMockClientGroupsAndDelay() async throws {
        let client = MockPantoClient()
        let groupsData = try await client.getGroups()
        XCTAssertFalse(groupsData.groups.isEmpty)

        let targetGroup = groupsData.groups[0]
        let newMember = targetGroup.members.last!
        let updated = try await client.selectGroupMember(groupId: targetGroup.id, memberId: newMember)
        XCTAssertEqual(updated.current, newMember)

        let delays = try await client.testGroupDelay(groupId: targetGroup.id, url: nil, timeoutMs: 1000)
        XCTAssertFalse(delays.isEmpty)
        XCTAssertNotNil(delays[newMember])
    }

    func testMockClientMagicIPConflictResolution() async throws {
        let client = MockPantoClient()
        let conflicts = try await client.getMagicIPPending()
        XCTAssertFalse(conflicts.isEmpty)

        let conflict = conflicts[0]
        let candidate = conflict.candidates[0].hostname
        let success = try await client.decideMagicIP(ip: conflict.ip, endpoint: candidate, remember: true)
        XCTAssertTrue(success)

        let remaining = try await client.getMagicIPPending()
        XCTAssertTrue(remaining.filter { $0.ip == conflict.ip }.isEmpty)

        let choices = try await client.getMagicIPChoices()
        XCTAssertTrue(choices.contains { $0.ip == conflict.ip })
    }

    func testMockClientProbeStream() async {
        let client = MockPantoClient()
        var receivedCount = 0
        for await result in client.streamProbeSites() {
            XCTAssertFalse(result.domain.isEmpty)
            XCTAssertTrue(result.latencyMs == -1 || result.latencyMs > 0)
            receivedCount += 1
        }
        XCTAssertGreaterThan(receivedCount, 0)
    }

    func testIPCPantoClientGracefulFallback() async throws {
        // 当 IPC 会话未就绪时，IPCPantoClient 会优雅回退到内置 mock 数据
        let client = IPCPantoClient { _ in
            throw NSError(domain: "panto.test", code: -1, userInfo: [NSLocalizedDescriptionKey: "VPN Extension Offline"])
        }

        let status = try await client.getStatus()
        XCTAssertTrue(status.running)

        let groups = try await client.getGroups()
        XCTAssertFalse(groups.groups.isEmpty)
    }

    func testMockClientRulesAndMatch() async throws {
        let client = MockPantoClient()
        let rules = try await client.getRules()
        XCTAssertFalse(rules.isEmpty)
        XCTAssertTrue(rules.contains { $0.type == "geoip" && $0.payload == "CN" })

        // 验证域名规则匹配
        let matchProxy = try await client.matchRule(domain: "google.com")
        XCTAssertTrue(matchProxy.matched)
        XCTAssertEqual(matchProxy.target, "⚡ 节点选择 (Proxy)")

        let matchDirect = try await client.matchRule(domain: "apple.com")
        XCTAssertTrue(matchDirect.matched)
        XCTAssertEqual(matchDirect.target, "DIRECT")

        // 验证 IP 规则匹配
        let matchMesh = try await client.matchRule(ip: "100.64.1.5")
        XCTAssertTrue(matchMesh.matched)
        XCTAssertEqual(matchMesh.target, "🌐 Tailscale 网格")
    }

    func testMockClientObservationConsents() async throws {
        let client = MockPantoClient()
        let consents = try await client.getObservationConsents()
        XCTAssertFalse(consents.isEmpty)

        let consent = consents[0]
        let decided = try await client.decideObservationConsent(endpointId: consent.endpointId, allow: true, remember: true)
        XCTAssertTrue(decided)

        let remaining = try await client.getObservationConsents()
        XCTAssertTrue(remaining.filter { $0.endpointId == consent.endpointId }.isEmpty)
    }

    func testModelsOpenAPICodable() throws {
        // 验证 TrafficStats 对齐 OpenAPI 3.0.3 的 upload_total / download_total
        let jsonStr = """
        {
            "upload_total": 1048576,
            "download_total": 2097152,
            "upload_speed": 512,
            "download_speed": 1024
        }
        """
        let data = jsonStr.data(using: .utf8)!
        let stats = try JSONDecoder().decode(TrafficStats.self, from: data)
        XCTAssertEqual(stats.uploadTotal, 1048576)
        XCTAssertEqual(stats.downloadTotal, 2097152)
        XCTAssertEqual(stats.upBytes, 1048576)
        XCTAssertEqual(stats.downBytes, 2097152)
        XCTAssertEqual(stats.upRateBps, 512)
        XCTAssertEqual(stats.downRateBps, 1024)

        // 验证 ModeInfo 兼容 global_exit 与 global_target
        let modeJson = """
        {
            "mode": "global",
            "global_exit": "SG-Node-1"
        }
        """
        let modeData = modeJson.data(using: .utf8)!
        let modeInfo = try JSONDecoder().decode(ModeInfo.self, from: modeData)
        XCTAssertEqual(modeInfo.mode, .global)
        XCTAssertEqual(modeInfo.globalExit, "SG-Node-1")
        XCTAssertEqual(modeInfo.globalTarget, "SG-Node-1")
    }
}
