import SwiftUI
import Domain

struct SourcePicker: View {
    @Binding var selection: SourceFilter
    let catalogs: [SkillsCatalog]
    let onAddCatalog: () -> Void
    let onRemoveCatalog: (SkillsCatalog) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            Text("Source")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)

            Spacer()

            Menu {
                // Local option
                Button {
                    selection = .local
                } label: {
                    HStack {
                        Label("Local", systemImage: "internaldrive")
                        if case .local = selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                // Remote catalogs with remove option
                ForEach(catalogs) { catalog in
                    Menu {
                        Button {
                            selection = .remote(repoId: catalog.id)
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }

                        // Don't allow removing the default Anthropic skills catalog
                        if catalog.id != SkillsCatalog.anthropicSkills.id {
                            Divider()

                            Button(role: .destructive) {
                                onRemoveCatalog(catalog)
                            } label: {
                                Label("Remove Catalog", systemImage: "trash")
                            }
                        }
                    } label: {
                        HStack {
                            Label(catalog.name, systemImage: "cloud")
                            if case .remote(let catalogId) = selection, catalogId == catalog.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                // Add catalog
                Button {
                    onAddCatalog()
                } label: {
                    Label("Add Catalog...", systemImage: "plus")
                }

            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: sourceIcon)
                        .font(.system(size: 10, weight: .semibold))

                    Text(currentSelectionLabel)
                        .font(DesignSystem.Typography.caption)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                        .fill(DesignSystem.Colors.accent)
                )
                .foregroundStyle(.white)
                .shadow(
                    color: isHovering ? DesignSystem.Shadows.elevated.color : DesignSystem.Shadows.subtle.color,
                    radius: isHovering ? DesignSystem.Shadows.elevated.radius : DesignSystem.Shadows.subtle.radius,
                    y: isHovering ? DesignSystem.Shadows.elevated.y : DesignSystem.Shadows.subtle.y
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.quick) {
                    isHovering = hovering
                }
            }
        }
    }

    private var sourceIcon: String {
        switch selection {
        case .local: return "internaldrive"
        case .remote: return "cloud"
        }
    }

    private var currentSelectionLabel: String {
        switch selection {
        case .local:
            return "Local"
        case .remote(let catalogId):
            return catalogs.first { $0.id == catalogId }?.name ?? "Remote"
        }
    }
}

// MARK: - Add Catalog Sheet

struct AddCatalogSheet: View {
    @Bindable var library: SkillLibrary
    @Binding var isPresented: Bool

    @State private var urlInput: String = ""
    @FocusState private var isURLFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Add Catalog")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Enter a GitHub repository URL containing skills.")
                    .font(DesignSystem.Typography.bodySecondary)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)

            // Subtle divider
            Rectangle()
                .fill(DesignSystem.Colors.subtleBorder)
                .frame(height: 1)
                .padding(.bottom, DesignSystem.Spacing.lg)

            // URL input
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("GitHub URL")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                TextField("https://github.com/owner/repo", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.body)
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                                    .stroke(
                                        isURLFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.subtleBorder,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .focused($isURLFocused)

                Text("The catalog should contain skill folders with SKILL.md files.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)

            // Example
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Examples")
                    .font(DesignSystem.Typography.micro)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)

                VStack(alignment: .leading, spacing: 4) {
                    exampleRow("anthropics/skills")
                    exampleRow("your-org/internal-skills")
                }
            }

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
                    library.addCatalog(url: urlInput)
                    isPresented = false
                } label: {
                    Text("Add Catalog")
                        .font(DesignSystem.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(urlInput.isEmpty || !urlInput.contains("github.com"))
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(width: 450, height: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isURLFocused = true
        }
    }

    private func exampleRow(_ catalog: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "link")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)

            Text("github.com/\(catalog)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }
}

// MARK: - Catalog Row

struct CatalogRow: View {
    let catalog: SkillsCatalog
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "cloud")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                VStack(alignment: .leading, spacing: 2) {
                    Text(catalog.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    Text(catalog.url)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                if isHovering && catalog.id != SkillsCatalog.anthropicSkills.id {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
    }
}
