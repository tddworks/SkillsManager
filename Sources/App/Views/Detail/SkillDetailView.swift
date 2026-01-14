import SwiftUI
import Domain
import Infrastructure

struct SkillDetailView: View {
    let skill: Skill
    @Bindable var library: SkillLibrary
    @Binding var showingInstallSheet: Bool

    // Local UI state for uninstall confirmation
    @State private var showingUninstallConfirmation = false
    @State private var providerToUninstall: Provider?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero header
                heroHeader
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    .padding(.top, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.lg)

                // Subtle separator
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, DesignSystem.Colors.subtleBorder, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, DesignSystem.Spacing.xxl)

                // Markdown content
                MarkdownView(content: skill.content)
                    .textSelection(.enabled)
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    .padding(.top, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xxxl)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(skill.name)
        .navigationSubtitle(skill.source.displayName)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Edit button (only for local skills)
                if skill.isEditable {
                    Button {
                        library.startEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .help("Edit skill")
                }

                // Install button
                Button {
                    showingInstallSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                }
                .help("Install skill")

                // Uninstall menu (only if installed)
                if skill.isInstalled {
                    Menu {
                        ForEach(Array(skill.installedProviders), id: \.self) { provider in
                            Button(role: .destructive) {
                                providerToUninstall = provider
                                showingUninstallConfirmation = true
                            } label: {
                                Label("Uninstall from \(provider.displayName)", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .help("Uninstall skill")
                }

                // Open in Finder
                Button {
                    openInFinder()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .medium))
                }
                .help("Show in Finder")
                .disabled(!skill.source.isLocal)
            }
        }
        .confirmationDialog(
            "Uninstall Skill",
            isPresented: $showingUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                if let provider = providerToUninstall {
                    Task { await library.uninstall(from: provider) }
                }
            }
            Button("Cancel", role: .cancel) {
                providerToUninstall = nil
            }
        } message: {
            if let provider = providerToUninstall {
                Text("Are you sure you want to uninstall \"\(skill.name)\" from \(provider.displayName)? This will delete the skill folder.")
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Title row
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Skill name
                    Text(skill.displayName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    // Source info
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: skill.source.isLocal ? "internaldrive" : "cloud")
                            .font(.system(size: 11, weight: .medium))
                        Text(skill.source.displayName)
                            .font(DesignSystem.Typography.bodySecondary)
                    }
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }

                Spacer()

                // Installation status indicator
                if skill.isInstalled {
                    IconBadge(icon: "checkmark.circle.fill", text: "Installed", color: DesignSystem.Colors.success)
                }
            }

            // Description
            Text(skill.description)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Metadata row
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Version
                metadataItem(icon: "tag", label: "Version", value: "v\(skill.version)")

                // References
                if skill.hasReferences {
                    metadataItem(
                        icon: "doc.text",
                        label: "References",
                        value: "\(skill.referenceCount)"
                    )
                }

                // Scripts
                if skill.hasScripts {
                    metadataItem(
                        icon: "terminal",
                        label: "Scripts",
                        value: "\(skill.scriptCount)"
                    )
                }
            }

            // Provider badges with uninstall
            if skill.isInstalled {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Installed for")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(Array(skill.installedProviders), id: \.self) { provider in
                            ProviderBadge(
                                provider: provider,
                                onUninstall: {
                                    providerToUninstall = provider
                                    showingUninstallConfirmation = true
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Metadata Item

    private func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(DesignSystem.Typography.micro)
            }
            .foregroundStyle(DesignSystem.Colors.tertiaryText)

            Text(value)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.primaryText)
        }
    }

    // MARK: - Actions

    private func openInFinder() {
        guard case .local(let provider) = skill.source else { return }
        let pathResolver = ProviderPathResolver()
        let path = "\(pathResolver.skillsPath(for: provider))/\(skill.id)"
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}

// MARK: - Provider Badge

struct ProviderBadge: View {
    let provider: Provider
    let onUninstall: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Provider icon
            Image(systemName: providerIcon)
                .font(.system(size: 10, weight: .semibold))

            Text(provider.displayName)
                .font(DesignSystem.Typography.caption)

            if isHovering {
                Button {
                    onUninstall()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .fill(providerColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                        .stroke(providerColor.opacity(0.25), lineWidth: 1)
                )
        )
        .foregroundStyle(providerColor)
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

    private var providerColor: Color {
        switch provider {
        case .codex: return DesignSystem.Colors.codexGreen
        case .claude: return DesignSystem.Colors.claudeBlue
        }
    }
}