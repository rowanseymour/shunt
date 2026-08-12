import ShuntCore
import SwiftUI

struct RuleEditor: View {
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    let browsers: [Browser]
    let profilesByBrowser: [String: [BrowserProfile]]
    let onSave: (Rule) -> Void

    @State private var rule: Rule
    @State private var patternText: String
    @State private var sourceAppText: String

    init(rule: Rule, isNew: Bool, browsers: [Browser], profilesByBrowser: [String: [BrowserProfile]], onSave: @escaping (Rule) -> Void) {
        self.isNew = isNew
        self.browsers = browsers
        self.profilesByBrowser = profilesByBrowser
        self.onSave = onSave
        _rule = State(initialValue: rule)
        _patternText = State(initialValue: rule.pattern ?? "")
        _sourceAppText = State(initialValue: rule.sourceApp ?? "")
    }

    /// Safari has no private-window switch, so the toggle is hidden rather than shown
    /// as something that would be silently ignored.
    private var supportsPrivateWindows: Bool {
        PrivateWindows.isSupported(bundleID: rule.browserID)
    }

    /// Profiles of the selected browser, keeping a stale selection visible so the
    /// picker stays valid if the profile was deleted since the rule was created.
    private var profiles: [BrowserProfile] {
        var profiles = profilesByBrowser[rule.browserID] ?? []
        if let selected = rule.profile, !profiles.contains(where: { $0.directory == selected }) {
            profiles.append(BrowserProfile(directory: selected, name: selected))
        }
        return profiles
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "Add rule" : "Edit rule")
                .font(.headline)

            Form {
                TextField("URL pattern", text: $patternText, prompt: Text("*.atlassian.net"))
                    .font(.body.monospaced())
                Text("A host, optionally with a path (github.com/nyaruka/*); * matches anything")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Source app", text: $sourceAppText, prompt: Text("com.tinyspeck.slackmacgap (optional)"))
                    .font(.body.monospaced())
                Text("Only match links clicked in this app")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Open in", selection: $rule.browserID) {
                    ForEach(browsers) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                .onChange(of: rule.browserID) {
                    rule.profile = nil
                    rule.privateWindow = rule.privateWindow && supportsPrivateWindows
                }

                if !profiles.isEmpty {
                    Picker("Profile", selection: $rule.profile) {
                        Text("Last used").tag(String?.none)
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(String?.some(profile.directory))
                        }
                    }
                }

                if supportsPrivateWindows {
                    Toggle("Open in a private window", isOn: $rule.privateWindow)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    let pattern = patternText.trimmingCharacters(in: .whitespaces)
                    rule.pattern = pattern.isEmpty ? nil : pattern
                    let source = sourceAppText.trimmingCharacters(in: .whitespaces)
                    rule.sourceApp = source.isEmpty ? nil : source
                    onSave(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(patternText.trimmingCharacters(in: .whitespaces).isEmpty
                    && sourceAppText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
