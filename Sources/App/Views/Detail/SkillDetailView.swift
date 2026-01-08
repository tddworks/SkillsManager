import SwiftUI
import Domain

struct SkillDetailView: View {
    let skill: Skill
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Rendered markdown content
                MarkdownView(content: skill.content)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle(skill.name)
        .navigationSubtitle(skill.source.displayName)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Install button
                Button {
                    appState.showInstall()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Install skill")

                // Uninstall menu (only if installed)
                if skill.isInstalled {
                    Menu {
                        ForEach(Array(skill.installedProviders), id: \.self) { provider in
                            Button(role: .destructive) {
                                appState.confirmUninstall(from: provider)
                            } label: {
                                Label("Uninstall from \(provider.displayName)", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Uninstall skill")
                }

                // Open in Finder
                Button {
                    openInFinder()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Show in Finder")
                .disabled(!skill.source.isLocal)
            }
        }
        .confirmationDialog(
            "Uninstall Skill",
            isPresented: $appState.showingUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                Task { await appState.uninstall() }
            }
            Button("Cancel", role: .cancel) {
                appState.cancelUninstall()
            }
        } message: {
            if let provider = appState.uninstallProvider {
                Text("Are you sure you want to uninstall \"\(skill.name)\" from \(provider.displayName)? This will delete the skill folder at:\n\(provider.skillsPath)/\(skill.id)")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(skill.name)
                .font(.largeTitle.weight(.bold))

            // Description
            Text(skill.description)
                .font(.body)
                .foregroundStyle(.secondary)

            // Metadata row
            HStack(spacing: 16) {
                // Version
                Label("v\(skill.version)", systemImage: "tag")

                // Source
                if skill.source.isLocal {
                    Label(skill.source.displayName, systemImage: "internaldrive")
                } else {
                    Label(skill.source.displayName, systemImage: "cloud")
                }

                // Installation status
                if skill.isInstalled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Installed")
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Provider badges with uninstall buttons
            if skill.isInstalled {
                HStack(spacing: 8) {
                    Text("Installed for:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Array(skill.installedProviders), id: \.self) { provider in
                        ProviderBadge(
                            provider: provider,
                            onUninstall: {
                                appState.confirmUninstall(from: provider)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func openInFinder() {
        guard case .local(let provider) = skill.source else { return }
        let path = "\(provider.skillsPath)/\(skill.id)"
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}

/// Provider badge with optional uninstall action
struct ProviderBadge: View {
    let provider: Provider
    let onUninstall: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(provider.displayName)
                .font(.caption2.weight(.medium))

            if isHovering {
                Button {
                    onUninstall()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(providerColor.opacity(0.2))
        .foregroundStyle(providerColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var providerColor: Color {
        switch provider {
        case .codex: return .green
        case .claude: return .blue
        }
    }
}
