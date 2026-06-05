import SwiftUI

/// A compact menu picker for selecting the active organization or personal scope.
struct OrganizationPicker: View {
    var selectedId: String?
    var organizations: [Organization]
    var isLoading: Bool
    var onSelect: (String?) -> Void

    var body: some View {
        if isLoading {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker("Organization", selection: Binding(
                get: { selectedId },
                set: { onSelect($0) }
            )) {
                Text("Personal").tag(nil as String?)
                ForEach(organizations, id: \.id) { org in
                    Text(org.name).tag(org.id as String?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}