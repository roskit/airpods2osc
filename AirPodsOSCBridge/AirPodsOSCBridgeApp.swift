import SwiftUI

@main
struct AirPodsOSCBridgeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("AirPods OSC Bridge", systemImage: "headphones") {
            MenuBarView(appState: appState)
                .background(MenuBarWindowConfigurator { isOpen in
                    appState.setMenuOpen(isOpen)
                })
        }
        .menuBarExtraStyle(.window)
    }
}