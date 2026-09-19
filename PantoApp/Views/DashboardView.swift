import SwiftUI
import NetworkExtension
import PantoShared

public struct DashboardView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var proStore: ProStore
    @State private var showingProSheet = false
    @State private var isCollapsed = true
    @Namespace private var modeAnimationNamespace

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. 顶部控制舱 (可折叠大标题栏 + 伴随舒适大按钮 + 48pt 黄金触控大尺寸模式切换舱)
                headerControlConsole

                ScrollView {
                    VStack(spacing: 14) {
                        // 顶部滚动位置探测器
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: proxy.frame(in: .named("DashboardScrollSpace")).minY
                            )
                        }
                        .frame(height: 0)

                        // 2. 链路概况信息横条 (运行时长 + 虚拟 IP)
                        statusSummaryStrip

                        // 3. 上下行速率监控组件 (4px 标准正方形点阵)
                        TrafficChartView(
                            history: appState.trafficHistory,
                            upRate: appState.currentUpRate,
                            downRate: appState.currentDownRate
                        )

                        // 4. 核心指标卡片矩阵
                        metricsGridSection

                        // 5. Pro 买断会员入口
                        if !proStore.isProUnlocked {
                            proBannerSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "DashboardScrollSpace")
                .onPreferenceChange(ScrollOffsetKey.self) { minY in
                    let collapsed = minY < -16
                    if collapsed != isCollapsed {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isCollapsed = collapsed
                        }
                    }
                }
            }
            .navigationBarHidden(true) // 隐藏系统空旷单占一行的导航栏
            .sheet(isPresented: $appState.showingConflictSheet) {
                if let conflict = appState.selectedConflict {
                    MagicIPConflictSheet(appState: appState, conflict: conflict)
                }
            }
            .sheet(isPresented: $showingProSheet) {
                ProUpgradeView()
                    .environmentObject(proStore)
            }
            .sheet(isPresented: $appState.showingVirtualInterfacesSheet) {
                VirtualInterfacesSheet(appState: appState)
            }
        }
    }

    // MARK: - 1. 顶部控制舱 (Header Control Console - 大标题动态伸缩、大触摸靶心模式控制舱)

    private var headerControlConsole: some View {
        VStack(spacing: isCollapsed ? 8 : 14) {
            // A. 第一行：品牌标题栏 (顶部时为饱满大标题，向上滑动或轻触时平滑收缩紧凑)
            HStack(alignment: .center) {
                if isCollapsed {
                    // 收缩态：紧凑横向单行
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: statusColor.opacity(isConnected ? 0.9 : 0.0), radius: 3)

                        Text("PANTO")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.primary)

                        Text("·")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.5))

                        Text(statusSummaryText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isCollapsed.toggle()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // 默认展开态：大标题行，大气开阔，纵向更具呼吸感
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PANTO")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.primary)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: statusColor.opacity(isConnected ? 0.9 : 0.0), radius: 4)

                            Text(statusSummaryText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isCollapsed.toggle()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                }

                Spacer(minLength: 8)

                // 右侧伴随控制按钮组 (统一高度 40pt，大圆角胶囊)
                HStack(spacing: 8) {
                    if !appState.magicConflicts.isEmpty {
                        conflictNoticeButton
                    }
                    comfortablePowerButton
                }
            }

            // B. 第二行：48pt 黄金触控高度大模式切换舱 (核心高频操作，极易触达，带苹果悬浮滑块弹簧动画)
            modeSelectorSection
        }
        .padding(.horizontal, 16)
        .padding(.top, isCollapsed ? 8 : 14)
        .padding(.bottom, isCollapsed ? 8 : 12)
        .background(.ultraThinMaterial)
        .overlay(
            Divider()
                .opacity(isCollapsed ? 0.45 : 0.15),
            alignment: .bottom
        )
    }

    /// 舒适大尺寸主电源控制按钮 (采用苹果官方原生样式 .buttonStyle(.bordered / .borderedProminent))
    private var comfortablePowerButton: some View {
        Button(action: {
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
            Task {
                await appState.toggleTunnel()
            }
        }) {
            HStack(spacing: 6) {
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .bold))
                }

                Text(statusButtonLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .appleNativeButtonStyle(isProminent: isConnected)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .tint(isConnected ? .green : (isConnecting ? .orange : .accentColor))
    }

    /// 舒适大尺寸冲突提醒按钮 (采用苹果官方原生样式)
    private var conflictNoticeButton: some View {
        Button(action: {
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
            appState.selectedConflict = appState.magicConflicts.first
            appState.showingConflictSheet = true
        }) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(String(format: "%d 冲突".localized, appState.magicConflicts.count))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .tint(.orange)
        .transition(.scale.combined(with: .opacity))
    }

    /// 苹果官方原生分段选择器 (100% 原生 UISegmentedControl，原生支持点击拖动跟随手势，半圆 Capsule 预设)
    private var modeSelectorSection: some View {
        Picker("运行模式".localized, selection: Binding(
            get: { appState.currentMode },
            set: { newMode in
                Task {
                    await appState.switchMode(newMode)
                }
            }
        )) {
            ForEach(TunnelMode.allCases, id: \.self) { mode in
                Text(mode.displayName.localized)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .clipShape(Capsule())
    }

    // MARK: - 2. Sections

    /// 紧凑状态概览横条 (点击展示多虚拟网络接口清单)
    private var statusSummaryStrip: some View {
        Button(action: {
            #if canImport(UIKit)
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
            #endif
            appState.showingVirtualInterfacesSheet = true
        }) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(String(format: "持续 %@".localized, formatUptime(appState.systemStatus?.uptimeSeconds ?? appState.vpn.currentUptime)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 优先展示 Tailscale 等 Mesh IP，并带交互指示
                HStack(spacing: 5) {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                    Text(appState.systemStatus?.primaryVirtualIp ?? "10.201.0.2")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// 核心指标卡片 (包含可点击的多虚拟网络接口卡片)
    private var metricsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(
                title: "活跃拓扑节点".localized,
                value: String(format: "%d 个".localized, appState.systemStatus?.activeEndpoints ?? 14),
                icon: "point.3.filled.connected.trianglepath.dotted",
                color: .purple
            )
            metricCard(
                title: "分流匹配规则".localized,
                value: String(format: "%d 条".localized, appState.systemStatus?.activeRules ?? 128),
                icon: "list.bullet.rectangle.portrait",
                color: .blue
            )

            // 可点击的多虚拟网络接口卡片
            Button(action: {
                #if canImport(UIKit)
                let feedback = UISelectionFeedbackGenerator()
                feedback.selectionChanged()
                #endif
                appState.showingVirtualInterfacesSheet = true
            }) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "network.badge.shield.half.filled")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("虚拟网络接口".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    Text(appState.systemStatus?.primaryVirtualIp ?? "10.201.0.2")
                        .font(.headline)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 5, height: 5)
                        Text(String(format: "%d 个接口就绪".localized, appState.systemStatus?.virtualInterfaces?.count ?? 3))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            metricCard(
                title: "看门狗内存".localized,
                value: "< 9.5 MB",
                icon: "shield.lefthalf.filled",
                color: .teal
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    /// Pro 升级卡片
    private var proBannerSection: some View {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Panto Pro 终身尊享版".localized)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("解锁 Underlay Chain 无限制嵌套与自适应链路调度".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showingProSheet = true }) {
                Text("升级".localized)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 3, y: 1)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - State Helpers

    private var isConnected: Bool {
        appState.vpn.status == .connected
    }

    private var isConnecting: Bool {
        appState.vpn.status == .connecting || appState.vpn.status == .reasserting
    }

    private var statusColor: Color {
        switch appState.vpn.status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        case .disconnecting: return .red
        default: return .secondary
        }
    }

    private var statusButtonLabel: String {
        switch appState.vpn.status {
        case .connected: return "已连接".localized
        case .connecting: return "连接中".localized
        case .disconnecting: return "断开中".localized
        case .reasserting: return "重连中".localized
        default: return "连接".localized
        }
    }

    private var statusSummaryText: String {
        switch appState.vpn.status {
        case .connected: return "隧道接管中".localized
        case .connecting: return "正在建立连接...".localized
        case .disconnecting: return "正在断开...".localized
        case .reasserting: return "网络切换重连中...".localized
        default: return "隧道未连接".localized
        }
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

extension View {
    @ViewBuilder
    fileprivate func appleNativeButtonStyle(isProminent: Bool) -> some View {
        if isProminent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
