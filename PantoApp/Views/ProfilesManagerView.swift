import SwiftUI
import PantoShared

public struct ProfilesManagerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var profiles: [ProfileItem] = []
    @State private var activeProfileId: String? = nil
    @State private var showingFileImporter: Bool = false
    @State private var showingRenameAlert: Bool = false
    @State private var targetProfileToRename: ProfileItem? = nil
    @State private var newProfileName: String = ""
    @State private var alertMessage: String? = nil
    @State private var showingAlert: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        List {
            // 1. 顶部提示与当前运行状态
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "folder.fill.badge.gearshape")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("配置档案库")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("支持多套配置并存与即时热切换，点击即可生效")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // 2. 档案列表
            Section(header: Text("已保存档案 (\(profiles.count))")) {
                if profiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("暂无已导入配置档案")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("请通过局域网投送或点击下方按钮导入")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(profiles) { item in
                        profileRow(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                switchProfile(item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteProfile(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                Button {
                                    startRename(item)
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }

            // 3. 快速添加与导入渠道
            Section(header: Text("添加更多配置")) {
                Button {
                    importFromClipboard()
                } label: {
                    Label("从剪贴板导入配置", systemImage: "doc.on.clipboard")
                }

                Button {
                    showingFileImporter = true
                } label: {
                    Label("从系统文件选取导入", systemImage: "folder")
                }
            }
        }
        .navigationTitle("配置档案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.data, .text, .item]) { result in
            handleFileImport(result)
        }
        .alert("重命名配置档案", isPresented: $showingRenameAlert) {
            TextField("档案名称", text: $newProfileName)
            Button("保存", action: applyRename)
            Button("取消", role: .cancel) {}
        } message: {
            Text("请输入新的配置档案名称")
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("提示"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("好的")))
        }
        .onAppear {
            reloadProfiles()
        }
    }

    private func profileRow(_ item: ProfileItem) -> some View {
        let isActive = item.id == activeProfileId
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: isActive ? "checkmark.circle.fill" : "doc.text.fill")
                    .foregroundColor(isActive ? .green : .secondary)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(isActive ? .bold : .medium)
                        .foregroundColor(.primary)

                    if isActive {
                        Text("当前生效")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text("\(item.nodeCount) 节点")
                    Text("·")
                    Text("\(item.groupCount) 策略组")
                    Text("·")
                    Text("\(max(1, item.byteSize / 1024)) KB")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.subheadline.bold())
            }
        }
        .padding(.vertical, 4)
    }

    private func reloadProfiles() {
        let manifest = ProfileManager.shared.loadManifest()
        self.profiles = manifest.profiles
        self.activeProfileId = manifest.activeProfileId
    }

    private func switchProfile(_ item: ProfileItem) {
        guard item.id != activeProfileId else { return }
        do {
            try ProfileManager.shared.activateProfile(id: item.id)
            reloadProfiles()
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
            appState.reloadLocalProfile()
        } catch {
            showAlert("切换配置失败: \(error.localizedDescription)")
        }
    }

    private func deleteProfile(_ item: ProfileItem) {
        do {
            try ProfileManager.shared.deleteProfile(id: item.id)
            reloadProfiles()
            appState.reloadLocalProfile()
        } catch {
            showAlert("删除失败: \(error.localizedDescription)")
        }
    }

    private func startRename(_ item: ProfileItem) {
        self.targetProfileToRename = item
        self.newProfileName = item.name
        self.showingRenameAlert = true
    }

    private func applyRename() {
        guard let target = targetProfileToRename, !newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        ProfileManager.shared.renameProfile(id: target.id, newName: newProfileName.trimmingCharacters(in: .whitespacesAndNewlines))
        reloadProfiles()
        appState.reloadLocalProfile()
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert("剪贴板中未找到配置内容")
            return
        }
        let suggestedName = ProfileManager.shared.suggestUniqueName(baseName: "剪贴板导入")
        do {
            try ProfileManager.shared.saveProfile(name: suggestedName, content: text, sourceURL: nil, activate: true)
            reloadProfiles()
            appState.reloadLocalProfile()
            showAlert("已成功导入并切换为当前生效配置！")
        } catch {
            showAlert("保存配置失败: \(error.localizedDescription)")
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let baseName = url.deletingPathExtension().lastPathComponent
                let suggestedName = ProfileManager.shared.suggestUniqueName(baseName: baseName)
                do {
                    try ProfileManager.shared.saveProfile(name: suggestedName, content: content, sourceURL: url.lastPathComponent, activate: true)
                    reloadProfiles()
                    appState.reloadLocalProfile()
                    showAlert("成功导入配置文件: \(suggestedName)")
                } catch {
                    showAlert("保存文件失败: \(error.localizedDescription)")
                }
            }
        case .failure(let err):
            showAlert("选取文件失败: \(err.localizedDescription)")
        }
    }

    private func showAlert(_ msg: String) {
        self.alertMessage = msg
        self.showingAlert = true
    }
}
