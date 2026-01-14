import Foundation
import Observation

/// Error thrown by SkillEditor operations
public enum SkillEditorError: Error, Sendable {
    case notEditable
}

/// Domain aggregate for editing a skill
///
/// Encapsulates editing behavior: draft state, save, and reset.
/// Uses method injection for the writer dependency.
@Observable
@MainActor
public final class SkillEditor: Sendable {
    private let writer: SkillWriter

    /// The original skill being edited
    public private(set) var original: Skill

    /// The draft content being edited
    public var draft: String

    /// Whether the skill can be edited (only local skills)
    public var canEdit: Bool {
        original.isEditable
    }

    /// Whether there are unsaved changes
    public var isDirty: Bool {
        draft != original.content
    }

    /// Creates an editor for the given skill
    /// - Parameters:
    ///   - skill: The skill to edit
    ///   - writer: The writer to use for saving
    public init(skill: Skill, writer: SkillWriter) {
        self.original = skill
        self.draft = skill.content
        self.writer = writer
    }

    /// Saves the current draft content
    /// - Returns: The updated skill
    /// - Throws: `SkillEditorError.notEditable` if skill is not editable
    public func save() async throws -> Skill {
        guard canEdit else {
            throw SkillEditorError.notEditable
        }

        let updated = original.updating(content: draft)
        try await writer.save(updated)

        original = updated
        return updated
    }

    /// Resets the draft to the original content
    public func reset() {
        draft = original.content
    }
}
