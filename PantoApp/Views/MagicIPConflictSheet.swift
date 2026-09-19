import SwiftUI
import PantoShared

public struct MagicIPConflictSheet: View {
    @ObservedObject var appState: AppState
    let conflict: MagicIPConflictItem

    @State private var selectedEndpoint: String
    @State private var rememberChoice: Bool = true
    @Environment(\.dismiss) private var dismiss

    public init(appState: AppState, conflict: MagicIPConflictItem) {
        self.appState = appState
        self.conflict = conflict
        _selectedEndpoint = State(initialValue: conflict.lastUsedEndpoint)
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 顶部警告卡片
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text("Tailscale Magic IP 冲突")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("多个 Tailnet 设备声明了相同虚拟 IP 地址。请指定数据包的首选下一跳目的地。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // 冲突 IP 标签
                HStack {
                    Text("冲突地址:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(conflict.ip)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }

                // 候选设备列表
                VStack(alignment: .leading, spacing: 10) {
                    Text("候选目的端点 (按优先级排序)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)

                    ForEach(conflict.candidates, id: \.endpointId) { candidate in
                        candidateRow(candidate)
                    }
                }
                .padding(.horizontal)

                // 偏好记忆开关
                Toggle("记住对此 IP 的路由裁决，下次自动优先转发", isOn: $rememberChoice)
                    .font(.footnote)
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Spacer()

                // 确认决策按钮
                Button(action: {
                    Task {
                        await appState.resolveMagicIP(
                            ip: conflict.ip,
                            endpoint: selectedEndpoint,
                            remember: rememberChoice
                        )
                        dismiss()
                    }
                }) {
                    Text("确认路由裁决")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后处理") { dismiss() }
                }
            }
        }
    }

    private func candidateRow(_ candidate: MagicIPCandidate) -> some View {
        Button(action: {
            selectedEndpoint = candidate.hostname
        }) {
            HStack(spacing: 12) {
                Image(systemName: selectedEndpoint == candidate.hostname ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedEndpoint == candidate.hostname ? .accentColor : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(candidate.hostname)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        if candidate.online {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    if let dns = candidate.dnsName {
                        Text(dns)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("权重: \(candidate.priority)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding()
            .background(selectedEndpoint == candidate.hostname ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedEndpoint == candidate.hostname ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
