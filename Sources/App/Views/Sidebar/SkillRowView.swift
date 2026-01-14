import SwiftUI
import Domain

struct SkillRowView: View {
    let skill: Skill

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Name with installed indicator
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Text(skill.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                if skill.isInstalled {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 6, height: 6)
                }

                Spacer(minLength: 0)
            }

            // Description
            Text(skill.description)
                .font(DesignSystem.Typography.bodySecondary)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Tags row
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Version badge
                RefinedBadge(text: "v\(skill.version)", style: .version)

                // Provider badges
                ForEach(Array(skill.installedProviders), id: \.self) { provider in
                    RefinedBadge(
                        text: provider.displayName,
                        style: provider == .claude ? .claude : .codex
                    )
                }

                // Reference count
                if skill.hasReferences {
                    RefinedBadge(
                        text: "\(skill.referenceCount) ref\(skill.referenceCount == 1 ? "" : "s")",
                        style: .info
                    )
                }

                // Script count
                if skill.hasScripts {
                    HStack(spacing: 3) {
                        Image(systemName: "terminal")
                            .font(.system(size: 8, weight: .semibold))
                        Text("\(skill.scriptCount)")
                            .font(DesignSystem.Typography.micro)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Legacy Badge (kept for compatibility, but prefer RefinedBadge)

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.micro)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}