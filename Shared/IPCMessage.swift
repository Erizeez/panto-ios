import Foundation

/// IPCRequest 是主应用向 Network Extension 发送的强类型控制指令。
public struct IPCRequest: Codable {
    public let action: String
    public let payload: Data?

    public init(action: String, payload: Data? = nil) {
        self.action = action
        self.payload = payload
    }

    public static func ping() -> IPCRequest {
        return IPCRequest(action: "ping")
    }

    public static func status() -> IPCRequest {
        return IPCRequest(action: "status")
    }

    public static func traffic() -> IPCRequest {
        return IPCRequest(action: "traffic")
    }

    public static func groups() -> IPCRequest {
        return IPCRequest(action: "groups")
    }

    public static func selectGroup(group: String, selected: String) -> IPCRequest? {
        let dict = ["group": group, "selected": selected]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return IPCRequest(action: "select-group", payload: data)
    }

    public static func setMode(mode: String, globalExit: String? = nil, globalTarget: String? = nil) -> IPCRequest? {
        var dict: [String: Any] = ["mode": mode]
        let exit = globalExit ?? globalTarget
        if let exit = exit {
            dict["global_exit"] = exit
            dict["global_target"] = exit
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return IPCRequest(action: "mode", payload: data)
    }

    public static func rules() -> IPCRequest {
        return IPCRequest(action: "rules")
    }

    public static func matchRule(domain: String? = nil, ip: String? = nil, port: Int? = nil, network: String? = nil) -> IPCRequest? {
        var dict: [String: Any] = [:]
        if let domain = domain { dict["domain"] = domain }
        if let ip = ip { dict["ip"] = ip }
        if let port = port { dict["port"] = port }
        if let network = network { dict["network"] = network }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return IPCRequest(action: "match-rule", payload: data)
    }

    public static func observationConsents() -> IPCRequest {
        return IPCRequest(action: "observation-consents")
    }

    public static func decideObservationConsent(endpointId: String, allow: Bool, remember: Bool) -> IPCRequest? {
        let dict: [String: Any] = [
            "endpoint_id": endpointId,
            "allow": allow,
            "remember": remember
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return IPCRequest(action: "observation-consent-decide", payload: data)
    }
}

/// IPCResponse 是 Network Extension 回复主应用的通用响应结构。
public struct IPCResponse: Codable {
    public let success: Bool
    public let data: Data?
    public let error: String?

    public init(success: Bool, data: Data? = nil, error: String? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}

/// StatusPayload 映射 Panto 引擎的实时运行状态。
public struct StatusPayload: Codable {
    public let running: Bool
    public let uptimeSeconds: Int
    public let activeEndpoints: Int
    public let activeGroups: Int
    public let activeRules: Int
    public let mode: String?
    public let globalTarget: String?

    enum CodingKeys: String, CodingKey {
        case running
        case uptimeSeconds = "uptime_seconds"
        case activeEndpoints = "active_endpoints"
        case activeGroups = "active_groups"
        case activeRules = "active_rules"
        case mode
        case globalTarget = "global_target"
    }
}

/// TrafficPayload 映射 Panto 引擎的实时吞吐与速率统计。
public struct TrafficPayload: Codable {
    public let upBytes: Int64
    public let downBytes: Int64
    public let upRate: Int64
    public let downRate: Int64

    enum CodingKeys: String, CodingKey {
        case upBytes = "up_bytes"
        case downBytes = "down_bytes"
        case upRate = "up_rate"
        case downRate = "down_rate"
    }
}
