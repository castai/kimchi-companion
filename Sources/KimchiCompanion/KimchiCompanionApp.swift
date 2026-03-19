import SwiftUI

@main
@MainActor
struct KimchiCompanionApp: App {
    @State private var appState = AppState()
    
    init() {
        // Hide from Dock and Cmd+Tab app switcher.
        // Must be set before the first scene renders.
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra {
            PopoverContentView()
                .environment(appState)
        } label: {
            MenuBarLabel()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
