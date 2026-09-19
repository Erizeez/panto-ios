import SwiftUI
import PantoShared

public struct MainTabView: View {
    @StateObject private var appState: AppState
    @EnvironmentObject private var proStore: ProStore
    @State private var selectedTab: Int
    @State private var importPayload: ImportConfirmationPayload? = nil
    @State private var isDownloadingConfig: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert: Bool = false

    public init(vpnManager: VPNManager, initialTab: Int = 0) {
        _appState = StateObject(wrappedValue: AppState(vpnManager: vpnManager))
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(appState: appState)
                .tabItem {
                    Label("仪表盘".localized, systemImage: "bolt.shield.fill")
                }
                .tag(0)

            TopologyView(appState: appState)
                .tabItem {
                    Label("拓扑图".localized, systemImage: "point.3.filled.connected.trianglepath.dotted")
                }
                .tag(1)

            GroupsView(appState: appState)
                .tabItem {
                    Label("策略组".localized, systemImage: "slider.horizontal.3")
                }
                .tag(2)

            ProbeView(appState: appState)
                .tabItem {
                    Label("全球测速".localized, systemImage: "network")
                }
                .tag(3)

            SettingsView(appState: appState)
                .tabItem {
                    Label("设置".localized, systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.accentColor)
        .sheet(item: $importPayload) { payload in
            ImportConfirmationSheet(appState: appState, payload: payload) {
                appState.reloadLocalProfile()
            }
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("导入失败".localized),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("好的".localized))
            )
        }
        .alert(isPresented: $appState.showingVPNAlert) {
            Alert(
                title: Text("VPN 提示".localized),
                message: Text(appState.vpnAlertMessage ?? ""),
                dismissButton: .default(Text("好的".localized))
            )
        }
        .onOpenURL { incomingURL in
            handleIncomingURL(incomingURL)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let link = DeepLinkParser.parse(url) else {
            errorMessage = "无法识别的深度链接协议: \(url.absoluteString)"
            showingErrorAlert = true
            return
        }

        switch link {
        case .installConfig(let downloadURL, let name, let token):
            isDownloadingConfig = true
            Task {
                do {
                    var request = URLRequest(url: downloadURL)
                    if let token = token {
                        request.setValue(token, forHTTPHeaderField: "X-Panto-Token")
                    }
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 400 {
                        throw NSError(domain: "panto.import", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "下载配置失败 (HTTP \(httpResp.statusCode))"])
                    }
                    guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
                        throw NSError(domain: "panto.import", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载的配置文件内容为空"])
                    }
                    let profileName = name ?? downloadURL.lastPathComponent.replacingOccurrences(of: ".yaml", with: "").replacingOccurrences(of: ".yml", with: "")
                    await MainActor.run {
                        self.isDownloadingConfig = false
                        self.importPayload = ImportConfirmationPayload(
                            name: profileName.isEmpty ? "远程配置" : profileName,
                            sourceURL: downloadURL.absoluteString,
                            rawContent: text
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.isDownloadingConfig = false
                        self.errorMessage = "拉取配置失败: \(error.localizedDescription)"
                        self.showingErrorAlert = true
                    }
                }
            }

        case .importData(let content, let name):
            self.importPayload = ImportConfirmationPayload(
                name: name ?? "内联配置",
                sourceURL: nil,
                rawContent: content
            )
        }
    }
}
