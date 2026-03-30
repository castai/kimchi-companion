import SwiftUI

/// Menu bar label displaying the pepper icon and the current cost text.
/// Reads `AppState` from the environment so it updates reactively.
public struct MenuBarLabel: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .opacity(appState.isStale ? 0.5 : 1.0)

            let text = appState.displayText
            if !text.isEmpty {
                Text(text)
            }
        }
    }
}
