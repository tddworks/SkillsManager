import SwiftUI
import Domain
import Infrastructure

struct InstallSheet: View {
    let skill: Skill
    @Bindable var library: SkillLibrary
    @Binding var isPresented: Bool

    @State private var selectedProviders: Set<Provider> = []
    @State private var isInstalling = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignSystem.Spacing.md) {
                // Icon with subtle gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent.opacity(0.2),
                                    DesignSystem.Colors.accent.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Install Skill")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    Text("Choose where to install")
                        .font(DesignSystem.Typography.bodySecondary)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    Text(skill.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
            .padding(.top, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xl)

            // Provider cards
            VStack(spacing: DesignSystem.Spacing.sm) {
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
            .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()

            // Buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .font(DesignSystem.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Button {
                    isInstalling = true
                    Task {
                        await library.install(to: selectedProviders)
                        isInstalling = false
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if isInstalling {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isInstalling ? "Installing..." : "Install")
                            .font(DesignSystem.Typography.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProviders.isEmpty || isInstalling)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .frame(width: 360, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedProviders = Set(Provider.allCases.filter { !skill.isInstalledFor($0) })
        }
    }

    private func toggleProvider(_ provider: Provider) {
        withAnimation(DesignSystem.Animation.quick) {
            if selectedProviders.contains(provider) {
                selectedProviders.remove(provider)
            } else {
                selectedProviders.insert(provider)
            }
        }
    }
}

// MARK: - Provider Card

struct ProviderCard: View {
    let provider: Provider
    let isSelected: Bool
    let isAlreadyInstalled: Bool
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Provider icon
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                        .fill(iconBackgroundColor)
                        .frame(width: 44, height: 44)

                    Image(systemName: providerIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                // Provider info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(provider.displayName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(isAlreadyInstalled ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.primaryText)

                        if isAlreadyInstalled {
                            RefinedBadge(text: "Installed", style: .success)
                        }
                    }

                    Text(shortenedPath)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                }

                Spacer()

                // Checkbox
                ZStack {
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected || isAlreadyInstalled {
                        Circle()
                            .fill(fillColor)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous)
                            .stroke(
                                isSelected && !isAlreadyInstalled ? DesignSystem.Colors.accent.opacity(0.5) :
                                    (isHovering && !isAlreadyInstalled ? DesignSystem.Colors.subtleBorder : .clear),
                                lineWidth: isSelected && !isAlreadyInstalled ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isHovering && !isAlreadyInstalled ? DesignSystem.Shadows.subtle.color : .clear,
                radius: DesignSystem.Shadows.subtle.radius,
                y: DesignSystem.Shadows.subtle.y
            )
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyInstalled)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
    }

    private var providerIcon: String {
        switch provider {
        case .codex: return "terminal"
        case .claude: return "message"
        }
    }

    private var iconBackgroundColor: Color {
        switch provider {
        case .codex: return DesignSystem.Colors.codexGreen.opacity(0.15)
        case .claude: return DesignSystem.Colors.claudeBlue.opacity(0.15)
        }
    }

    private var iconColor: Color {
        switch provider {
        case .codex: return DesignSystem.Colors.codexGreen
        case .claude: return DesignSystem.Colors.claudeBlue
        }
    }

    private var borderColor: Color {
        if isAlreadyInstalled { return DesignSystem.Colors.tertiaryText.opacity(0.3) }
        return isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText.opacity(0.4)
    }

    private var fillColor: Color {
        isAlreadyInstalled ? DesignSystem.Colors.tertiaryText.opacity(0.5) : DesignSystem.Colors.accent
    }

    private var shortenedPath: String {
        let pathResolver = ProviderPathResolver()
        return pathResolver.skillsPath(for: provider)
            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}
