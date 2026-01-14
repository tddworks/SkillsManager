import Testing
import Foundation
import Mockable
@testable import App
@testable import Domain
@testable import Infrastructure

@Suite
@MainActor
struct SkillLibraryTests {

    // MARK: - Install Tests

    @Test func `install adds skill to local catalog when installing remote skill`() async {
        let remoteSkill = makeRemoteSkill(id: "test-skill")
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog()
        let remoteCatalog = makeRemoteCatalog(skills: [remoteSkill])

        given(mockInstaller).install(.any, to: .any).willReturn(remoteSkill.installing(for: .claude))

        let library = SkillLibrary(
            localCatalog: localCatalog,
            remoteCatalogs: [remoteCatalog],
            installer: mockInstaller
        )
        library.selectedSkill = remoteSkill

        await library.install(to: [.claude])

        // Should have 1 skill in local catalog
        #expect(localCatalog.skills.count == 1)
        #expect(localCatalog.skills.first?.uniqueKey == remoteSkill.uniqueKey)
    }

    @Test func `install updates installedProviders on remote catalog skill`() async {
        let remoteSkill = makeRemoteSkill(id: "test-skill")
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog()
        let remoteCatalog = makeRemoteCatalog(skills: [remoteSkill])

        given(mockInstaller).install(.any, to: .any).willReturn(remoteSkill.installing(for: .claude))

        let library = SkillLibrary(
            localCatalog: localCatalog,
            remoteCatalogs: [remoteCatalog],
            installer: mockInstaller
        )
        library.selectedSkill = remoteSkill

        await library.install(to: [.claude])

        // Remote skill should have updated installedProviders
        let updatedRemote = remoteCatalog.skills.first
        #expect(updatedRemote?.installedProviders.contains(.claude) == true)
    }

    @Test func `install does not add duplicate skill to local catalog`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog(skills: [localSkill])

        // Installer returns skill with both providers installed
        given(mockInstaller).install(.any, to: .any).willReturn(localSkill.installing(for: .codex))

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller
        )
        library.selectedSkill = localSkill

        await library.install(to: [.codex])

        // Should still have only 1 skill (no duplicate)
        #expect(localCatalog.skills.count == 1)
        #expect(localCatalog.skills.first?.installedProviders == [.claude, .codex])
    }

    @Test func `install sets error message on failure`() async {
        let skill = makeRemoteSkill(id: "test-skill")
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog()

        given(mockInstaller).install(.any, to: .any).willThrow(MockError.installFailed)

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller
        )
        library.selectedSkill = skill

        await library.install(to: [.claude])

        #expect(library.errorMessage?.contains("Installation failed") == true)
    }

    // MARK: - Uninstall Tests

    @Test func `uninstall removes skill from local catalog when fully uninstalled`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog(skills: [localSkill])

        given(mockInstaller).uninstall(.any, from: .any).willReturn(localSkill.uninstalling(from: .claude))

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller
        )
        library.selectedSkill = localSkill

        await library.uninstall(from: .claude)

        // Local skill should be removed
        #expect(localCatalog.skills.isEmpty)
    }

    @Test func `uninstall keeps skill in local catalog when partially installed`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
            .installing(for: .codex)
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog(skills: [localSkill])

        given(mockInstaller).uninstall(.any, from: .any).willReturn(localSkill.uninstalling(from: .claude))

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller
        )
        library.selectedSkill = localSkill

        await library.uninstall(from: .claude)

        // Local skill should remain (still installed for codex)
        #expect(localCatalog.skills.count == 1)
        #expect(localCatalog.skills.first?.installedProviders == [.codex])
    }

    @Test func `uninstall updates installedProviders on remote catalog skill`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
        let remoteSkill = makeRemoteSkill(id: "test-skill")
            .installing(for: .claude)
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog(skills: [localSkill])
        let remoteCatalog = makeRemoteCatalog(skills: [remoteSkill])

        given(mockInstaller).uninstall(.any, from: .any).willReturn(localSkill.uninstalling(from: .claude))

        let library = SkillLibrary(
            localCatalog: localCatalog,
            remoteCatalogs: [remoteCatalog],
            installer: mockInstaller
        )
        library.selectedSkill = localSkill

        await library.uninstall(from: .claude)

        // Remote skill should have updated installedProviders
        let updatedRemote = remoteCatalog.skills.first
        #expect(updatedRemote?.installedProviders.isEmpty == true)
    }

    @Test func `uninstall sets error message on failure`() async {
        let skill = makeLocalSkill(id: "test-skill", provider: .claude)
        let mockInstaller = MockSkillInstaller()
        let localCatalog = makeLocalCatalog(skills: [skill])

        given(mockInstaller).uninstall(.any, from: .any).willThrow(MockError.uninstallFailed)

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: mockInstaller
        )
        library.selectedSkill = skill

        await library.uninstall(from: .claude)

        #expect(library.errorMessage?.contains("Uninstall failed") == true)
    }

    // MARK: - Filtered Skills Tests

    @Test func `filteredSkills returns local catalog skills when source is local`() async {
        let localSkill = makeLocalSkill(id: "local", provider: .claude)
        let remoteSkill = makeRemoteSkill(id: "remote")
        let localCatalog = makeLocalCatalog(skills: [localSkill])
        let remoteCatalog = makeRemoteCatalog(skills: [remoteSkill])

        let library = SkillLibrary(
            localCatalog: localCatalog,
            remoteCatalogs: [remoteCatalog],
            installer: MockSkillInstaller()
        )
        library.selectedSource = .local

        #expect(library.filteredSkills.count == 1)
        #expect(library.filteredSkills.first?.id == "local")
    }

    @Test func `filteredSkills filters by search query`() async {
        let skill1 = makeLocalSkill(id: "alpha", provider: .claude, name: "Alpha Skill")
        let skill2 = makeLocalSkill(id: "beta", provider: .claude, name: "Beta Skill")
        let localCatalog = makeLocalCatalog(skills: [skill1, skill2])

        let library = SkillLibrary(
            localCatalog: localCatalog,
            installer: MockSkillInstaller()
        )
        library.selectedSource = .local
        library.searchQuery = "Alpha"

        #expect(library.filteredSkills.count == 1)
        #expect(library.filteredSkills.first?.id == "alpha")
    }

    // MARK: - Helpers

    private func makeLocalCatalog(skills: [Skill] = []) -> SkillsCatalog {
        let catalog = SkillsCatalog(
            id: SkillsCatalog.localCatalogId,
            name: "Local",
            loader: MockSkillRepository()
        )
        catalog.skills = skills
        return catalog
    }

    private func makeRemoteCatalog(skills: [Skill] = []) -> SkillsCatalog {
        let catalog = SkillsCatalog(
            url: "https://github.com/example/skills",
            loader: MockSkillRepository()
        )
        catalog.skills = skills
        return catalog
    }

    private func makeLocalSkill(
        id: String,
        provider: Provider,
        name: String = "Test Skill"
    ) -> Skill {
        Skill(
            id: id,
            name: name,
            description: "Test description",
            version: "1.0.0",
            content: "# Content",
            source: .local(provider: provider)
        )
    }

    private func makeRemoteSkill(id: String) -> Skill {
        Skill(
            id: id,
            name: "Remote Skill",
            description: "Remote description",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/skills")
        )
    }
}

// MARK: - Test Error

enum MockError: Error {
    case installFailed
    case uninstallFailed
}
