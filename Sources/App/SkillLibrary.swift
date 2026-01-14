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

    /// The skill editor for editing local skills
    public var skillEditor: SkillEditor?

    /// Whether edit mode is active
    public var isEditing: Bool {
        skillEditor != nil
    }

    /// User's configured skill catalogs (remote sources)
    public var catalogs: [SkillsCatalog] = [] {
        didSet {
            saveCatalogs()
        }
    }

    // MARK: - Computed Properties

    /// Currently selected catalog (if source is remote)
    public var selectedCatalog: SkillsCatalog? {
        if case .remote(let catalogId) = selectedSource {
            return catalogs.first { $0.id == catalogId }
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
            case .remote(let catalogId):
                if case .remote(let skillRepoUrl) = skill.source {
                    let catalog = catalogs.first { $0.id == catalogId }
                    matchesSource = catalog?.url == skillRepoUrl
                } else {
                    matchesSource = false
                }
            }

            // Filter by search - delegated to domain model
            return matchesSource && skill.matches(query: searchQuery)
        }
    }

    /// Count of local skills
    public var localSkillCount: Int {
        skills.filter { $0.source.isLocal }.count
    }

    // MARK: - Dependencies

    private let claudeRepo: SkillRepository
    private let codexRepo: SkillRepository
    private let installer: SkillInstaller
    private let writerFactory: () -> SkillWriter

    // MARK: - Init

    public init() {
        self.claudeRepo = LocalSkillRepository(provider: .claude)
        self.codexRepo = LocalSkillRepository(provider: .codex)
        self.installer = FileSystemSkillInstaller()
        self.writerFactory = { LocalSkillWriter() }
        self.catalogs = Self.loadCatalogs()
    }

    /// Testable initializer with dependency injection
    public init(
        claudeRepo: SkillRepository,
        codexRepo: SkillRepository,
        installer: SkillInstaller,
        writerFactory: @escaping () -> SkillWriter = { LocalSkillWriter() },
        catalogs: [SkillsCatalog] = []
    ) {
        self.claudeRepo = claudeRepo
        self.codexRepo = codexRepo
        self.installer = installer
        self.writerFactory = writerFactory
        self.catalogs = catalogs
    }

    // MARK: - Catalog Management

    /// Add a new catalog
    public func addCatalog(url: String) {
        let catalog = SkillsCatalog(url: url)
        guard catalog.isValid else {
            errorMessage = "Invalid GitHub URL"
            return
        }
        guard !catalogs.contains(where: { $0.url == url }) else {
            errorMessage = "Catalog already added"
            return
        }
        catalogs.append(catalog)

        // Switch to the new catalog and load skills
        selectedSource = .remote(repoId: catalog.id)
        Task { await loadSkills() }
    }

    /// Remove a catalog and delete its cached clone
    public func removeCatalog(_ catalog: SkillsCatalog) {
        catalogs.removeAll { $0.id == catalog.id }

        // Delete the cloned repository from cache
        do {
            try ClonedRepoSkillRepository.deleteClone(forRepoUrl: catalog.url)
            print("[SkillLibrary] Deleted cached clone for: \(catalog.name)")
        } catch {
            print("[SkillLibrary] Failed to delete cached clone for \(catalog.name): \(error)")
        }

        // If we were viewing that catalog, switch to local
        if case .remote(let catalogId) = selectedSource, catalogId == catalog.id {
            selectedSource = .local
        }
    }

    // MARK: - Persistence

    private static let catalogsKey = "skillsManager.catalogs"

    private static func loadCatalogs() -> [SkillsCatalog] {
        guard let data = UserDefaults.standard.data(forKey: catalogsKey),
              let catalogs = try? JSONDecoder().decode([SkillsCatalog].self, from: data) else {
            // Return default catalogs
            return [.anthropicSkills]
        }
        return catalogs
    }

    private func saveCatalogs() {
        if let data = try? JSONEncoder().encode(catalogs) {
            UserDefaults.standard.set(data, forKey: Self.catalogsKey)
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

            // Merge local skills - use uniqueKey for matching with remote
            var merged: [String: Skill] = [:]

            for skill in claude {
                merged[skill.uniqueKey] = skill.installing(for: .claude)
            }

            for skill in codex {
                if var existing = merged[skill.uniqueKey] {
                    existing = existing.installing(for: .codex)
                    merged[skill.uniqueKey] = existing
                } else {
                    merged[skill.uniqueKey] = skill.installing(for: .codex)
                }
            }

            // Load remote skills from all catalogs using git clone
            for catalog in catalogs {
                do {
                    print("[SkillLibrary] Loading skills from: \(catalog.name) (\(catalog.url)) via git clone")
                    let remoteRepo = ClonedRepoSkillRepository(repoUrl: catalog.url)
                    let remoteSkills = try await remoteRepo.fetchAll()
                    print("[SkillLibrary] Found \(remoteSkills.count) skills in \(catalog.name)")

                    for skill in remoteSkills {
                        // Use uniqueKey (repoPath + id) for deduplication
                        let key = "\(catalog.id)-\(skill.uniqueKey)"
                        // Match by uniqueKey to sync installation status
                        if let existing = merged[skill.uniqueKey] {
                            // Merge remote skill with local installation status
                            merged[key] = skill.withInstalledProviders(existing.installedProviders)
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
                    errorMessage = "Error loading \(catalog.name): \(errorDesc)"
                    print("Failed to load from \(catalog.name): \(error)")
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

    /// Install selected skill to providers
    public func install(to providers: Set<Provider>) async {
        guard let skill = selectedSkill else { return }

        isLoading = true

        do {
            let updatedSkill = try await installer.install(skill, to: providers)

            // Update installedProviders on all matching skills (remote views)
            for index in skills.indices {
                if skills[index].uniqueKey == skill.uniqueKey {
                    skills[index] = skills[index].withInstalledProviders(updatedSkill.installedProviders)
                }
            }

            // Add local skill entry if not exists (for local view)
            if !skills.contains(where: { $0.source.isLocal && $0.uniqueKey == skill.uniqueKey }) {
                let localSkill = Skill(
                    id: skill.id,
                    name: skill.name,
                    description: skill.description,
                    version: skill.version,
                    content: skill.content,
                    source: .local(provider: providers.first!),
                    repoPath: skill.repoPath,
                    installedProviders: updatedSkill.installedProviders
                )
                skills.append(localSkill)
                skills.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }

            selectedSkill = updatedSkill

        } catch {
            errorMessage = "Installation failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Uninstall selected skill from a provider
    public func uninstall(from provider: Provider) async {
        guard let skill = selectedSkill else { return }

        isLoading = true

        do {
            let updatedSkill = try await installer.uninstall(skill, from: provider)

            // Update installedProviders on all matching skills
            for index in skills.indices {
                if skills[index].uniqueKey == skill.uniqueKey {
                    skills[index] = skills[index].withInstalledProviders(updatedSkill.installedProviders)
                }
            }

            // Remove local skill entry if fully uninstalled
            if updatedSkill.installedProviders.isEmpty {
                skills.removeAll { $0.source.isLocal && $0.uniqueKey == skill.uniqueKey }
            }

            selectedSkill = updatedSkill

        } catch {
            errorMessage = "Uninstall failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Editing

    /// Start editing the selected skill
    public func startEditing() {
        guard let skill = selectedSkill, skill.isEditable else { return }
        skillEditor = SkillEditor(skill: skill, writer: writerFactory())
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
