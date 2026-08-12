import SwiftUI

struct MenuContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Toggle("Pause routing", isOn: $model.paused)

        if !model.recent.isEmpty {
            Section("Recent") {
                ForEach(model.recent) { record in
                    Button("\(record.url) → \(record.destination)") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.url, forType: .string)
                    }
                }
            }
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("Quit Shunt") {
            NSApp.terminate(nil)
        }
    }
}
