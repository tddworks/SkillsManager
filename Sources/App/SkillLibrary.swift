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
        self.catalogs = Self.loadCatalogs()
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
        showingAddRepoSheet = false

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
                            // Mark remote version with installation status from local
                            let remoteVersion = Skill(
                                id: skill.id,
                                name: skill.name,
                                description: skill.description,
                                version: skill.version,
                                content: skill.content,
                                source: skill.source,
                                repoPath: skill.repoPath,
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
