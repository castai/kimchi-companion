import SwiftUI

/// Menu bar label displaying an SF Symbol and the current cost text.
/// Reads `AppState` from the environment so it updates reactively.
struct MenuBarLabel: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle")
            Text(appState.displayCost)
        }
    }
}
