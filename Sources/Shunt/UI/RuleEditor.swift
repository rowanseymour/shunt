import ShuntCore
import SwiftUI

struct RuleEditor: View {
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    let browsers: [Browser]
    let onSave: (Rule) -> Void

    @State private var rule: Rule
    @State private var patternsText: String
    @State private var sourceAppText: String

    init(rule: Rule, isNew: Bool, browsers: [Browser], onSave: @escaping (Rule) -> Void) {
        self.isNew = isNew
        self.browsers = browsers
        self.onSave = onSave
        _rule = State(initialValue: rule)
        _patternsText = State(initialValue: rule.patterns.joined(separator: ", "))
        _sourceAppText = State(initialValue: rule.sourceApp ?? "")
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
