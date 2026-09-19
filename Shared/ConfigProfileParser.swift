import Foundation

/// Panto 真实配置文件解析器（支持标准 Panto Schema YAML / JSON 格式）
/// 无外部第三方依赖，纯 Swift 零开销解析端点拓扑、策略组、规则集
public enum ConfigProfileParser {

    public struct ParsedProfile: Sendable {
        public let mode: TunnelMode
        public let endpoints: [TopologyNodeItem]
        public let groups: [GroupItem]
        public let rules: [RuleItem]
        public let mixedPort: Int
    }

    public static func parse(yaml: String) -> ParsedProfile {
        let lines = yaml.components(separatedBy: .newlines)
        
        var currentSection: String = ""
        var rawEndpoints: [[String: String]] = []
        var currentEndpoint: [String: String] = [:]
        
        var rawGroups: [(id: String, kind: String, members: [String])] = []
        var currentGroupId: String = ""
        var currentGroupKind: String = "select"
        var currentGroupMembers: [String] = []
        var inGroupMembers: Bool = false
        
        var rawRules: [RuleItem] = []
        var mixedPort: Int = 7890
        var detectedMode: TunnelMode = .rule

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            // 顶层键识别 (排除以 - 开头的列表元素)
            if !rawLine.hasPrefix(" ") && !rawLine.hasPrefix("\t") && !line.hasPrefix("-") && line.contains(":") {
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                let key = parts[0]
                let val = parts.count > 1 ? parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "'\" ")) : ""

                if key == "endpoints" || key == "proxies" {
                    currentSection = "endpoints"
                    continue
                } else if key == "groups" || key == "proxy-groups" {
                    // 结算最后一个 endpoint
                    if !currentEndpoint.isEmpty {
                        rawEndpoints.append(currentEndpoint)
                        currentEndpoint = [:]
                    }
                    currentSection = "groups"
                    continue
                } else if key == "rules" {
                    // 结算最后一个 group
                    if !currentGroupId.isEmpty {
                        rawGroups.append((id: currentGroupId, kind: currentGroupKind, members: currentGroupMembers))
                        currentGroupId = ""
                        currentGroupMembers = []
                    }
                    currentSection = "rules"
                    continue
                } else {
                    currentSection = "root"
                    if key == "mixed_port" || key == "mixed-port" || key == "port" {
                        mixedPort = Int(val) ?? 7890
                    } else if key == "mode" {
                        detectedMode = TunnelMode(rawValue: val.lowercased()) ?? .rule
                    }
                }
            }

            // 处理各 Section 内容
            switch currentSection {
            case "endpoints":
                if line.hasPrefix("- ") {
                    if !currentEndpoint.isEmpty {
                        rawEndpoints.append(currentEndpoint)
                        currentEndpoint = [:]
                    }
                    let sub = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                    parseKeyValue(sub, into: &currentEndpoint)
                } else {
                    parseKeyValue(line, into: &currentEndpoint)
                }

            case "groups":
                if line.hasPrefix("- id:") || line.hasPrefix("- name:") {
                    if !currentGroupId.isEmpty {
                        rawGroups.append((id: currentGroupId, kind: currentGroupKind, members: currentGroupMembers))
                        currentGroupId = ""
                        currentGroupMembers = []
                    }
                    inGroupMembers = false
                    let parts = line.dropFirst(2).split(separator: ":", maxSplits: 1)
                    if parts.count > 1 {
                        currentGroupId = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
                    }
                } else if line.hasPrefix("kind:") || line.hasPrefix("type:") {
                    let parts = line.split(separator: ":", maxSplits: 1)
                    if parts.count > 1 {
                        currentGroupKind = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
                    }
                } else if line.hasPrefix("members:") || line.hasPrefix("proxies:") {
                    inGroupMembers = true
                } else if inGroupMembers && line.hasPrefix("- ") {
                    let member = String(line.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
                    if !member.isEmpty {
                        currentGroupMembers.append(member)
                    }
                }

            case "rules":
                let ruleStr = line.hasPrefix("- ") ? String(line.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "'\" ")) : line
                let segs = ruleStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                if segs.count >= 3 {
                    rawRules.append(RuleItem(
                        type: segs[0].uppercased(),
                        payload: segs[1],
                        target: segs[2]
                    ))
                } else if segs.count == 2 {
                    rawRules.append(RuleItem(
                        type: segs[0].uppercased(),
                        payload: "",
                        target: segs[1]
                    ))
                }

            default:
                break
            }
        }

        // 结算未入栈的尾部条目
        if !currentEndpoint.isEmpty {
            rawEndpoints.append(currentEndpoint)
        }
        if !currentGroupId.isEmpty {
            rawGroups.append((id: currentGroupId, kind: currentGroupKind, members: currentGroupMembers))
        }

        // 构造 Topology 节点列表
        var nodes: [TopologyNodeItem] = []
        // 保证 DIRECT / WAN 顶层根节点存在
        var hasDirect = false
        for ep in rawEndpoints {
            let id = ep["id"] ?? ep["name"] ?? "node"
            let kind = ep["kind"] ?? ep["type"] ?? "unknown"
            let underlay = ep["underlay"]
            if id.uppercased() == "DIRECT" || id.uppercased() == "WAN" {
                hasDirect = true
            }
            nodes.append(TopologyNodeItem(
                id: id,
                kind: kind,
                underlay: underlay,
                effectiveMtu: 1420,
                overhead: 80,
                dependents: [],
                path: underlay != nil ? [underlay!, id] : [id]
            ))
        }
        if !hasDirect {
            nodes.insert(TopologyNodeItem(
                id: "DIRECT",
                kind: "direct",
                underlay: nil,
                effectiveMtu: 1500,
                overhead: 0,
                dependents: [],
                path: ["DIRECT"]
            ), at: 0)
        }

        // 构造 GroupItem 列表
        var finalGroups: [GroupItem] = []
        for g in rawGroups {
            let currentChoice = g.members.first ?? "DIRECT"
            var initialDelays: [String: Int] = [:]
            for m in g.members {
                if m.uppercased() == "DIRECT" {
                    initialDelays[m] = 5
                }
            }
            finalGroups.append(GroupItem(
                id: g.id,
                kind: g.kind,
                members: g.members,
                current: currentChoice,
                delays: initialDelays
            ))
        }

        return ParsedProfile(
            mode: detectedMode,
            endpoints: nodes,
            groups: finalGroups,
            rules: rawRules,
            mixedPort: mixedPort
        )
    }

    private static func parseKeyValue(_ line: String, into dict: inout [String: String]) {
        guard line.contains(":") else { return }
        let parts = line.split(separator: ":", maxSplits: 1)
        let k = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let v = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "'\" ")) : ""
        if !k.isEmpty && !v.isEmpty {
            dict[k] = v
        }
    }
}
