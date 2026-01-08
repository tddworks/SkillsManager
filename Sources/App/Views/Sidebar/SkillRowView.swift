import SwiftUI
import Domain

struct SkillRowView: View {
    let skill: Skill

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name
            Text(skill.name)
                .font(.headline)
                .lineLimit(1)

            // Description
            Text(skill.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Tags row
            HStack(spacing: 4) {
                // Version badge
                Badge(text: "v\(skill.version)", color: .gray)

                // Provider badges
                ForEach(Array(skill.installedProviders), id: \.self) { provider in
                    Badge(text: provider.displayName, color: providerColor(provider))
                }

                // Reference/script badges
                if skill.hasReferences {
                    Badge(text: "\(skill.referenceCount) reference\(skill.referenceCount == 1 ? "" : "s")", color: .purple)
                }

                if skill.hasScripts {
                    Badge(text: "\(skill.scriptCount) script\(skill.scriptCount == 1 ? "" : "s")", color: .orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func providerColor(_ provider: Provider) -> Color {
        switch provider {
        case .codex: return .green
        case .claude: return .blue
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
