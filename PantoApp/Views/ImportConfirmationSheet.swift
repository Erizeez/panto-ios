import SwiftUI
import PantoShared

public struct ImportConfirmationPayload: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let sourceURL: String?
    public let rawContent: String
    public let lineCount: Int
    public let byteSize: Int

    public init(name: String, sourceURL: String? = nil, rawContent: String) {
        self.name = name
        self.sourceURL = sourceURL
        self.rawContent = rawContent
        self.lineCount = rawContent.split(separator: "\n").count
        self.byteSize = rawContent.utf8.count
    }
}

public struct ImportConfirmationSheet: View {
    @ObservedObject var appState: AppState
    let payload: ImportConfirmationPayload
    let onConfirm: () -> Void

    @State private var autoStartTunnel: Bool = true
    @Environment(\.dismiss) private var dismiss

    public init(appState: AppState, payload: ImportConfirmationPayload, onConfirm: @escaping () -> Void) {
        self.appState = appState
        self.payload = payload
        self.onConfirm = onConfirm
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 顶部图标与标题
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.top, 10)

                    Text("发现新的 Panto 配置文件")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("通过深度链接接收到配置导入请求，请在确认来源安全后导入。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // 配置元数据卡片
                VStack(spacing: 12) {
                    infoRow(title: "配置名称", value: payload.name, icon: "bookmark.fill")
                    if let source = payload.sourceURL {
                        infoRow(title: "来源地址", value: source, icon: "network")
                    }
                    infoRow(title: "文件体积", value: "\(max(1, payload.byteSize / 1024)) KB", icon: "scalemass.fill")
                    infoRow(title: "规则行数", value: "\(payload.lineCount) 行", icon: "list.number")
                }
                .padding()
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // 启动偏好开关
                Toggle("导入完成后立即激活并启动隧道", isOn: $autoStartTunnel)
                    .font(.footnote)
                    .padding()
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Spacer()

                // 操作按钮
                VStack(spacing: 12) {
                    Button(action: {
                        do {
                            try AppGroupConstants.saveConfig(payload.rawContent)
                            onConfirm()
                            dismiss()
                            if autoStartTunnel && appState.vpn.status != .connected {
                                Task { await appState.toggleTunnel() }
                            }
                        } catch {}
                    }) {
                        Text("确认导入并生效")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
