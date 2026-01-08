import SwiftUI
import Domain
import Infrastructure

/// Observable app state - single source of truth
@Observable
@MainActor
public final class AppState {

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

    /// Remove a repository
    public func removeRepository(_ repo: SkillsRepo) {
        repositories.removeAll { $0.id == repo.id }

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

            // Load remote skills from all repositories
            for repo in repositories {
                do {
                    let remoteRepo = GitHubSkillRepository(repoUrl: repo.url)
                    let remoteSkills = try await remoteRepo.fetchAll()

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
                                scriptCount: skill.scriptCount
                            )
                            merged[key] = remoteVersion
                        } else {
                            merged[key] = skill
                        }
                    }
                } catch {
                    // Log error but continue with other repos
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
}

/// Filter for skill sources
public enum SourceFilter: Hashable {
    case local
    case remote(repoId: UUID)
}
