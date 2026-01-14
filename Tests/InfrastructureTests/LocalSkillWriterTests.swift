import Testing
import Foundation
@testable import Domain
@testable import Infrastructure

@Suite
struct LocalSkillWriterTests {

    // MARK: - Validation

    @Test func `save throws error for remote skill`() async throws {
        let remoteSkill = Skill(
            id: "remote-skill",
            name: "Remote",
            description: "Remote skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/skills")
        )
        let writer = LocalSkillWriter()

        await #expect(throws: SkillWriterError.notLocalSkill) {
            try await writer.save(remoteSkill)
        }
    }

    // MARK: - File Writing

    @Test func `save writes content to correct path for claude provider`() async throws {
        let skill = Skill(
            id: "my-skill",
            name: "My Skill",
            description: "Test",
            version: "1.0.0",
            content: "# Updated content",
            source: .local(provider: .claude)
        )

        // Create temp directory structure
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let skillDir = tempDir.appendingPathComponent("my-skill")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        let skillPath = skillDir.appendingPathComponent("SKILL.md")
        try "# Original".write(to: skillPath, atomically: true, encoding: .utf8)

        // Use custom base path
        let writer = LocalSkillWriter(basePath: tempDir.path)
        try await writer.save(skill)

        // Verify content was written
        let savedContent = try String(contentsOf: skillPath, encoding: .utf8)
        #expect(savedContent == "# Updated content")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func `save throws error when skill directory does not exist`() async throws {
        let skill = Skill(
            id: "nonexistent-skill",
            name: "Nonexistent",
            description: "Test",
            version: "1.0.0",
            content: "# Content",
            source: .local(provider: .claude)
        )

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let writer = LocalSkillWriter(basePath: tempDir.path)

        await #expect(throws: SkillWriterError.self) {
            try await writer.save(skill)
        }
    }
}
