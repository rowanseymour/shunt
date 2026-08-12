import SwiftUI

@main
struct ShuntApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Template image so the system recolors it for menu bar state and appearance;
    // falls back to an SF Symbol when running outside the assembled app bundle.
    private static let menuBarIcon: NSImage = {
        guard let image = Bundle.main.image(forResource: "MenuBarIcon") else {
            return NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Shunt")!
        }
        image.isTemplate = true
        return image
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(AppModel.shared)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        Settings {
            SettingsView()
                .environment(AppModel.shared)
        }
    }
}
