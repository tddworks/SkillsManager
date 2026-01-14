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

    @Test func `install adds local skill entry when installing remote skill`() async {
        let remoteSkill = makeRemoteSkill(id: "test-skill")
        let mockInstaller = MockSkillInstaller()

        given(mockInstaller).install(.any, to: .any).willReturn(remoteSkill.installing(for: .claude))

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [remoteSkill]
        library.selectedSkill = remoteSkill

        await library.install(to: [.claude])

        // Should have 2 skills: original remote + new local entry
        #expect(library.skills.count == 2)
        #expect(library.skills.contains { $0.source.isLocal && $0.uniqueKey == remoteSkill.uniqueKey })
    }

    @Test func `install updates installedProviders on matching skills`() async {
        let remoteSkill = makeRemoteSkill(id: "test-skill")
        let mockInstaller = MockSkillInstaller()

        given(mockInstaller).install(.any, to: .any).willReturn(remoteSkill.installing(for: .claude))

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [remoteSkill]
        library.selectedSkill = remoteSkill

        await library.install(to: [.claude])

        // Remote skill should have updated installedProviders
        let updatedRemote = library.skills.first { !$0.source.isLocal }
        #expect(updatedRemote?.installedProviders.contains(.claude) == true)
    }

    @Test func `install does not add duplicate local entry`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
        let mockInstaller = MockSkillInstaller()

        // Installer returns skill with both providers installed
        given(mockInstaller).install(.any, to: .any).willReturn(localSkill.installing(for: .codex))

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [localSkill]
        library.selectedSkill = localSkill

        await library.install(to: [.codex])

        // Should still have only 1 skill (no duplicate)
        #expect(library.skills.count == 1)
        #expect(library.skills.first?.installedProviders == [.claude, .codex])
    }

    @Test func `install sets error message on failure`() async {
        let skill = makeRemoteSkill(id: "test-skill")
        let mockInstaller = MockSkillInstaller()

        given(mockInstaller).install(.any, to: .any).willThrow(MockError.installFailed)

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [skill]
        library.selectedSkill = skill

        await library.install(to: [.claude])

        #expect(library.errorMessage?.contains("Installation failed") == true)
    }

    // MARK: - Uninstall Tests

    @Test func `uninstall removes local skill entry when fully uninstalled`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
        let mockInstaller = MockSkillInstaller()

        given(mockInstaller).uninstall(.any, from: .any).willReturn(localSkill.uninstalling(from: .claude))

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [localSkill]
        library.selectedSkill = localSkill

        await library.uninstall(from: .claude)

        // Local skill should be removed
        #expect(library.skills.isEmpty)
    }

    @Test func `uninstall keeps local skill entry when partially installed`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
            .installing(for: .codex)
        let mockInstaller = MockSkillInstaller()

        given(mockInstaller).uninstall(.any, from: .any).willReturn(localSkill.uninstalling(from: .claude))

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [localSkill]
        library.selectedSkill = localSkill

        await library.uninstall(from: .claude)

        // Local skill should remain (still installed for codex)
        #expect(library.skills.count == 1)
        #expect(library.skills.first?.installedProviders == [.codex])
    }

    @Test func `uninstall updates installedProviders on all matching skills`() async {
        let localSkill = makeLocalSkill(id: "test-skill", provider: .claude)
            .installing(for: .claude)
        let remoteSkill = makeRemoteSkill(id: "test-skill")
            .installing(for: .claude)
        let mockInstaller = MockSkillInstaller()

        given(mockInstaller).uninstall(.any, from: .any).willReturn(localSkill.uninstalling(from: .claude))

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [localSkill, remoteSkill]
        library.selectedSkill = localSkill

        await library.uninstall(from: .claude)

        // Remote skill should have updated installedProviders
        let updatedRemote = library.skills.first { !$0.source.isLocal }
        #expect(updatedRemote?.installedProviders.isEmpty == true)
    }

    @Test func `uninstall sets error message on failure`() async {
        let skill = makeLocalSkill(id: "test-skill", provider: .claude)
        let mockInstaller = MockSkillInstaller()

        given(mockInstaller).uninstall(.any, from: .any).willThrow(MockError.uninstallFailed)

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: mockInstaller
        )
        library.skills = [skill]
        library.selectedSkill = skill

        await library.uninstall(from: .claude)

        #expect(library.errorMessage?.contains("Uninstall failed") == true)
    }

    // MARK: - Filtered Skills Tests

    @Test func `filteredSkills returns local skills when source is local`() async {
        let localSkill = makeLocalSkill(id: "local", provider: .claude)
        let remoteSkill = makeRemoteSkill(id: "remote")

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: MockSkillInstaller()
        )
        library.skills = [localSkill, remoteSkill]
        library.selectedSource = .local

        #expect(library.filteredSkills.count == 1)
        #expect(library.filteredSkills.first?.id == "local")
    }

    @Test func `filteredSkills filters by search query`() async {
        let skill1 = makeLocalSkill(id: "alpha", provider: .claude, name: "Alpha Skill")
        let skill2 = makeLocalSkill(id: "beta", provider: .claude, name: "Beta Skill")

        let library = SkillLibrary(
            claudeRepo: MockSkillRepository(),
            codexRepo: MockSkillRepository(),
            installer: MockSkillInstaller()
        )
        library.skills = [skill1, skill2]
        library.selectedSource = .local
        library.searchQuery = "Alpha"

        #expect(library.filteredSkills.count == 1)
        #expect(library.filteredSkills.first?.id == "alpha")
    }

    // MARK: - Helpers

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
