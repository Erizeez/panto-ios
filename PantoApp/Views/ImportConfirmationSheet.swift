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

    @State private var profileName: String
    @State private var autoStartTunnel: Bool = true
    @State private var errorMessage: String? = nil
    @State private var showingError: Bool = false
    @Environment(\.dismiss) private var dismiss

    public init(appState: AppState, payload: ImportConfirmationPayload, onConfirm: @escaping () -> Void) {
        self.appState = appState
        self.payload = payload
        self.onConfirm = onConfirm
        // 自动计算推荐的无冲突命名
        let suggested = ProfileManager.shared.suggestUniqueName(baseName: payload.name)
        _profileName = State(initialValue: suggested)
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部图标与标题
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 34))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.top, 10)

                        Text("导入配置档案")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("通过局域网投送或外部链接接收到配置，已为您自动生成推荐命名并规避冲突。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // 1. 配置名称设置卡片 (支持编辑修改与推荐重命名)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("档案命名", systemImage: "bookmark.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            if profileName != payload.name {
                                Text("推荐名称（避免同名覆盖）")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }

                        HStack {
                            TextField("输入配置档案名称", text: $profileName)
                                .font(.body)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()

                            if !profileName.isEmpty {
                                Button {
                                    profileName = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // 2. 配置元数据卡片
                    VStack(spacing: 12) {
                        if let source = payload.sourceURL {
                            infoRow(title: "来源地址", value: source, icon: "network")
                        }
                        infoRow(title: "文件体积", value: "\(max(1, payload.byteSize / 1024)) KB", icon: "scalemass.fill")
                        infoRow(title: "配置行数", value: "\(payload.lineCount) 行", icon: "list.number")
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // 3. 启动偏好开关
                    Toggle("导入后立即设为生效并启动隧道", isOn: $autoStartTunnel)
                        .font(.footnote)
                        .padding(14)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    // 操作按钮
                    VStack(spacing: 12) {
                        Button(action: {
                            confirmImport()
                        }) {
                            Text("确认导入并生效")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(profileName.isEmpty ? Color.secondary : Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(profileName.isEmpty)

                        Button("取消") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert(isPresented: $showingError) {
                Alert(title: Text("导入失败"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("好的")))
            }
        }
    }

    private func confirmImport() {
        let cleanName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        do {
            try ProfileManager.shared.saveProfile(
                name: cleanName,
                content: payload.rawContent,
                sourceURL: payload.sourceURL,
                activate: true
            )
            onConfirm()
            dismiss()

            if autoStartTunnel && appState.vpn.status != .connected {
                Task { await appState.toggleTunnel() }
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.showingError = true
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
