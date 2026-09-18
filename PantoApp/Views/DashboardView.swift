import SwiftUI
import NetworkExtension

#if canImport(UIKit)
import UIKit
private extension Color {
    static let cardBackground = Color(UIColor.secondarySystemBackground)
}
#elseif canImport(AppKit)
import AppKit
private extension Color {
    static let cardBackground = Color(NSColor.windowBackgroundColor)
}
#endif

/// DashboardView 是 Panto iOS 客户端的现代化主仪表盘。
public struct DashboardView: View {
    @EnvironmentObject private var vpn: VPNManager
    @EnvironmentObject private var proStore: ProStore
    @State private var showingProSheet = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 商业版 Pro 状态横幅
                    proBannerSection

                    // 2. 核心状态与启动圆环按钮
                    connectionStatusSection

                    // 3. 实时速率与吞吐统计矩阵
                    metricsGridSection

                    // 4. 路由与高级特性入口
                    featuresListSection
                }
                .padding()
            }
            .navigationTitle("PANTO")
            .sheet(isPresented: $showingProSheet) {
                ProUpgradeView()
                    .environmentObject(proStore)
            }
        }
    }

    private var proBannerSection: some View {
        HStack {
            Image(systemName: proStore.isProUnlocked ? "crown.fill" : "crown")
                .foregroundColor(proStore.isProUnlocked ? .yellow : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(proStore.isProUnlocked ? "Panto Pro 终身尊享版" : "Panto 基础免费版")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(proStore.isProUnlocked ? "全功能已解锁 · 多层隧道嵌套无限制" : "解锁 Underlay Chain 多层嵌套与高级调度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !proStore.isProUnlocked {
                Button(action: { showingProSheet = true }) {
                    Text("升级")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            Button(action: toggleConnection) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(statusColor)
                        .frame(width: 100, height: 100)
                        .shadow(color: statusColor.opacity(0.4), radius: 10, x: 0, y: 5)
                    Image(systemName: "power")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.bold)
                if vpn.status == .connected {
                    Text("在线时长: \(formatUptime(vpn.currentUptime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var metricsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(title: "下行速率", value: formatBytes(vpn.downRate) + "/s", icon: "arrow.down.circle.fill", color: .blue)
            metricCard(title: "上行速率", value: formatBytes(vpn.upRate) + "/s", icon: "arrow.up.circle.fill", color: .green)
            metricCard(title: "活跃拓扑节点", value: "\(vpn.activeEndpointsCount) 个", icon: "point.3.filled.connected.trianglepath.dotted", color: .purple)
            metricCard(title: "运行模式", value: "规则分流 (Rule)", icon: "arrow.triangle.branch", color: .orange)
        }
    }

    private var featuresListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("编排管理")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                navigationRow(icon: "network", title: "Underlay 链路拓扑", subtitle: "管理多层隧道嵌套与 DAG")
                navigationRow(icon: "slider.horizontal.3", title: "策略调度器", subtitle: "K8s 纯函数 Filter-Score-Pick")
                navigationRow(icon: "doc.text", title: "声明式配置", subtitle: "YAML 文件查看与本地导入")
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private func navigationRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 32)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var statusColor: Color {
        switch vpn.status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        case .disconnecting: return .red
        default: return .gray
        }
    }

    private var statusText: String {
        switch vpn.status {
        case .connected: return "已连接"
        case .connecting: return "正在连接..."
        case .disconnecting: return "正在断开..."
        case .reasserting: return "重新连接中..."
        default: return "未连接"
        }
    }

    private func toggleConnection() {
        if vpn.status == .connected {
            vpn.stopTunnel()
        } else {
            Task {
                try? await vpn.startTunnel()
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        return String(format: "%.2f MB", mb)
    }

    private func formatUptime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        let h = m / 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m % 60, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

/// ProUpgradeView 是商业化一次性买断弹窗界面。
struct ProUpgradeView: View {
    @EnvironmentObject private var proStore: ProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding(.top, 40)

                Text("解锁 Panto Pro 终身版")
                    .font(.title)
                    .fontWeight(.bold)

                Text("一次性购买，永久拥有。支持家庭共享，免去循环订阅烦恼。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    featureBenefit(icon: "square.stack.3d.up.fill", title: "多层 Underlay Chain 嵌套", desc: "任意编排 Tailscale over IKEv2 等复杂拓扑")
                    featureBenefit(icon: "cpu.fill", title: "K8s 纯函数高级调度", desc: "享受毫秒级自适应 Filter 与 Score 路由优选")
                    featureBenefit(icon: "icloud.fill", title: "iCloud 跨设备加密漫游", desc: "配置文件在多台 iOS / Mac 设备间安全同步")
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(16)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            let ok = await proStore.purchaseLifetimePro()
                            if ok { dismiss() }
                        }
                    }) {
                        HStack {
                            if proStore.isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(proStore.lifetimeProduct != nil ? "立即买断 · \(proStore.lifetimeProduct!.displayPrice)" : "立即买断 Pro")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    Button("恢复已购买项目") {
                        Task {
                            await proStore.restorePurchases()
                            if proStore.isProUnlocked { dismiss() }
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func featureBenefit(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
