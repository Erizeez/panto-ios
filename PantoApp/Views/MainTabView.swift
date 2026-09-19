import SwiftUI
import PantoShared

public struct MainTabView: View {
    @StateObject private var appState: AppState
    @EnvironmentObject private var proStore: ProStore
    @State private var selectedTab: Int

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
    }
}
