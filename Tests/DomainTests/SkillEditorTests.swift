import Testing
import Foundation
@testable import Domain

@Suite
@MainActor
struct SkillEditorTests {

    // MARK: - Initialization

    @Test func `editor initializes with skill content as draft`() async {
        let skill = makeLocalSkill(content: "# Original Content")
        let editor = SkillEditor(skill: skill, writer: MockSkillWriter())

        #expect(editor.draft == "# Original Content")
        #expect(editor.original.id == skill.id)
    }

    // MARK: - Editable State

    @Test func `editor for local skill is editable`() async {
        let skill = makeLocalSkill()
        let editor = SkillEditor(skill: skill, writer: MockSkillWriter())

        #expect(editor.canEdit == true)
    }

    @Test func `editor for remote skill is not editable`() async {
        let skill = makeRemoteSkill()
        let editor = SkillEditor(skill: skill, writer: MockSkillWriter())

        #expect(editor.canEdit == false)
    }

    // MARK: - Dirty State

    @Test func `editor is not dirty when draft matches original`() async {
        let skill = makeLocalSkill(content: "# Content")
        let editor = SkillEditor(skill: skill, writer: MockSkillWriter())

        #expect(editor.isDirty == false)
    }

    @Test func `editor is dirty when draft differs from original`() async {
        let skill = makeLocalSkill(content: "# Original")
        let editor = SkillEditor(skill: skill, writer: MockSkillWriter())

        editor.draft = "# Modified"

        #expect(editor.isDirty == true)
    }

    // MARK: - Reset

    @Test func `reset restores draft to original content`() async {
        let skill = makeLocalSkill(content: "# Original")
        let editor = SkillEditor(skill: skill, writer: MockSkillWriter())
        editor.draft = "# Modified"

        editor.reset()

        #expect(editor.draft == "# Original")
        #expect(editor.isDirty == false)
    }

    // MARK: - Save

    @Test func `save throws error when skill is not editable`() async throws {
        let skill = makeRemoteSkill()
        let mockWriter = MockSkillWriter()
        let editor = SkillEditor(skill: skill, writer: mockWriter)

        await #expect(throws: SkillEditorError.notEditable) {
            try await editor.save()
        }
    }

    @Test func `save delegates to writer with updated skill`() async throws {
        let skill = makeLocalSkill(content: "# Original")
        let mockWriter = MockSkillWriter()
        let editor = SkillEditor(skill: skill, writer: mockWriter)
        editor.draft = "# Updated Content"

        _ = try await editor.save()

        #expect(mockWriter.savedSkill?.content == "# Updated Content")
    }

    @Test func `save updates original after successful write`() async throws {
        let skill = makeLocalSkill(content: "# Original")
        let mockWriter = MockSkillWriter()
        let editor = SkillEditor(skill: skill, writer: mockWriter)
        editor.draft = "# Updated Content"

        let saved = try await editor.save()

        #expect(saved.content == "# Updated Content")
        #expect(editor.original.content == "# Updated Content")
        #expect(editor.isDirty == false)
    }

    @Test func `save throws writer error on failure`() async throws {
        let skill = makeLocalSkill()
        let mockWriter = MockSkillWriter()
        mockWriter.shouldThrow = TestError.writeFailed
        let editor = SkillEditor(skill: skill, writer: mockWriter)

        await #expect(throws: TestError.writeFailed) {
            try await editor.save()
        }
    }

    // MARK: - Helpers

    private func makeLocalSkill(content: String = "# Test") -> Skill {
        Skill(
            id: "test-skill",
            name: "Test",
            description: "Test skill",
            version: "1.0.0",
            content: content,
            source: .local(provider: .claude)
        )
    }

    private func makeRemoteSkill() -> Skill {
        Skill(
            id: "remote-skill",
            name: "Remote",
            description: "Remote skill",
            version: "1.0.0",
            content: "# Remote",
            source: .remote(repoUrl: "https://github.com/example/skills")
        )
    }
}

// MARK: - Test Doubles

final class MockSkillWriter: SkillWriter, @unchecked Sendable {
    var savedSkill: Skill?
    var shouldThrow: Error?

    func save(_ skill: Skill) async throws {
        if let error = shouldThrow {
            throw error
        }
        savedSkill = skill
    }
}

enum TestError: Error {
    case writeFailed
}
