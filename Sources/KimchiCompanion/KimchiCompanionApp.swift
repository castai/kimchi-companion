import SwiftUI

@main
@MainActor
struct KimchiCompanionApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Hello from Kimchi Companion")
                .padding()
        } label: {
            Text("Kimchi")
        }
        .menuBarExtraStyle(.window)
    }
}
