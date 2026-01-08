import SwiftUI
import Domain

struct InstallSheet: View {
    let skill: Skill
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProviders: Set<Provider> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)

                Text("Install Skill")
                    .font(.title2.weight(.semibold))

                Text("Choose where to install **\(skill.name)**")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Provider cards
            VStack(spacing: 10) {
                ForEach(Provider.allCases, id: \.self) { provider in
                    ProviderCard(
                        provider: provider,
                        isSelected: selectedProviders.contains(provider),
                        isAlreadyInstalled: skill.isInstalledFor(provider)
                    ) {
                        toggleProvider(provider)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Button {
                    Task {
                        await appState.install(to: selectedProviders)
                        dismiss()
                    }
                } label: {
                    Text("Install")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProviders.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 340, height: 340)
        .onAppear {
            selectedProviders = Set(Provider.allCases.filter { !skill.isInstalledFor($0) })
        }
    }

    private func toggleProvider(_ provider: Provider) {
        if selectedProviders.contains(provider) {
            selectedProviders.remove(provider)
        } else {
            selectedProviders.insert(provider)
        }
    }
}

/// Modern card-style provider selection
struct ProviderCard: View {
    let provider: Provider
    let isSelected: Bool
    let isAlreadyInstalled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Provider icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 40, height: 40)

                    Image(systemName: providerIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(iconColor)
                }

                // Provider info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(provider.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(isAlreadyInstalled ? .secondary : .primary)

                        if isAlreadyInstalled {
                            Text("Installed")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(shortenedPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Toggle/Checkbox
                ZStack {
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected || isAlreadyInstalled {
                        Circle()
                            .fill(fillColor)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && !isAlreadyInstalled ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyInstalled)
    }

    private var providerIcon: String {
        switch provider {
        case .codex: return "terminal"
        case .claude: return "message"
        }
    }

    private var iconBackgroundColor: Color {
        switch provider {
        case .codex: return .green.opacity(0.15)
        case .claude: return .blue.opacity(0.15)
        }
    }

    private var iconColor: Color {
        switch provider {
        case .codex: return .green
        case .claude: return .blue
        }
    }

    private var borderColor: Color {
        if isAlreadyInstalled { return .gray.opacity(0.3) }
        return isSelected ? .accentColor : .gray.opacity(0.4)
    }

    private var fillColor: Color {
        isAlreadyInstalled ? .gray.opacity(0.5) : .accentColor
    }

    private var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var shortenedPath: String {
        provider.skillsPath
            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}
