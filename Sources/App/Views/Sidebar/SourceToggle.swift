import SwiftUI
import Domain

struct SourcePicker: View {
    @Binding var selection: SourceFilter
    let repositories: [SkillsRepo]
    let onAddRepo: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("Source")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

                // Remote repositories
                ForEach(repositories) { repo in
                    Button {
                        selection = .remote(repoId: repo.id)
                    } label: {
                        HStack {
                            Label(repo.name, systemImage: "cloud")
                            if case .remote(let repoId) = selection, repoId == repo.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                // Add repository
                Button {
                    onAddRepo()
                } label: {
                    Label("Add Repository...", systemImage: "plus")
                }

            } label: {
                HStack(spacing: 6) {
                    Text(currentSelectionLabel)
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var currentSelectionLabel: String {
        switch selection {
        case .local:
            return "Local"
        case .remote(let repoId):
            return repositories.first { $0.id == repoId }?.name ?? "Remote"
        }
    }
}

/// Sheet for adding a new repository
struct AddRepositorySheet: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var urlInput: String = ""
    @FocusState private var isURLFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Repository")
                    .font(.title2.weight(.bold))
                Text("Enter a GitHub repository URL containing skills.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            // URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub URL")
                    .font(.headline)

                TextField("https://github.com/owner/repo", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($isURLFocused)

                Text("The repository should contain skill folders with SKILL.md files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Example
            VStack(alignment: .leading, spacing: 4) {
                Text("Examples:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("• https://github.com/anthropics/skills")
                    Text("• https://github.com/your-org/internal-skills")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    appState.addRepository(url: urlInput)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlInput.isEmpty || !urlInput.contains("github.com"))
            }
        }
        .padding(24)
        .frame(width: 450, height: 320)
        .onAppear {
            isURLFocused = true
        }
    }
}

/// Row showing a repository with remove option
struct RepositoryRow: View {
    let repo: SkillsRepo
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "cloud")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.body.weight(.medium))
                    Text(repo.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }

                if isHovering && repo.id != SkillsRepo.anthropicSkills.id {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
