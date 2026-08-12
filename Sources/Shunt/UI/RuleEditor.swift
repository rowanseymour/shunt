import ShuntCore
import SwiftUI

struct RuleEditor: View {
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    let browsers: [Browser]
    let profilesByBrowser: [String: [BrowserProfile]]
    let onSave: (Rule) -> Void

    @State private var rule: Rule
    @State private var patternsText: String
    @State private var sourceAppText: String

    init(rule: Rule, isNew: Bool, browsers: [Browser], profilesByBrowser: [String: [BrowserProfile]], onSave: @escaping (Rule) -> Void) {
        self.isNew = isNew
        self.browsers = browsers
        self.profilesByBrowser = profilesByBrowser
        self.onSave = onSave
        _rule = State(initialValue: rule)
        _patternsText = State(initialValue: rule.patterns.joined(separator: ", "))
        _sourceAppText = State(initialValue: rule.sourceApp ?? "")
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
                TextField("URL patterns", text: $patternsText, prompt: Text("*.atlassian.net, localhost"))
                    .font(.body.monospaced())
                Text("Comma-separated hosts; * matches anything")
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
                }

                if !profiles.isEmpty {
                    Picker("Profile", selection: $rule.profile) {
                        Text("Last used").tag(String?.none)
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(String?.some(profile.directory))
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    rule.patterns = patternsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    let source = sourceAppText.trimmingCharacters(in: .whitespaces)
                    rule.sourceApp = source.isEmpty ? nil : source
                    onSave(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(patternsText.trimmingCharacters(in: .whitespaces).isEmpty
                    && sourceAppText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
