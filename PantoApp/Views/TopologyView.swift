import SwiftUI
import PantoShared

public struct TopologyView: View {
    @ObservedObject var appState: AppState
    @State private var selectedNode: TopologyNodeItem? = nil

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 架构说明横幅
                    headerBanner

                    // 节点拓扑列表 / 依赖链路
                    if let topo = appState.topology, !topo.nodes.isEmpty {
                        VStack(spacing: 16) {
                            ForEach(topo.nodes) { node in
                                nodeCard(node)
                            }
                        }
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("链路拓扑 (DAG)")
            .sheet(item: $selectedNode) { node in
                nodeDetailSheet(node)
            }
        }
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text("Underlay Chain 多层嵌套")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("单 VPN 槽位下透明编排 IKEv2、Tailscale 与代理隧道，按层展开线性链。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func nodeCard(_ node: TopologyNodeItem) -> some View {
        Button(action: {
            selectedNode = node
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    protocolIcon(for: node.kind)
                    Text(node.id)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    // MTU 损耗指示
                    HStack(spacing: 4) {
                        Text("MTU: \(node.effectiveMtu)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        if node.overhead > 0 {
                            Text("(-\(node.overhead))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }

                // 依赖链路指示
                if !node.path.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(node.path.enumerated()), id: \.offset) { index, step in
                            Text(step)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(index == node.path.count - 1 ? .accentColor : .secondary)

                            if index < node.path.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                // MTU 阶梯条形指示
                GeometryReader { geo in
                    let ratio = CGFloat(node.effectiveMtu) / 1500.0
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 4)
                        Capsule()
                            .fill(node.overhead > 0 ? Color.orange : Color.green)
                            .frame(width: max(20, geo.size.width * ratio), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func protocolIcon(for kind: String) -> some View {
        let (icon, color): (String, Color) = {
            switch kind.lowercased() {
            case "direct": return ("arrow.up.forward.app.fill", .green)
            case "ikev2": return ("lock.shield.fill", .blue)
            case "tailscale": return ("circle.grid.3x3.fill", .purple)
            case "wireguard": return ("network", .indigo)
            case "shadowsocks": return ("paperplane.fill", .orange)
            default: return ("point.3.connected.trianglepath.dotted", .accentColor)
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundColor(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("未获取到链路拓扑")
                .font(.headline)
            Text("连接隧道或刷新以查看当前 DAG 依赖链")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    private func nodeDetailSheet(_ node: TopologyNodeItem) -> some View {
        NavigationView {
            List {
                Section("基础元数据") {
                    labeledRow("节点标识 (ID)", value: node.id)
                    labeledRow("协议类型 (Kind)", value: node.kind.uppercased())
                    labeledRow("底层依赖 (Underlay)", value: node.underlay ?? "无 (物理直出)")
                }

                Section("MTU 与协议损耗") {
                    labeledRow("生效 MTU", value: "\(node.effectiveMtu) 字节")
                    labeledRow("协议开销 (Overhead)", value: "+\(node.overhead) 字节")
                }

                Section("完整出站路径链") {
                    ForEach(Array(node.path.enumerated()), id: \.offset) { index, step in
                        HStack {
                            Text("跳 \(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 32, alignment: .leading)
                            Text(step)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle(node.id)
        }
    }

    private func labeledRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
