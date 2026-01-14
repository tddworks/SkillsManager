import SwiftUI
import Domain
import Infrastructure

/// The user's skill library - browse, search, and manage skills
@Observable
@MainActor
public final class SkillLibrary {

    // MARK: - Catalogs

    /// Local catalog (installed skills from claude/codex)
    public let localCatalog: SkillsCatalog

    /// Remote catalogs (GitHub repos)
    public var remoteCatalogs: [SkillsCatalog] = []

    /// All catalogs for UI iteration
    public var catalogs: [SkillsCatalog] {
        [localCatalog] + remoteCatalogs
    }

    // MARK: - Selection State

    /// Currently selected skill
    public var selectedSkill: Skill?

    /// Current source filter
    public var selectedSource: SourceFilter = .local

    /// Search query
    public var searchQuery: String = ""

    // MARK: - Loading State

    /// Loading state - computed from selected catalog
    public var isLoading: Bool {
        selectedCatalog.isLoading
    }

    /// Error message
    public var errorMessage: String?

    // MARK: - Editing

    /// The skill editor for editing local skills
    public var skillEditor: SkillEditor?

    /// Whether edit mode is active
    public var isEditing: Bool {
        skillEditor != nil
    }

    // MARK: - Computed Properties

    /// Currently selected catalog
    public var selectedCatalog: SkillsCatalog {
        switch selectedSource {
        case .local:
            return localCatalog
        case .remote(let catalogId):
            return remoteCatalogs.first { $0.id == catalogId } ?? localCatalog
        }
    }

    /// Filtered skills based on source and search
    public var filteredSkills: [Skill] {
        let sourceSkills = selectedCatalog.skills
        guard !searchQuery.isEmpty else { return sourceSkills }
        return sourceSkills.filter { $0.matches(query: searchQuery) }
    }

    /// Count of local skills
    public var localSkillCount: Int {
        localCatalog.skills.count
    }

    // MARK: - Dependencies

    private let installer: SkillInstaller
    private let writerFactory: () -> SkillWriter
    private let catalogLoaderFactory: (String) -> SkillRepository
    private let cacheCleaner: (String) throws -> Void

    // MARK: - Init

    public init() {
        let claudeRepo = LocalSkillRepository(provider: .claude)
        let codexRepo = LocalSkillRepository(provider: .codex)
        let localLoader = MergedSkillRepository.forLocalSkills(
            claudeRepo: claudeRepo,
            codexRepo: codexRepo
        )

        self.localCatalog = SkillsCatalog(
            id: SkillsCatalog.localCatalogId,
            name: "Local",
            loader: localLoader
        )

        self.installer = FileSystemSkillInstaller()
        self.writerFactory = { LocalSkillWriter() }
        self.catalogLoaderFactory = { ClonedRepoSkillRepository(repoUrl: $0) }
        self.cacheCleaner = { try ClonedRepoSkillRepository.deleteClone(forRepoUrl: $0) }
        self.remoteCatalogs = Self.loadRemoteCatalogs(loaderFactory: catalogLoaderFactory)
    }

    /// Testable initializer with dependency injection
    public init(
        localCatalog: SkillsCatalog,
        remoteCatalogs: [SkillsCatalog] = [],
        installer: SkillInstaller,
        writerFactory: @escaping () -> SkillWriter = { LocalSkillWriter() },
        catalogLoaderFactory: @escaping (String) -> SkillRepository = { ClonedRepoSkillRepository(repoUrl: $0) },
        cacheCleaner: @escaping (String) throws -> Void = { try ClonedRepoSkillRepository.deleteClone(forRepoUrl: $0) }
    ) {
        self.localCatalog = localCatalog
        self.remoteCatalogs = remoteCatalogs
        self.installer = installer
        self.writerFactory = writerFactory
        self.catalogLoaderFactory = catalogLoaderFactory
        self.cacheCleaner = cacheCleaner
    }

    // MARK: - Catalog Management

    /// Add a new remote catalog
    public func addCatalog(url: String) {
        let catalog = SkillsCatalog(
            url: url,
            loader: catalogLoaderFactory(url)
        )
        guard catalog.isValid else {
            errorMessage = "Invalid GitHub URL"
            return
        }
        guard !remoteCatalogs.contains(where: { $0.url == url }) else {
            errorMessage = "Catalog already added"
            return
        }
        remoteCatalogs.append(catalog)
        saveRemoteCatalogs()

        // Switch to the new catalog and load skills
        selectedSource = .remote(repoId: catalog.id)
        Task { await catalog.loadSkills() }
    }

    /// Remove a remote catalog
    public func removeCatalog(_ catalog: SkillsCatalog) {
        guard !catalog.isLocal else { return }  // Can't remove local catalog
        guard let url = catalog.url else { return }

        remoteCatalogs.removeAll { $0.id == catalog.id }
        saveRemoteCatalogs()

        // Delete the cloned repository from cache
        do {
            try cacheCleaner(url)
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

    private static func loadRemoteCatalogs(
        loaderFactory: @escaping (String) -> SkillRepository
    ) -> [SkillsCatalog] {
        guard let data = UserDefaults.standard.data(forKey: catalogsKey),
              let catalogsData = try? JSONDecoder().decode([SkillsCatalog.Data].self, from: data) else {
            // Return default Anthropic catalog
            return [
                SkillsCatalog(
                    from: .anthropicSkills,
                    loader: loaderFactory(SkillsCatalog.Data.anthropicSkills.url!)
                )
            ]
        }
        return catalogsData.compactMap { catalogData in
            guard let url = catalogData.url else { return nil }
            return SkillsCatalog(
                from: catalogData,
                loader: loaderFactory(url)
            )
        }
    }

    private func saveRemoteCatalogs() {
        let catalogsData = remoteCatalogs.map { $0.persistableData }
        if let data = try? JSONEncoder().encode(catalogsData) {
            UserDefaults.standard.set(data, forKey: Self.catalogsKey)
        }
    }

    // MARK: - Actions

    /// Load skills from all catalogs
    public func loadSkills() async {
        errorMessage = nil

        // Load all catalogs in parallel
        await withTaskGroup(of: Void.self) { group in
            for catalog in catalogs {
                group.addTask {
                    await catalog.loadSkills()
                }
            }
        }

        // Sync installation status on remote catalog skills
        syncInstallationStatus()
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

        do {
            let updatedSkill = try await installer.install(skill, to: providers)

            updateInstallationStatus(for: skill.uniqueKey, to: updatedSkill.installedProviders)
            addToLocalCatalog(skill, providers: updatedSkill.installedProviders)
            selectedSkill = updatedSkill

        } catch {
            errorMessage = "Installation failed: \(error.localizedDescription)"
        }
    }

    /// Uninstall selected skill from a provider
    public func uninstall(from provider: Provider) async {
        guard let skill = selectedSkill else { return }

        do {
            let updatedSkill = try await installer.uninstall(skill, from: provider)

            updateInstallationStatus(for: skill.uniqueKey, to: updatedSkill.installedProviders)

            if updatedSkill.installedProviders.isEmpty {
                removeFromLocalCatalog(uniqueKey: skill.uniqueKey)
            }

            selectedSkill = updatedSkill

        } catch {
            errorMessage = "Uninstall failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Installation Status Sync

    /// Sync installation status from local catalog to remote catalogs
    private func syncInstallationStatus() {
        let localSkills = localCatalog.skills
        for catalog in remoteCatalogs {
            catalog.syncInstallationStatus(with: localSkills)
        }
    }

    /// Update installation status for all skills matching the uniqueKey
    private func updateInstallationStatus(for uniqueKey: String, to providers: Set<Provider>) {
        localCatalog.updateInstallationStatus(for: uniqueKey, to: providers)
        for catalog in remoteCatalogs {
            catalog.updateInstallationStatus(for: uniqueKey, to: providers)
        }
    }

    /// Add skill to local catalog (creates entry if not exists)
    private func addToLocalCatalog(_ skill: Skill, providers: Set<Provider>) {
        let localSkill = Skill(
            id: skill.id,
            name: skill.name,
            description: skill.description,
            version: skill.version,
            content: skill.content,
            source: .local(provider: providers.first!),
            repoPath: skill.repoPath,
            installedProviders: providers
        )
        localCatalog.addSkill(localSkill)
    }

    /// Remove skill from local catalog
    private func removeFromLocalCatalog(uniqueKey: String) {
        localCatalog.removeSkill(uniqueKey: uniqueKey)
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

            localCatalog.updateSkill(savedSkill)
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
