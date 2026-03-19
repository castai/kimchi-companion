import SwiftUI

/// Root view for the MenuBarExtra popover window.
/// Downstream slices (S02, S04, S05) replace the placeholder content
/// with API key setup, usage display, and settings views.
struct PopoverContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Kimchi Companion")
                .font(.headline)
            
            Text("Configure your API key to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Divider()
            
            // Debug control — proves dynamic menu bar label updates.
            // Remove or gate behind a debug flag once real usage data lands (S03).
            Button("Toggle Cost") {
                if appState.displayCost == "$0.00" {
                    appState.displayCost = "$12.34"
                } else {
                    appState.displayCost = "$0.00"
                }
            }
            
            Spacer()
            
            Divider()
            
            // Quit button — essential for no-Dock apps that lack
            // the standard app menu and Cmd+Q shortcut.
            Button("Quit Kimchi Companion") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(minWidth: 300, maxWidth: 300, minHeight: 200)
    }
}
