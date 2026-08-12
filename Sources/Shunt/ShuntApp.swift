import SwiftUI

@main
struct ShuntApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Shunt", systemImage: "arrow.triangle.branch") {
            MenuContent()
                .environment(AppModel.shared)
        }
        Settings {
            SettingsView()
                .environment(AppModel.shared)
        }
    }
}
