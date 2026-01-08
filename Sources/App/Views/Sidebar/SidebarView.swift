import SwiftUI
import Domain

struct SidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter skills", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                if !appState.searchQuery.isEmpty {
                    Button {
                        appState.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.top, 8)

            // Source picker (dropdown menu)
            SourcePicker(
                selection: $appState.selectedSource,
                repositories: appState.repositories,
                onAddRepo: {
                    appState.showingAddRepoSheet = true
                },
                onRemoveRepo: { repo in
                    appState.removeRepository(repo)
                }
            )
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            // Skills header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.headline)
                    Text("\(appState.filteredSkills.count) skills")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Error message
            if let error = appState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        appState.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Skills list
            if appState.filteredSkills.isEmpty && !appState.isLoading {
                Spacer()
                ContentUnavailableView(
                    "No Skills",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(emptyStateMessage)
                )
                Spacer()
            } else {
                List(appState.filteredSkills, selection: Binding(
                    get: { appState.selectedSkill },
                    set: { skill in
                        if let skill {
                            appState.select(skill)
                        }
                    }
                )) { skill in
                    SkillRowView(skill: skill)
                        .tag(skill)
                }
                .listStyle(.sidebar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appState.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh skills")
                .disabled(appState.isLoading)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.showingAddRepoSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add repository")
            }
        }
        .sheet(isPresented: $appState.showingAddRepoSheet) {
            AddRepositorySheet(appState: appState)
        }
    }

    private var headerTitle: String {
        switch appState.selectedSource {
        case .local:
            return "Installed Skills"
        case .remote(let repoId):
            if let repo = appState.repositories.first(where: { $0.id == repoId }) {
                return repo.name
            }
            return "Remote Skills"
        }
    }

    private var emptyStateMessage: String {
        if !appState.searchQuery.isEmpty {
            return "No skills match your search"
        }
        switch appState.selectedSource {
        case .local:
            return "No skills installed locally"
        case .remote:
            return "No skills found in this repository"
        }
    }
}
