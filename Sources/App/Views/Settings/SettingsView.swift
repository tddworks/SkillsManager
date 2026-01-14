import SwiftUI

#if ENABLE_SPARKLE
struct SettingsView: View {
    @Environment(\.sparkleUpdater) private var sparkleUpdater
    @State private var settings = AppSettings.shared

    var body: some View {
        TabView {
            UpdatesSettingsView(sparkleUpdater: sparkleUpdater, settings: settings)
                .tabItem {
                    Label("Updates", systemImage: "arrow.down.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - Updates Settings View

struct UpdatesSettingsView: View {
    let sparkleUpdater: SparkleUpdater?
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                if sparkleUpdater?.isAvailable == true {
                    // Check for Updates Button
                    HStack {
                        Button {
                            sparkleUpdater?.checkForUpdates()
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                if sparkleUpdater?.isCheckingForUpdates == true {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .semibold))
                                }

                                Text(sparkleUpdater?.isCheckingForUpdates == true ? "Checking..." : "Check for Updates")
                                    .font(DesignSystem.Typography.body)
                            }
                        }
                        .disabled(sparkleUpdater?.canCheckForUpdates != true || sparkleUpdater?.isCheckingForUpdates == true)

                        Spacer()

                        // Version badge
                        RefinedBadge(text: "v\(appVersion)", style: .version)
                    }

                    // Last check info
                    if let lastCheck = sparkleUpdater?.lastUpdateCheckDate {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)

                            Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        }
                    }

                    // Update available indicator
                    if sparkleUpdater?.isUpdateAvailable == true,
                       let version = sparkleUpdater?.availableVersion {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(DesignSystem.Colors.success)

                            Text("Version \(version) is available")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.primaryText)

                            Spacer()

                            Button("Update Now") {
                                sparkleUpdater?.checkForUpdates()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignSystem.Colors.success)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.success.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                    }
                } else {
                    // Debug mode message
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)

                        Text("Updates unavailable in debug builds")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                }
            } header: {
                Text("Software Update")
            }

            Section {
                // Auto updates toggle
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { sparkleUpdater?.automaticallyChecksForUpdates ?? true },
                    set: { sparkleUpdater?.automaticallyChecksForUpdates = $0 }
                ))
                .disabled(sparkleUpdater?.isAvailable != true)

                // Beta updates toggle
                Toggle(isOn: $settings.receiveBetaUpdates) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include beta versions")
                        Text("Get early access to new features")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                }
                .disabled(sparkleUpdater?.isAvailable != true)
            } header: {
                Text("Preferences")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - App Info

    /// The app version from the bundle
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// The app build number from the bundle
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
#endif
