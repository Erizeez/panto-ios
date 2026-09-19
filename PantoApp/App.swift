import SwiftUI

@main
struct PantoApp: App {
    @StateObject private var vpnManager = VPNManager()
    @StateObject private var proStore = ProStore()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var iconManager = AppIconManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView(vpnManager: vpnManager)
                .environmentObject(vpnManager)
                .environmentObject(proStore)
                .environmentObject(languageManager)
                .environmentObject(iconManager)
                .environment(\.locale, languageManager.locale)
                .id(languageManager.currentLanguage)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        iconManager.checkAndRotateIconIfNeeded()
                    }
                }
        }
    }
}
