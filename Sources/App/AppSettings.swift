import Foundation

/// Observable settings manager for SkillsManager preferences.
@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    // MARK: - Update Settings

    /// Whether to receive beta updates (default: false)
    public var receiveBetaUpdates: Bool {
        didSet {
            UserDefaults.standard.set(receiveBetaUpdates, forKey: Keys.receiveBetaUpdates)
            NotificationCenter.default.post(name: .betaUpdatesSettingChanged, object: nil)
        }
    }

    // MARK: - Initialization

    private init() {
        self.receiveBetaUpdates = UserDefaults.standard.bool(forKey: Keys.receiveBetaUpdates)
    }
}

// MARK: - UserDefaults Keys

private extension AppSettings {
    enum Keys {
        static let receiveBetaUpdates = "receiveBetaUpdates"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let betaUpdatesSettingChanged = Notification.Name("betaUpdatesSettingChanged")
}
