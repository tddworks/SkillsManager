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
}
