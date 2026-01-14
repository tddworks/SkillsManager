import SwiftUI
import Domain

struct ContentView: View {
    @State private var library = SkillLibrary()

    var body: some View {
        NavigationSplitView {
            SidebarView(library: library)
        } detail: {
            if let skill = library.selectedSkill {
                SkillDetailView(skill: skill, library: library)
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .task {
            await library.loadSkills()
        }
        .sheet(isPresented: $library.showingInstallSheet) {
            if let skill = library.selectedSkill {
                InstallSheet(skill: skill, library: library)
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Animated icon
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.accent.opacity(0.3),
                                DesignSystem.Colors.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isAnimating)

                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.accent.opacity(0.08),
                                DesignSystem.Colors.accent.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                // Icon
                Image(systemName: "doc.text")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.accent.opacity(0.7))
            }

            // Text content
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Select a Skill")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Choose a skill from the sidebar to view its details")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            // Keyboard hint
            HStack(spacing: DesignSystem.Spacing.sm) {
                KeyboardHint(keys: ["↑", "↓"])
                Text("to navigate")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Keyboard Hint

struct KeyboardHint: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(DesignSystem.Colors.subtleBorder, lineWidth: 1)
                            )
                    )
            }
        }
    }
}
