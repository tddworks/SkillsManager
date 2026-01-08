import Foundation
import Domain

/// Errors that can occur during skill parsing
public enum SkillParserError: Error, Sendable {
    case missingFrontmatter
    case missingName
    case missingDescription
    case invalidFrontmatter(String)
}

/// Parses SKILL.md files into Skill domain models
public enum SkillParser {

    /// Parse a SKILL.md file content into a Skill model
    /// - Parameters:
    ///   - content: The raw string content of the SKILL.md file
    ///   - id: The skill identifier (usually directory name)
    ///   - source: Where the skill comes from (local or remote)
    /// - Returns: A parsed Skill model
    /// - Throws: SkillParserError if parsing fails
    public static func parse(content: String, id: String, source: SkillSource) throws -> Skill {
        // Extract frontmatter between --- markers
        guard let frontmatter = extractFrontmatter(from: content) else {
            throw SkillParserError.missingFrontmatter
        }

        // Parse YAML frontmatter
        let metadata = parseYAMLFrontmatter(frontmatter)

        guard let name = metadata["name"] else {
            throw SkillParserError.missingName
        }

        guard let description = metadata["description"] else {
            throw SkillParserError.missingDescription
        }

        let version = metadata["version"] ?? "1.0.0"

        return Skill(
            id: id,
            name: name,
            description: description,
            version: version,
            content: content,
            source: source
        )
    }

    /// Extract frontmatter content between --- markers
    private static func extractFrontmatter(from content: String) -> String? {
        let pattern = "^---\\s*\\n([\\s\\S]*?)\\n---"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[range])
    }

    /// Parse simple YAML frontmatter into key-value pairs
    /// Supports single-line and multiline (|) values
    private static func parseYAMLFrontmatter(_ yaml: String) -> [String: String] {
        var result: [String: String] = [:]
        var currentKey: String?
        var currentValue: [String] = []
        var isMultiline = false

        let lines = yaml.components(separatedBy: .newlines)

        for line in lines {
            if isMultiline {
                // Check if this line starts a new key (not indented)
                if !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.contains(":") {
                    // Save previous multiline value
                    if let key = currentKey {
                        result[key] = currentValue.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    isMultiline = false
                    currentKey = nil
                    currentValue = []
                } else {
                    // Continue multiline value
                    let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
                    if !trimmed.isEmpty {
                        currentValue.append(trimmed)
                    }
                    continue
                }
            }

            // Parse key: value pairs
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueStart = line.index(after: colonIndex)
                let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)

                if value == "|" {
                    // Start multiline value
                    currentKey = key
                    currentValue = []
                    isMultiline = true
                } else if !value.isEmpty {
                    result[key] = value
                }
            }
        }

        // Don't forget the last multiline value
        if isMultiline, let key = currentKey {
            result[key] = currentValue.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}
