import SwiftUI
import Domain
import Infrastructure

/// The user's skill library - browse, search, and manage skills
@Observable
@MainActor
public final class SkillLibrary {

    // MARK: - State

    /// All skills (local + remote combined)
    public var skills: [Skill] = []

    /// Currently selected skill
    public var selectedSkill: Skill?

    /// Current source filter
    public var selectedSource: SourceFilter = .local

    /// Search query
    public var searchQuery: String = ""

    /// Loading state
    public var isLoading: Bool = false

    /// Error message
    public var errorMessage: String?

    /// Show install sheet
    public var showingInstallSheet: Bool = false

    /// Show uninstall confirmation
    public var showingUninstallConfirmation: Bool = false

    /// Provider to uninstall from
    public var uninstallProvider: Provider?

    /// Show add repository sheet
    public var showingAddRepoSheet: Bool = false

    /// The skill editor for editing local skills
    public var skillEditor: SkillEditor?

    /// Whether edit mode is active
    public var isEditing: Bool {
        skillEditor != nil
    }

    /// User's configured repositories
    public var repositories: [SkillsRepo] = [] {
        didSet {
            saveRepositories()
        }
    }

    // MARK: - Computed Properties

    /// Currently selected repository (if source is remote)
    public var selectedRepo: SkillsRepo? {
        if case .remote(let repoId) = selectedSource {
            return repositories.first { $0.id == repoId }
        }
        return nil
    }

    /// Filtered skills based on source and search
    public var filteredSkills: [Skill] {
        skills.filter { skill in
            // Filter by source
            let matchesSource: Bool
            switch selectedSource {
            case .local:
                matchesSource = skill.source.isLocal
            case .remote(let repoId):
                if case .remote(let skillRepoUrl) = skill.source {
                    let repo = repositories.first { $0.id == repoId }
                    matchesSource = repo?.url == skillRepoUrl
                } else {
                    matchesSource = false
                }
            }

            // Filter by search
            let matchesSearch = searchQuery.isEmpty ||
                skill.name.localizedCaseInsensitiveContains(searchQuery) ||
                skill.description.localizedCaseInsensitiveContains(searchQuery)

            return matchesSource && matchesSearch
        }
    }

    /// Count of local skills
    public var localSkillCount: Int {
        skills.filter { $0.source.isLocal }.count
    }

    // MARK: - Repositories

    private let claudeRepo: LocalSkillRepository
    private let codexRepo: LocalSkillRepository

    // MARK: - Init

    public init() {
        self.claudeRepo = LocalSkillRepository(provider: .claude)
        self.codexRepo = LocalSkillRepository(provider: .codex)
        self.repositories = Self.loadRepositories()
    }

    // MARK: - Repository Management

    /// Add a new repository
    public func addRepository(url: String) {
        let repo = SkillsRepo(url: url)
        guard repo.isValid else {
            errorMessage = "Invalid GitHub URL"
            return
        }
        guard !repositories.contains(where: { $0.url == url }) else {
            errorMessage = "Repository already added"
            return
        }
        repositories.append(repo)
        showingAddRepoSheet = false

        // Switch to the new repo and load skills
        selectedSource = .remote(repoId: repo.id)
        Task { await loadSkills() }
    }

    /// Remove a repository and delete its cached clone
    public func removeRepository(_ repo: SkillsRepo) {
        repositories.removeAll { $0.id == repo.id }

        // Delete the cloned repository from cache
        do {
            try ClonedRepoSkillRepository.deleteClone(forRepoUrl: repo.url)
            print("[SkillLibrary] Deleted cached clone for: \(repo.name)")
        } catch {
            print("[SkillLibrary] Failed to delete cached clone for \(repo.name): \(error)")
        }

        // If we were viewing that repo, switch to local
        if case .remote(let repoId) = selectedSource, repoId == repo.id {
            selectedSource = .local
        }
    }

    // MARK: - Persistence

    private static let repositoriesKey = "skillsManager.repositories"

    private static func loadRepositories() -> [SkillsRepo] {
        guard let data = UserDefaults.standard.data(forKey: repositoriesKey),
              let repos = try? JSONDecoder().decode([SkillsRepo].self, from: data) else {
            // Return default repos
            return [.anthropicSkills]
        }
        return repos
    }

    private func saveRepositories() {
        if let data = try? JSONEncoder().encode(repositories) {
            UserDefaults.standard.set(data, forKey: Self.repositoriesKey)
        }
    }

    // MARK: - Actions

    /// Load skills from all sources
    public func loadSkills() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load local skills from both providers
            async let claudeSkills = claudeRepo.fetchAll()
            async let codexSkills = codexRepo.fetchAll()

            let (claude, codex) = try await (claudeSkills, codexSkills)

            // Merge local skills
            var merged: [String: Skill] = [:]

            for skill in claude {
                merged[skill.id] = skill.installing(for: .claude)
            }

            for skill in codex {
                if var existing = merged[skill.id] {
                    existing = existing.installing(for: .codex)
                    merged[skill.id] = existing
                } else {
                    merged[skill.id] = skill.installing(for: .codex)
                }
            }

            // Load remote skills from all repositories using git clone
            for repo in repositories {
                do {
                    print("[SkillLibrary] Loading skills from: \(repo.name) (\(repo.url)) via git clone")
                    let remoteRepo = ClonedRepoSkillRepository(repoUrl: repo.url)
                    let remoteSkills = try await remoteRepo.fetchAll()
                    print("[SkillLibrary] Found \(remoteSkills.count) skills in \(repo.name)")
                    for skill in remoteSkills {
                        print("[SkillLibrary]   - id: \(skill.id), name: \(skill.name)")
                    }

                    for skill in remoteSkills {
                        let key = "\(repo.id)-\(skill.id)"
                        if let existing = merged[skill.id] {
                            // Mark remote version with installation status from local
                            let remoteVersion = Skill(
                                id: skill.id,
                                name: skill.name,
                                description: skill.description,
                                version: skill.version,
                                content: skill.content,
                                source: skill.source,
                                installedProviders: existing.installedProviders,
                                referenceCount: skill.referenceCount,
                                scriptCount: skill.scriptCount,
                                folderName: skill.folderName
                            )
                            merged[key] = remoteVersion
                        } else {
                            merged[key] = skill
                        }
                    }
                } catch {
                    // Show error to user but continue with other repos
                    let errorDesc: String
                    if let gitError = error as? GitCLIError {
                        switch gitError {
                        case .cloneFailed(let message):
                            errorDesc = "Clone failed: \(message)"
                        case .pullFailed(let message):
                            errorDesc = "Pull failed: \(message)"
                        case .gitNotInstalled:
                            errorDesc = "Git is not installed. Please install git to use remote repositories."
                        default:
                            errorDesc = "Git error: \(error.localizedDescription)"
                        }
                    } else {
                        errorDesc = "Failed to load: \(error.localizedDescription)"
                    }
                    errorMessage = "Error loading \(repo.name): \(errorDesc)"
                    print("Failed to load from \(repo.name): \(error)")
                }
            }

            skills = Array(merged.values).sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh skills
    public func refresh() async {
        await loadSkills()
    }

    /// Select a skill
    public func select(_ skill: Skill) {
        selectedSkill = skill
    }

    /// Show install sheet for current skill
    public func showInstall() {
        guard selectedSkill != nil else { return }
        showingInstallSheet = true
    }

    /// Install selected skill to providers
    public func install(to providers: Set<Provider>) async {
        guard let skill = selectedSkill else { return }

        isLoading = true

        do {
            let installer = FileSystemSkillInstaller()
            let updatedSkill = try await installer.install(skill, to: providers)

            if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                skills[index] = updatedSkill
            }
            selectedSkill = updatedSkill

            await loadSkills()

        } catch {
            errorMessage = "Installation failed: \(error.localizedDescription)"
        }

        isLoading = false
        showingInstallSheet = false
    }

    /// Show uninstall confirmation
    public func confirmUninstall(from provider: Provider) {
        guard selectedSkill != nil else { return }
        uninstallProvider = provider
        showingUninstallConfirmation = true
    }

    /// Uninstall selected skill
    public func uninstall() async {
        guard let skill = selectedSkill,
              let provider = uninstallProvider else { return }

        isLoading = true

        do {
            let installer = FileSystemSkillInstaller()
            let updatedSkill = try await installer.uninstall(skill, from: provider)

            if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                skills[index] = updatedSkill
            }
            selectedSkill = updatedSkill

            await loadSkills()

        } catch {
            errorMessage = "Uninstall failed: \(error.localizedDescription)"
        }

        isLoading = false
        showingUninstallConfirmation = false
        uninstallProvider = nil
    }

    /// Cancel uninstall
    public func cancelUninstall() {
        showingUninstallConfirmation = false
        uninstallProvider = nil
    }

    // MARK: - Editing

    /// Start editing the selected skill
    public func startEditing() {
        guard let skill = selectedSkill, skill.isEditable else { return }
        let writer = LocalSkillWriter()
        skillEditor = SkillEditor(skill: skill, writer: writer)
    }

    /// Cancel editing and discard changes
    public func cancelEditing() {
        skillEditor = nil
    }

    /// Save the edited skill and exit edit mode
    public func saveEditing() async {
        guard let editor = skillEditor else { return }

        do {
            let savedSkill = try await editor.save()

            // Update in-memory state
            if let index = skills.firstIndex(where: { $0.id == savedSkill.id }) {
                skills[index] = savedSkill
            }
            selectedSkill = savedSkill

            skillEditor = nil

        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}

/// Filter for skill sources
public enum SourceFilter: Hashable {
    case local
    case remote(repoId: UUID)
}
