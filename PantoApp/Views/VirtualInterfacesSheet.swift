import SwiftUI
import PantoShared
#if canImport(UIKit)
import UIKit
#endif

/// VirtualInterfacesSheet 展示本机当前持有的所有虚拟网络接口与多网资产 (Tailscale、Underlay VPN、本地 utun)。
public struct VirtualInterfacesSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var copiedIp: String? = nil

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. 架构说明提示卡片
                    explanationBanner

                    // 2. 虚拟接口清单
                    if let interfaces = appState.systemStatus?.virtualInterfaces, !interfaces.isEmpty {
                        VStack(spacing: 14) {
                            ForEach(interfaces) { item in
                                interfaceCard(item)
                            }
                        }
                    } else {
                        fallbackSingleInterfaceCard
                    }

                    // 3. 底部原理解析
                    technicalNoteCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            #if os(iOS)
            .background(Color(uiColor: .systemGroupedBackground))
            #else
            .background(Color.secondary.opacity(0.1))
            #endif
            .navigationTitle("虚拟网络接口".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成".localized) {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }

    // MARK: - Components

    private var explanationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.system(size: 26))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text("多网络接口融合架构".localized)
                    .font(.system(size: 15, weight: .bold))
                Text("在 iOS 单一 VPN 槽位限制下，Panto 在用户态同时融合 Tailscale Mesh、多 Underlay 节点与本地 TUN。".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func interfaceCard(_ item: VirtualInterfaceItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：类型徽标 + 接口名称 + 标签
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: item.type.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(typeColor(item.type))

                    Text(item.name)
                        .font(.system(size: 15, weight: .bold))
                }

                Spacer()

                Text(item.type.displayName.localized)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(typeColor(item.type).opacity(0.12))
                    .foregroundColor(typeColor(item.type))
                    .clipShape(Capsule())
            }

            Divider().opacity(0.4)

            // IPv4 地址行
            VStack(alignment: .leading, spacing: 6) {
                Text("IPv4 虚拟地址".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Text(item.ipv4)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    Spacer()

                    copyButton(ip: item.ipv4)
                }
            }

            // IPv6 地址行 (若存在)
            if let ipv6 = item.ipv6 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IPv6 虚拟地址".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(ipv6)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        copyButton(ip: ipv6, isCompact: true)
                    }
                }
            }

            // 子网与功能说明
            VStack(alignment: .leading, spacing: 4) {
                if let mask = item.subnetMask {
                    HStack(spacing: 4) {
                        Text("子网段 / 掩码:".localized)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(mask)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Text(item.descriptionText.localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(item.isPrimaryMesh ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: item.isPrimaryMesh ? 1.5 : 1)
        )
    }

    private var fallbackSingleInterfaceCard: some View {
        let ip = appState.systemStatus?.assignedIp ?? "10.201.0.2"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.green)
                Text("iOS 系统网卡 (utun)".localized)
                    .font(.headline)
                Spacer()
                Text("系统网卡".localized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            }

            Text(ip)
                .font(.system(size: 20, weight: .bold, design: .monospaced))

            Text("iOS NetworkExtension 分配的唯一系统虚拟接口。".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func copyButton(ip: String, isCompact: Bool = false) -> some View {
        let isCopied = copiedIp == ip
        return Button(action: {
            #if canImport(UIKit)
            UIPasteboard.general.string = ip
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedIp = ip
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    if copiedIp == ip { copiedIp = nil }
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                Text(isCopied ? "已复制".localized : "复制".localized)
                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
            }
            .padding(.horizontal, isCompact ? 8 : 10)
            .padding(.vertical, isCompact ? 4 : 5)
            .background(isCopied ? Color.green : Color.secondary.opacity(0.12))
            .foregroundColor(isCopied ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var technicalNoteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("为什么在设置中只能看到一个 VPN？".localized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Text("Apple iOS 操作系统对所有第三方网络工具执行单一 TUN 网卡策略。Panto 在这单个系统网卡底层构建了高性能用户态路由栈，使得 Tailscale 节点互访与多云节点互联可以在同一个 App 内并发运行，无需在系统设置中反复切换。".localized)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary.opacity(0.8))
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func typeColor(_ type: VirtualInterfaceItem.InterfaceType) -> Color {
        switch type {
        case .tailscale: return .blue
        case .underlay: return .purple
        case .utun: return .green
        }
    }
}
