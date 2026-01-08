import SwiftUI
import Domain

struct InstallSheet: View {
    let skill: Skill
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProviders: Set<Provider> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Install Skill")
                    .font(.title2.weight(.bold))
                Text("Choose where to install \(skill.name).")
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Provider selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Install for")
                    .font(.headline)

                ForEach(Provider.allCases, id: \.self) { provider in
                    ProviderCheckbox(
                        provider: provider,
                        isSelected: selectedProviders.contains(provider),
                        isAlreadyInstalled: skill.isInstalledFor(provider)
                    ) {
                        if selectedProviders.contains(provider) {
                            selectedProviders.remove(provider)
                        } else {
                            selectedProviders.insert(provider)
                        }
                    }
                }
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Install") {
                    Task {
                        await appState.install(to: selectedProviders)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProviders.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
        .onAppear {
            // Pre-select providers that aren't already installed
            selectedProviders = Set(Provider.allCases.filter { !skill.isInstalledFor($0) })
        }
    }
}

struct ProviderCheckbox: View {
    let provider: Provider
    let isSelected: Bool
    let isAlreadyInstalled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected || isAlreadyInstalled ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isAlreadyInstalled ? .gray : (isSelected ? Color.accentColor : .secondary))

                // Provider info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(provider.displayName)
                            .font(.body.weight(.medium))

                        if isAlreadyInstalled {
                            Text("(Already installed)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(provider.skillsPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyInstalled)
    }
}
