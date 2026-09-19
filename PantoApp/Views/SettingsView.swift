import SwiftUI
import PantoShared

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject private var proStore: ProStore
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showingProSheet = false

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

                // 2. Pro 商业版状态
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
        }
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
