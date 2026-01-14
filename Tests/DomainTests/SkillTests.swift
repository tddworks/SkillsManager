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

    // MARK: - Rich Installation Status (User Mental Model)

    @Test func `availableProviders returns providers not yet installed`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.claude]
        )

        // User thinks: "Where else can I install this?"
        #expect(skill.availableProviders == [.codex])
    }

    @Test func `availableProviders returns all providers when nothing installed`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: []
        )

        #expect(skill.availableProviders.count == 2)
        #expect(skill.availableProviders.contains(.claude))
        #expect(skill.availableProviders.contains(.codex))
    }

    @Test func `availableProviders returns empty when fully installed`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.claude, .codex]
        )

        // User thinks: "Can I install this anywhere else?" → No
        #expect(skill.availableProviders.isEmpty)
    }

    @Test func `isFullyInstalled returns true when installed in all providers`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.claude, .codex]
        )

        // User thinks: "Is this installed everywhere?"
        #expect(skill.isFullyInstalled == true)
    }

    @Test func `isFullyInstalled returns false when partially installed`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.claude]
        )

        #expect(skill.isFullyInstalled == false)
    }

    @Test func `canBeInstalled returns true when there are available providers`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.claude]
        )

        // User thinks: "Can I install this somewhere?"
        #expect(skill.canBeInstalled == true)
    }

    @Test func `canBeInstalled returns false when fully installed`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            installedProviders: [.claude, .codex]
        )

        #expect(skill.canBeInstalled == false)
    }

    // MARK: - Search (User Mental Model)

    @Test func `matches returns true when query matches name`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "Professional UI design",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "")
        )

        // User thinks: "Does this skill match my search?"
        #expect(skill.matches(query: "UI") == true)
        #expect(skill.matches(query: "pro") == true)
        #expect(skill.matches(query: "ux") == true)
    }

    @Test func `matches returns true when query matches description`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "Professional UI design",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "")
        )

        #expect(skill.matches(query: "design") == true)
        #expect(skill.matches(query: "professional") == true)
    }

    @Test func `matches returns false when query matches nothing`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "Professional UI design",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "")
        )

        #expect(skill.matches(query: "calendar") == false)
    }

    @Test func `matches returns true for empty query`() {
        let skill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "")
        )

        // Empty query matches everything
        #expect(skill.matches(query: "") == true)
    }

    // MARK: - Factory Methods (User Mental Model)

    @Test func `withInstalledProviders returns skill with merged installation status`() {
        let remoteSkill = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/skills"),
            installedProviders: []
        )

        // User thinks: "This remote skill is actually installed locally"
        let mergedSkill = remoteSkill.withInstalledProviders([.claude, .codex])

        #expect(mergedSkill.installedProviders == [.claude, .codex])
        #expect(mergedSkill.id == remoteSkill.id)
        #expect(mergedSkill.name == remoteSkill.name)
        #expect(mergedSkill.source == remoteSkill.source)
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

    // MARK: - Editable

    @Test func `local skill is editable`() {
        let skill = Skill(
            id: "local-skill",
            name: "Local Skill",
            description: "A local skill",
            version: "1.0.0",
            content: "# Content",
            source: .local(provider: .claude)
        )

        #expect(skill.isEditable == true)
    }

    @Test func `remote skill is not editable`() {
        let skill = Skill(
            id: "remote-skill",
            name: "Remote Skill",
            description: "A remote skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/skills")
        )

        #expect(skill.isEditable == false)
    }

    @Test func `updating content returns new skill with updated content`() {
        let original = Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: "# Original Content",
            source: .local(provider: .claude),
            installedProviders: [.claude],
            referenceCount: 2,
            scriptCount: 1
        )

        let updated = original.updating(content: "# Updated Content")

        #expect(updated.content == "# Updated Content")
        #expect(updated.id == original.id)
        #expect(updated.name == original.name)
        #expect(updated.description == original.description)
        #expect(updated.version == original.version)
        #expect(updated.source == original.source)
        #expect(updated.installedProviders == original.installedProviders)
        #expect(updated.referenceCount == original.referenceCount)
        #expect(updated.scriptCount == original.scriptCount)
    }

    // MARK: - Display Name

    @Test func `local skill displayName is just the name`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "",
            source: .local(provider: .claude),
            repoPath: ".claude/skills"  // Even if repoPath is set, local shows just name
        )

        #expect(skill.displayName == "UI/UX Pro Max")
    }

    @Test func `remote skill without repoPath displayName is just the name`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "https://github.com/example/skills"),
            repoPath: nil
        )

        #expect(skill.displayName == "UI/UX Pro Max")
    }

    @Test func `remote skill with repoPath displayName shows path context`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "https://github.com/example/skills"),
            repoPath: ".claude/skills"
        )

        #expect(skill.displayName == "UI/UX Pro Max (.claude/skills)")
    }

    // MARK: - Unique Key

    @Test func `uniqueKey without repoPath is just the id`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            repoPath: nil
        )

        #expect(skill.uniqueKey == "ui-ux-pro-max")
    }

    @Test func `uniqueKey with repoPath combines path and id`() {
        let skill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: ""),
            repoPath: ".claude/skills"
        )

        #expect(skill.uniqueKey == ".claude/skills/ui-ux-pro-max")
    }

    // MARK: - List ID (Prevents SwiftUI Collisions)

    @Test func `listId for local skill includes provider`() {
        let skill = Skill(
            id: "my-skill",
            name: "My Skill",
            description: "A skill",
            version: "1.0.0",
            content: "",
            source: .local(provider: .claude)
        )

        #expect(skill.listId.contains("local"))
        #expect(skill.listId.contains("claude"))
        #expect(skill.listId.contains("my-skill"))
    }

    @Test func `listId for remote skills from different catalogs are unique`() {
        let skillFromCatalogA = Skill(
            id: "seo-review",
            name: "SEO Review",
            description: "SEO skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "https://github.com/anthropics/skills"),
            repoPath: ".claude/skills"
        )

        let skillFromCatalogB = Skill(
            id: "seo-review",
            name: "SEO Review",
            description: "SEO skill",
            version: "1.0.0",
            content: "",
            source: .remote(repoUrl: "https://github.com/other/skills"),
            repoPath: ".claude/skills"
        )

        // Same uniqueKey (for deduplication)
        #expect(skillFromCatalogA.uniqueKey == skillFromCatalogB.uniqueKey)

        // Different listId (for SwiftUI)
        #expect(skillFromCatalogA.listId != skillFromCatalogB.listId)
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

// MARK: - SkillsCatalog Tests

@Suite
@MainActor
struct SkillsCatalogTests {

    @Test func `extracts name from GitHub URL`() {
        let catalog = SkillsCatalog(url: "https://github.com/anthropics/skills", loader: MockSkillRepository())

        #expect(catalog.name == "Skills")
    }

    @Test func `extracts name from URL with trailing slash`() {
        let catalog = SkillsCatalog(url: "https://github.com/owner/repo/", loader: MockSkillRepository())

        #expect(catalog.name == "Repo")
    }

    @Test func `extracts name from URL with .git suffix`() {
        let catalog = SkillsCatalog(url: "https://github.com/owner/repo.git", loader: MockSkillRepository())

        #expect(catalog.name == "Repo")
    }

    @Test func `uses provided name over extracted name`() {
        let catalog = SkillsCatalog(url: "https://github.com/anthropics/skills", name: "Custom Name", loader: MockSkillRepository())

        #expect(catalog.name == "Custom Name")
    }

    @Test func `validates GitHub URL`() {
        let validCatalog = SkillsCatalog(url: "https://github.com/owner/repo", loader: MockSkillRepository())
        let invalidCatalog = SkillsCatalog(url: "https://example.com/repo", loader: MockSkillRepository())

        #expect(validCatalog.isValid == true)
        #expect(invalidCatalog.isValid == false)
    }

    @Test func `anthropicSkills data has correct values`() {
        let data = SkillsCatalog.Data.anthropicSkills

        #expect(data.url == "https://github.com/anthropics/skills")
        #expect(data.name == "Anthropic Skills")
    }

    @Test func `isOfficial returns true for official catalog`() {
        let catalog = SkillsCatalog(
            id: SkillsCatalog.officialAnthropicId,
            url: "https://github.com/anthropics/skills",
            loader: MockSkillRepository()
        )

        #expect(catalog.isOfficial == true)
    }

    @Test func `isOfficial returns false for custom catalog`() {
        let catalog = SkillsCatalog(url: "https://github.com/my-org/skills", loader: MockSkillRepository())

        #expect(catalog.isOfficial == false)
    }

    @Test func `returns Unknown for empty URL`() {
        let name = SkillsCatalog.extractName(from: "")

        #expect(name == "Unknown")
    }

    @Test func `handles http URL`() {
        let name = SkillsCatalog.extractName(from: "http://github.com/owner/repo")

        #expect(name == "Repo")
    }

    @Test func `isLocal returns true for catalog without URL`() {
        let catalog = SkillsCatalog(name: "Local", loader: MockSkillRepository())

        #expect(catalog.isLocal == true)
    }

    @Test func `isLocal returns false for catalog with URL`() {
        let catalog = SkillsCatalog(url: "https://github.com/owner/repo", loader: MockSkillRepository())

        #expect(catalog.isLocal == false)
    }
}
