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

    func testDeepLinkParser() {
        // 1. 测试标准 panto://install-config 远程引用导入
        let pantoURL = URL(string: "panto://install-config?url=http%3A%2F%2F192.168.1.100%3A9090%2Fconfig.yaml&name=SJTU-Campus&token=secret123")!
        let result = DeepLinkParser.parse(pantoURL)
        XCTAssertNotNil(result)
        if case .installConfig(let downloadURL, let name, let token) = result {
            XCTAssertEqual(downloadURL.absoluteString, "http://192.168.1.100:9090/config.yaml")
            XCTAssertEqual(name, "SJTU-Campus")
            XCTAssertEqual(token, "secret123")
        } else {
            XCTFail("Expected .installConfig, got \(String(describing: result))")
        }

        // 2. 测试兼容 clash://install-config 协议
        let clashURL = URL(string: "clash://install-config?url=https%3A%2F%2Fexample.com%2Fsub.yaml&name=ClashSub")!
        let clashResult = DeepLinkParser.parse(clashURL)
        XCTAssertNotNil(clashResult)
        if case .installConfig(let downloadURL, let name, _) = clashResult {
            XCTAssertEqual(downloadURL.absoluteString, "https://example.com/sub.yaml")
            XCTAssertEqual(name, "ClashSub")
        } else {
            XCTFail("Expected .installConfig for clash://")
        }

        // 3. 测试 panto://import?data=... 内联 Base64 数据导入
        let rawYaml = "version: 1.0\nmixed_port: 7890\n"
        let base64 = Data(rawYaml.utf8).base64EncodedString()
        let inlineURL = URL(string: "panto://import?data=\(base64)&name=InlineProfile")!
        let inlineResult = DeepLinkParser.parse(inlineURL)
        XCTAssertNotNil(inlineResult)
        if case .importData(let content, let name) = inlineResult {
            XCTAssertEqual(content, rawYaml)
            XCTAssertEqual(name, "InlineProfile")
        } else {
            XCTFail("Expected .importData")
        }

        // 4. 测试非法 URL 或无关 Scheme
        let invalidURL = URL(string: "https://example.com")!
        XCTAssertNil(DeepLinkParser.parse(invalidURL))
    }

    func testConfigProfileParser() {
        let sampleYaml = """
        version: '1'
        mode: rule
        mixed_port: 7890
        endpoints:
        - id: wan
          kind: direct
        - id: sjtu
          kind: ikev2
          underlay: wan
        - id: corp-tailscale
          kind: tailscale
          underlay: sjtu
        - id: hk-01
          kind: vless
          underlay: wan
        groups:
        - id: Proxy
          kind: select
          members:
          - Auto
          - sjtu
          - corp-tailscale
          - hk-01
        - id: Auto
          kind: url-test
          members:
          - hk-01
        rules:
        - DOMAIN-SUFFIX,ts.net,corp-tailscale
        - IP-CIDR,10.0.0.0/8,corp-tailscale
        - MATCH,Proxy
        """

        let parsed = ConfigProfileParser.parse(yaml: sampleYaml)
        XCTAssertEqual(parsed.mode, .rule)
        XCTAssertEqual(parsed.mixedPort, 7890)
        
        // 验证端点
        XCTAssertEqual(parsed.endpoints.count, 4)
        XCTAssertTrue(parsed.endpoints.contains(where: { $0.id == "sjtu" && $0.kind == "ikev2" }))
        XCTAssertTrue(parsed.endpoints.contains(where: { $0.id == "corp-tailscale" && $0.underlay == "sjtu" }))
        XCTAssertTrue(parsed.endpoints.contains(where: { $0.id == "hk-01" }))

        // 验证策略组
        XCTAssertEqual(parsed.groups.count, 2)
        let proxyGroup = parsed.groups.first(where: { $0.id == "Proxy" })
        XCTAssertNotNil(proxyGroup)
        XCTAssertEqual(proxyGroup?.members.count, 4)
        XCTAssertEqual(proxyGroup?.current, "Auto")

        // 验证规则
        XCTAssertEqual(parsed.rules.count, 3)
        XCTAssertEqual(parsed.rules[0].type, "DOMAIN-SUFFIX")
        XCTAssertEqual(parsed.rules[0].payload, "ts.net")
        XCTAssertEqual(parsed.rules[0].target, "corp-tailscale")
    }

    func testProfileManagerSmartNamingAndActivation() throws {
        let pm = ProfileManager.shared
        
        let yaml1 = "version: '1'\nendpoints:\n- id: node1\n  kind: direct\n"
        let p1 = try pm.saveProfile(name: "SJTU-Campus", content: yaml1, sourceURL: "http://example.com/c1", activate: true)
        XCTAssertEqual(p1.name, "SJTU-Campus")
        XCTAssertEqual(pm.activeProfile()?.id, p1.id)

        // 验证自动推荐不冲突的名称
        let suggested = pm.suggestUniqueName(baseName: "SJTU-Campus")
        XCTAssertEqual(suggested, "SJTU-Campus (2)")

        let yaml2 = "version: '1'\nendpoints:\n- id: node2\n  kind: direct\n"
        let p2 = try pm.saveProfile(name: suggested, content: yaml2, sourceURL: "http://example.com/c2", activate: false)
        XCTAssertEqual(p2.name, "SJTU-Campus (2)")
        // p1 仍然是激活项
        XCTAssertEqual(pm.activeProfile()?.id, p1.id)

        // 切换激活到 p2
        try pm.activateProfile(id: p2.id)
        XCTAssertEqual(pm.activeProfile()?.id, p2.id)

        // 清理测试产生的数据
        try pm.deleteProfile(id: p1.id)
        try pm.deleteProfile(id: p2.id)
    }

    func testPantoAppIconScheduledRotation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func makeDate(hour: Int) -> Date {
            var comps = DateComponents()
            comps.year = 2026
            comps.month = 9
            comps.day = 19
            comps.hour = hour
            comps.minute = 30
            return calendar.date(from: comps)!
        }

        // 1. 00:00 - 08:00 -> Night (暗夜)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 0), calendar: calendar), .night)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 3), calendar: calendar), .night)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 7), calendar: calendar), .night)

        // 2. 08:00 - 16:00 -> Day (白昼)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 8), calendar: calendar), .day)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 12), calendar: calendar), .day)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 15), calendar: calendar), .day)

        // 3. 16:00 - 24:00 -> Twilight (黄昏)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 16), calendar: calendar), .twilight)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 20), calendar: calendar), .twilight)
        XCTAssertEqual(PantoAppIcon.scheduledIcon(for: makeDate(hour: 23), calendar: calendar), .twilight)
    }
}
