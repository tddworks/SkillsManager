import SwiftUI
import Domain

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
        } detail: {
            if let skill = appState.selectedSkill {
                SkillDetailView(skill: skill, appState: appState)
            } else {
                ContentUnavailableView(
                    "Select a Skill",
                    systemImage: "doc.text",
                    description: Text("Choose a skill from the sidebar to view its details")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .task {
            await appState.loadSkills()
        }
        .sheet(isPresented: $appState.showingInstallSheet) {
            if let skill = appState.selectedSkill {
                InstallSheet(skill: skill, appState: appState)
            }
        }
    }
}
