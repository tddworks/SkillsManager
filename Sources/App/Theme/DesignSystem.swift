import SwiftUI

// MARK: - Design System
// A refined, editorial design system for SkillsManager

enum DesignSystem {

    // MARK: - Typography

    enum Typography {
        /// Display font for hero headers
        static let displayLarge = Font.system(size: 28, weight: .semibold, design: .rounded)

        /// Section headers
        static let headline = Font.system(size: 15, weight: .semibold, design: .rounded)

        /// Body text
        static let body = Font.system(size: 13, weight: .regular, design: .default)

        /// Secondary body
        static let bodySecondary = Font.system(size: 12, weight: .regular, design: .default)

        /// Caption text
        static let caption = Font.system(size: 11, weight: .medium, design: .default)

        /// Tiny labels
        static let micro = Font.system(size: 10, weight: .semibold, design: .rounded)

        /// Monospace for code
        static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    // MARK: - Colors

    enum Colors {
        // Semantic colors
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(nsColor: .tertiaryLabelColor)

        // Accent colors
        static let accent = Color.accentColor

        // Provider colors
        static let claudeBlue = Color(red: 0.35, green: 0.55, blue: 0.95)
        static let codexGreen = Color(red: 0.3, green: 0.75, blue: 0.5)

        // Status colors
        static let success = Color(red: 0.3, green: 0.75, blue: 0.45)
        static let warning = Color(red: 0.95, green: 0.7, blue: 0.3)
        static let destructive = Color(red: 0.9, green: 0.35, blue: 0.35)

        // Surface colors
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let elevatedBackground = Color(nsColor: .windowBackgroundColor)
        static let subtleBorder = Color(nsColor: .separatorColor).opacity(0.5)

        // Badge backgrounds
        static let badgeBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.3)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Radius

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }

    // MARK: - Shadows

    enum Shadows {
        static let subtle = ShadowStyle(
            color: .black.opacity(0.06),
            radius: 4,
            x: 0,
            y: 2
        )

        static let elevated = ShadowStyle(
            color: .black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )

        static let prominent = ShadowStyle(
            color: .black.opacity(0.15),
            radius: 16,
            x: 0,
            y: 8
        )
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.35)
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    func cardStyle(isSelected: Bool = false, isHovering: Bool = false) -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                    .stroke(
                        isSelected ? DesignSystem.Colors.accent.opacity(0.6) :
                            (isHovering ? DesignSystem.Colors.subtleBorder : .clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isHovering ? DesignSystem.Shadows.elevated.color : DesignSystem.Shadows.subtle.color,
                radius: isHovering ? DesignSystem.Shadows.elevated.radius : DesignSystem.Shadows.subtle.radius,
                x: 0,
                y: isHovering ? DesignSystem.Shadows.elevated.y : DesignSystem.Shadows.subtle.y
            )
    }

    func subtleShadow() -> some View {
        self.shadow(
            color: DesignSystem.Shadows.subtle.color,
            radius: DesignSystem.Shadows.subtle.radius,
            x: DesignSystem.Shadows.subtle.x,
            y: DesignSystem.Shadows.subtle.y
        )
    }

    func elevatedShadow() -> some View {
        self.shadow(
            color: DesignSystem.Shadows.elevated.color,
            radius: DesignSystem.Shadows.elevated.radius,
            x: DesignSystem.Shadows.elevated.x,
            y: DesignSystem.Shadows.elevated.y
        )
    }
}

// MARK: - Refined Badge Component

struct RefinedBadge: View {
    let text: String
    let style: BadgeStyle

    enum BadgeStyle {
        case neutral
        case claude
        case codex
        case version
        case info
        case success

        var backgroundColor: Color {
            switch self {
            case .neutral: return DesignSystem.Colors.badgeBackground
            case .claude: return DesignSystem.Colors.claudeBlue.opacity(0.15)
            case .codex: return DesignSystem.Colors.codexGreen.opacity(0.15)
            case .version: return DesignSystem.Colors.badgeBackground
            case .info: return Color.purple.opacity(0.15)
            case .success: return DesignSystem.Colors.success.opacity(0.15)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .neutral: return DesignSystem.Colors.secondaryText
            case .claude: return DesignSystem.Colors.claudeBlue
            case .codex: return DesignSystem.Colors.codexGreen
            case .version: return DesignSystem.Colors.tertiaryText
            case .info: return .purple
            case .success: return DesignSystem.Colors.success
            }
        }
    }

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.micro)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(style.backgroundColor)
            .foregroundStyle(style.foregroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - Icon Badge (for installed status)

struct IconBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(DesignSystem.Typography.micro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Divider with Label

struct LabeledDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Rectangle()
                .fill(DesignSystem.Colors.subtleBorder)
                .frame(height: 1)

            Text(label)
                .font(DesignSystem.Typography.micro)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)

            Rectangle()
                .fill(DesignSystem.Colors.subtleBorder)
                .frame(height: 1)
        }
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: -geometry.size.width * 0.5 + geometry.size.width * 1.5 * phase)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}