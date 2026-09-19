import SwiftUI
import PantoShared

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject private var proStore: ProStore
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var iconManager = AppIconManager.shared
    @State private var showingProSheet = false
    @State private var hasConfig: Bool = AppGroupConstants.hasActiveConfig
    @State private var configSummary: String? = nil
    @State private var showingFileImporter: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showingAlert: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationView {
            List {
                // 1. 语言与偏好设置
                Section("语言".localized) {
                    Picker("应用语言".localized, selection: $languageManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName.localized)
                                .tag(lang)
                        }
                    }
                }

                // 1.5 应用图标与时段轮换
                Section {
                    Toggle("按时段自动轮换 (每 8 小时)".localized, isOn: $iconManager.autoRotateEnabled)

                    HStack(spacing: 12) {
                        ForEach(PantoAppIcon.allCases) { icon in
                            let isCurrent = iconManager.currentActiveIcon == icon
                            let isScheduled = iconManager.currentScheduledIcon == icon

                            Button {
                                #if canImport(UIKit)
                                let feedback = UIImpactFeedbackGenerator(style: .light)
                                feedback.impactOccurred()
                                #endif
                                iconManager.applyIcon(icon)
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(icon.previewImageName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 58, height: 58)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(isCurrent ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isCurrent ? 2.5 : 1)
                                            )
                                            .shadow(color: isCurrent ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4, y: 2)

                                        if isCurrent {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.accentColor)
                                                .background(Circle().fill(Color.white))
                                                .offset(x: 4, y: -4)
                                        }
                                    }

                                    Text(icon.displayName)
                                        .font(.system(size: 11, weight: isCurrent ? .bold : .medium))
                                        .foregroundColor(isCurrent ? .primary : .secondary)

                                    Text(icon.timeRangeDescription)
                                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                                        .foregroundColor(.secondary)

                                    if isScheduled {
                                        Text("当前时段".localized)
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundColor(.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("应用图标与 8 小时轮换".localized)
                } footer: {
                    Text("根据时间划分为 3 个 8 小时时段：08:00-16:00 (白昼)、16:00-24:00 (黄昏)、00:00-08:00 (暗夜)。开启自动轮换后，App 将在对应时段自动无缝切换图标。".localized)
                }

                // 2. 配置文件与节点规则
                Section("配置文件与节点规则".localized) {
                    NavigationLink {
                        ProfilesManagerView(appState: appState)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "folder.fill.badge.gearshape")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("配置档案库".localized)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Text(currentProfileText)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            let profileCount = ProfileManager.shared.loadManifest().profiles.count
                            Text(String(format: "%d 套档案".localized, profileCount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    Button {
                        importFromClipboard()
                    } label: {
                        Label("从剪贴板导入 YAML 配置".localized, systemImage: "doc.on.clipboard")
                    }

                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("从系统文件选取导入".localized, systemImage: "folder")
                    }
                }

                // 3. Pro 商业版状态
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "crown.fill")
                            .font(.title)
                            .foregroundColor(proStore.isProUnlocked ? .yellow : .secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(proStore.isProUnlocked ? "Panto Pro 终身尊享版".localized : "Panto 基础开源版".localized)
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(proStore.isProUnlocked ? "全功能已解锁 · 无限制 Underlay 嵌套".localized : "支持买断升级，支持家庭共享".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !proStore.isProUnlocked {
                            Button("升级".localized) {
                                showingProSheet = true
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 3. 调试与模拟器模式开关
                Section("开发者与调试选项".localized) {
                    Toggle(isOn: $appState.useMockMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("启用脱机模拟客户端 (Mock Mode)".localized)
                                .font(.body)
                            Text("在底层内核未编译或无 VPN 权限时使用高保真模拟数据".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("手动刷新所有状态".localized) {
                        Task { await appState.refreshAll() }
                    }
                }

                // 4. 运行环境诊断
                Section("系统环境与内核底座".localized) {
                    labeledRow("核心版本".localized, value: "Panto v2.4.0")
                    labeledRow("数据面架构".localized, value: "Rust 0-alloc / L3 Direct")
                    labeledRow("App Group".localized, value: AppGroupConstants.appGroupID)
                    labeledRow("Extension ID".localized, value: AppGroupConstants.extensionBundleID)
                }

                // 5. 法律合规与开源协议
                Section("合规与开源协议".localized) {
                    Text("Panto 客户端遵循双进程物理隔离与 IPC 防火墙架构：主应用独立专有，Network Extension 遵循 GPL-3.0 with App Store Exception，保障合规与用户隐私。".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置与诊断".localized)
            .sheet(isPresented: $showingProSheet) {
                ProUpgradeView()
                    .environmentObject(proStore)
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.data, .text, .item]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        do {
                            let baseName = url.deletingPathExtension().lastPathComponent
                            let suggestedName = ProfileManager.shared.suggestUniqueName(baseName: baseName.isEmpty ? "文件导入" : baseName)
                            try ProfileManager.shared.saveProfile(name: suggestedName, content: content, sourceURL: url.lastPathComponent, activate: true)
                            updateConfigStatus()
                            showAlert("成功导入配置文件「\(suggestedName)」！")
                            appState.reloadLocalProfile()
                        } catch {
                            showAlert("保存配置失败: \(error.localizedDescription)")
                        }
                    }
                case .failure(let err):
                    showAlert("选取文件失败: \(err.localizedDescription)")
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("配置管理".localized), message: Text(alertMessage ?? ""), dismissButton: .default(Text("好的".localized)))
            }
            .onAppear {
                updateConfigStatus()
            }
        }
    }

    private var currentProfileText: String {
        if let active = ProfileManager.shared.activeProfile() {
            return "当前生效: \(active.name)"
        }
        return "暂无已激活档案"
    }

    private func updateConfigStatus() {
        hasConfig = AppGroupConstants.hasActiveConfig
        if let text = AppGroupConstants.loadConfig() {
            let lineCount = text.split(separator: "\n").count
            let kb = max(1, text.utf8.count / 1024)
            configSummary = "大小: \(kb) KB · 行数: \(lineCount) 行"
        } else {
            configSummary = nil
        }
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert("剪贴板中未找到文本内容")
            return
        }
        let suggestedName = ProfileManager.shared.suggestUniqueName(baseName: "剪贴板导入")
        do {
            try ProfileManager.shared.saveProfile(name: suggestedName, content: text, sourceURL: nil, activate: true)
            updateConfigStatus()
            showAlert("成功从剪贴板导入配置「\(suggestedName)」！")
            appState.reloadLocalProfile()
        } catch {
            showAlert("保存配置失败: \(error.localizedDescription)")
        }
    }

    private func showAlert(_ msg: String) {
        alertMessage = msg
        showingAlert = true
    }

    private func labeledRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
