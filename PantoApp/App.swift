import SwiftUI

@main
struct PantoApp: App {
    @StateObject private var vpnManager = VPNManager()
    @StateObject private var proStore = ProStore()
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView(vpnManager: vpnManager)
                .environmentObject(vpnManager)
                .environmentObject(proStore)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale)
                .id(languageManager.currentLanguage)
        }
    }
}
