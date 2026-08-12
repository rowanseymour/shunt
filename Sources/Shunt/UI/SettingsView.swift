import ShuntCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var editingRule: Rule?
    @State private var editingIsNew = false

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            if !model.isDefaultBrowser {
                defaultBrowserBanner
            }

            HStack {
                Text("Rules match top to bottom — first match wins")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    editingRule = Rule(browserID: model.config.fallbackBrowserID)
                    editingIsNew = true
                } label: {
                    Label("Add rule", systemImage: "plus")
                }
            }

            rulesList

            HStack {
                Text("Everything else opens in")
                Picker("", selection: $model.config.fallbackBrowserID) {
                    ForEach(model.browsers) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Divider()

            footer
        }
        .padding(20)
        .frame(width: 560, height: 480)
        .sheet(item: $editingRule) { rule in
            RuleEditor(rule: rule, isNew: editingIsNew, browsers: model.browsers, profilesByBrowser: model.profilesByBrowser) { saved in
                if let index = model.config.rules.firstIndex(where: { $0.id == saved.id }) {
                    model.config.rules[index] = saved
                } else {
                    model.config.rules.append(saved)
                }
            }
        }
        .onAppear {
            model.refreshBrowsers()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var defaultBrowserBanner: some View {
        HStack {
            Label("Shunt isn't your default browser yet", systemImage: "exclamationmark.triangle")
            Spacer()
            Button("Set as default") {
                model.setAsDefaultBrowser()
            }
        }
        .padding(10)
        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    private var rulesList: some View {
        List {
            ForEach(model.config.rules) { rule in
                ruleRow(rule)
            }
            .onMove { source, destination in
                model.config.rules.move(fromOffsets: source, toOffset: destination)
            }
            .onDelete { offsets in
                model.config.rules.remove(atOffsets: offsets)
            }
        }
        .listStyle(.bordered)
        .overlay {
            if model.config.rules.isEmpty {
                Text("No rules yet — every link opens in the fallback browser")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func ruleRow(_ rule: Rule) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { newValue in
                    if let index = model.config.rules.firstIndex(where: { $0.id == rule.id }) {
                        model.config.rules[index].enabled = newValue
                    }
                }
            ))
            .labelsHidden()
            VStack(alignment: .leading) {
                Text(rule.pattern ?? "any URL")
                    .font(.body.monospaced())
                if let sourceApp = rule.sourceApp, !sourceApp.isEmpty {
                    Text("from \(sourceApp)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Text(model.destinationName(browserID: rule.browserID, profile: rule.profile))
            Button {
                editingRule = rule
                editingIsNew = false
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) {
                model.config.rules.removeAll { $0.id == rule.id }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .opacity(rule.enabled ? 1 : 0.5)
    }

    private var footer: some View {
        HStack {
            Text("Shunt \(appVersion)")
            Text("·")
            Link("Rowan Seymour", destination: URL(string: "https://github.com/rowanseymour")!)
            Spacer()
            Link("Report a bug", destination: URL(string: "https://github.com/rowanseymour/shunt/issues")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
