import SwiftUI
import Domain

struct SidebarView: View {
    @Bindable var library: SkillLibrary

    #if ENABLE_SPARKLE
    @Environment(\.sparkleUpdater) private var sparkleUpdater
    #endif

    @State private var searchIsFocused = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar with refined styling
            searchBar
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)

            // Source picker
            SourcePicker(
                selection: $library.selectedSource,
                repositories: library.repositories,
                onAddRepo: {
                    library.showingAddRepoSheet = true
                },
                onRemoveRepo: { repo in
                    library.removeRepository(repo)
                }
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.md)

            // Subtle divider
            Rectangle()
                .fill(DesignSystem.Colors.subtleBorder)
                .frame(height: 1)
                .padding(.horizontal, DesignSystem.Spacing.md)

            // Skills header
            skillsHeader
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)

            // Error message
            if let error = library.errorMessage {
                errorBanner(error)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }

            // Skills list
            if library.filteredSkills.isEmpty && !library.isLoading {
                Spacer()
                emptyState
                Spacer()
            } else {
                skillsList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            #if ENABLE_SPARKLE
            ToolbarItem(placement: .primaryAction) {
                SidebarSettingsButton(sparkleUpdater: sparkleUpdater)
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button {
                    library.showingAddRepoSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .help("Add repository")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await library.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .help("Refresh skills")
                .disabled(library.isLoading)
            }
        }
        .sheet(isPresented: $library.showingAddRepoSheet) {
            AddRepositorySheet(library: library)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(searchIsFocused ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)

            TextField("Filter skills", text: $library.searchQuery)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)

            if !library.searchQuery.isEmpty {
                Button {
                    withAnimation(DesignSystem.Animation.quick) {
                        library.searchQuery = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                        .stroke(
                            searchIsFocused ? DesignSystem.Colors.accent.opacity(0.4) : DesignSystem.Colors.subtleBorder,
                            lineWidth: 1
                        )
                )
        )
        .onTapGesture {
            searchIsFocused = true
        }
    }

    // MARK: - Skills Header

    private var skillsHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("\(library.filteredSkills.count) skill\(library.filteredSkills.count == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }

            Spacer()

            if library.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.warning)

            Text(message)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineLimit(2)

            Spacer()

            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    library.errorMessage = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                .fill(DesignSystem.Colors.warning.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                        .stroke(DesignSystem.Colors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("No Skills Found")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                Text(emptyStateMessage)
                    .font(DesignSystem.Typography.bodySecondary)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
    }

    // MARK: - Skills List

    private var skillsList: some View {
        List(library.filteredSkills, id: \.uniqueKey, selection: Binding(
            get: { library.selectedSkill },
            set: { skill in
                if let skill {
                    library.select(skill)
                }
            }
        )) { skill in
            SkillRowView(skill: skill)
                .tag(skill)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Helpers

    private var headerTitle: String {
        switch library.selectedSource {
        case .local:
            return "Installed Skills"
        case .remote(let repoId):
            if let repo = library.repositories.first(where: { $0.id == repoId }) {
                return repo.name
            }
            return "Remote Skills"
        }
    }

    private var emptyStateMessage: String {
        if !library.searchQuery.isEmpty {
            return "No skills match your search"
        }
        switch library.selectedSource {
        case .local:
            return "No skills installed locally"
        case .remote:
            return "No skills found in this repository"
        }
    }
}

// MARK: - Sidebar Settings Button

#if ENABLE_SPARKLE
struct SidebarSettingsButton: View {
    let sparkleUpdater: SparkleUpdater?

    var body: some View {
        SettingsLink {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))

                // Update badge
                if sparkleUpdater?.isUpdateAvailable == true {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .help(sparkleUpdater?.isUpdateAvailable == true ? "Update available - Open Settings" : "Settings")
    }
}
#endif