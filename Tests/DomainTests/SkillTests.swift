import Testing
import Foundation
@testable import Domain

@Suite
struct SkillTests {

    // MARK: - Basic Properties

    @Test func `skill has name and description`() {
        let skill = Skill(
            id: "apple-calendar",
            name: "Apple Calendar CLI",
            description: "Interact with Apple Calendar on macOS",
            version: "1.0.0",
            content: "# Apple Calendar CLI",
            source: .remote(repoUrl: "https://github.com/example/skills")
        )

        #expect(skill.name == "Apple Calendar CLI")
        #expect(skill.description == "Interact with Apple Calendar on macOS")
        #expect(skill.version == "1.0.0")
    }

    // MARK: - Installation Status

    @Test func `skill without installations shows empty providers`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "")
        )

        #expect(skill.installedProviders.isEmpty)
        #expect(skill.isInstalled == false)
    }

    @Test func `skill with codex installation shows codex provider`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.codex]
        )

        #expect(skill.installedProviders.contains(.codex))
        #expect(skill.isInstalled == true)
    }

    @Test func `skill with both installations shows both providers`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.codex, .claude]
        )

        #expect(skill.installedProviders.count == 2)
        #expect(skill.isInstalledFor(.codex) == true)
        #expect(skill.isInstalledFor(.claude) == true)
    }

    // MARK: - Source

    @Test func `local skill has local source`() {
        let skill = Skill(
            id: "local-skill",
            name: "Local Skill",
            description: "A local skill",
            version: "1.0.0",
            content: "",
            source: .local(provider: .claude)
        )

        #expect(skill.source.isLocal)
        #expect(skill.source.isRemote == false)
    }

    @Test func `remote skill has remote source`() {
        let skill = Skill(
            id: "remote-skill",
            name: "Remote Skill",
            description: "A remote skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "https://github.com/example/skills")
        )

        #expect(skill.source.isRemote)
        #expect(skill.source.isLocal == false)
    }

    // MARK: - Metadata

    @Test func `skill tracks reference count`() {
        let skill = Skill(
            id: "skill-with-refs",
            name: "Skill With References",
            description: "Has references",
            version: "1.0.0",
            content: "",
            source: .local(provider: .codex),
            referenceCount: 3
        )

        #expect(skill.referenceCount == 3)
        #expect(skill.hasReferences)
    }

    @Test func `skill tracks script count`() {
        let skill = Skill(
            id: "skill-with-scripts",
            name: "Skill With Scripts",
            description: "Has scripts",
            version: "1.0.0",
            content: "",
            source: .local(provider: .codex),
            scriptCount: 2
        )

        #expect(skill.scriptCount == 2)
        #expect(skill.hasScripts)
    }

    @Test func `skill without extras has no references or scripts`() {
        let skill = Skill(
            id: "basic-skill",
            name: "Basic",
            description: "Basic skill",
            version: "1.0.0",
            content: "",
            source: .local(provider: .codex)
        )

        #expect(skill.referenceCount == 0)
        #expect(skill.scriptCount == 0)
        #expect(skill.hasReferences == false)
        #expect(skill.hasScripts == false)
    }

    // MARK: - Mutation Methods

    @Test func `installing adds provider to installed providers`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "")
        )

        let updated = skill.installing(for: .claude)

        #expect(updated.isInstalledFor(.claude) == true)
        #expect(updated.isInstalledFor(.codex) == false)
    }

    @Test func `uninstalling removes provider from installed providers`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.claude, .codex]
        )

        let updated = skill.uninstalling(from: .claude)

        #expect(updated.isInstalledFor(.claude) == false)
        #expect(updated.isInstalledFor(.codex) == true)
    }
}

// MARK: - SkillSource Tests

@Suite
struct SkillSourceTests {

    @Test func `local source returns provider display name`() {
        let source = SkillSource.local(provider: .claude)

        #expect(source.displayName == "Claude Code")
    }

    @Test func `remote source returns repo name from URL`() {
        let source = SkillSource.remote(repoUrl: "https://github.com/anthropics/skills")

        #expect(source.displayName == "skills")
    }

    @Test func `remote source with empty URL returns Remote`() {
        let source = SkillSource.remote(repoUrl: "")

        #expect(source.displayName == "Remote")
    }
}

// MARK: - SkillsRepo Tests

@Suite
struct SkillsRepoTests {

    @Test func `extracts name from GitHub URL`() {
        let repo = SkillsRepo(url: "https://github.com/anthropics/skills")

        #expect(repo.name == "Skills")
    }

    @Test func `extracts name from URL with trailing slash`() {
        let repo = SkillsRepo(url: "https://github.com/owner/repo/")

        #expect(repo.name == "Repo")
    }

    @Test func `extracts name from URL with .git suffix`() {
        let repo = SkillsRepo(url: "https://github.com/owner/repo.git")

        #expect(repo.name == "Repo")
    }

    @Test func `uses provided name over extracted name`() {
        let repo = SkillsRepo(url: "https://github.com/anthropics/skills", name: "Custom Name")

        #expect(repo.name == "Custom Name")
    }

    @Test func `validates GitHub URL`() {
        let validRepo = SkillsRepo(url: "https://github.com/owner/repo")
        let invalidRepo = SkillsRepo(url: "https://example.com/repo")

        #expect(validRepo.isValid == true)
        #expect(invalidRepo.isValid == false)
    }

    @Test func `anthropicSkills has correct values`() {
        let repo = SkillsRepo.anthropicSkills

        #expect(repo.url == "https://github.com/anthropics/skills")
        #expect(repo.name == "Anthropic Skills")
    }

    @Test func `returns Unknown for empty URL`() {
        let name = SkillsRepo.extractName(from: "")

        #expect(name == "Unknown")
    }

    @Test func `handles http URL`() {
        let name = SkillsRepo.extractName(from: "http://github.com/owner/repo")

        #expect(name == "Repo")
    }
}
