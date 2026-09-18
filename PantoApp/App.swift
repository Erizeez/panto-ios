import SwiftUI

@main
struct PantoApp: App {
    @StateObject private var vpnManager = VPNManager()
    @StateObject private var proStore = ProStore()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(vpnManager)
                .environmentObject(proStore)
        }
    }
}
