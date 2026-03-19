import SwiftUI

/// Menu bar label displaying an SF Symbol and the current cost text.
/// Reads `AppState` from the environment so it updates reactively.
public struct MenuBarLabel: View {
    @Environment(AppState.self) private var appState
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle")
            Text(appState.displayCost)
        }
    }
}
