import SwiftUI
import Domain
import Infrastructure

@main
struct SkillsManagerApp: App {
    #if ENABLE_SPARKLE
    @State private var sparkleUpdater = SparkleUpdater()
    #endif

    var body: some Scene {
        WindowGroup {
            #if ENABLE_SPARKLE
            ContentView()
                .environment(\.sparkleUpdater, sparkleUpdater)
            #else
            ContentView()
            #endif
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        #if ENABLE_SPARKLE
        Settings {
            SettingsView()
                .environment(\.sparkleUpdater, sparkleUpdater)
        }
        #endif
    }
}
