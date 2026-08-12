import AppKit
import Observation
import ShuntCore

/// A single routed URL, shown in the menu bar dropdown.
struct RouteRecord: Identifiable, Sendable {
    let id = UUID()
    let url: String
    let browserName: String
    let ruleLabel: String
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    var config: Config {
        didSet { ConfigStore.save(config) }
    }
    var paused = false
    var recent: [RouteRecord] = []
    var browsers: [Browser] = []

    private init() {
        if let loaded = ConfigStore.load() {
            config = loaded
        } else {
            var fresh = Config()
            // First run: fall back to whatever the default browser was before Shunt.
            if let current = Browsers.currentDefaultBrowserID(), current != Bundle.main.bundleIdentifier {
                fresh.fallbackBrowserID = current
            }
            config = fresh
        }
        refreshBrowsers()
    }

    func refreshBrowsers() {
        browsers = Browsers.installed()
    }

    var isDefaultBrowser: Bool {
        Browsers.currentDefaultBrowserID() == Bundle.main.bundleIdentifier
    }

    func setAsDefaultBrowser() {
        Task {
            try? await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http")
        }
    }

    func browserName(for id: String) -> String {
        browsers.first { $0.id == id }?.name ?? id
    }

    func route(_ url: URL, from sourceApp: String?) {
        let browserID: String
        let ruleLabel: String
        if paused {
            (browserID, ruleLabel) = (config.fallbackBrowserID, "paused")
        } else if let rule = RuleMatcher.firstMatch(for: url, sourceApp: sourceApp, in: config.rules) {
            (browserID, ruleLabel) = (rule.browserID, rule.label)
        } else {
            (browserID, ruleLabel) = (config.fallbackBrowserID, "fallback")
        }
        Browsers.open(url, inBrowserWithID: browserID)
        recent.insert(RouteRecord(url: url.absoluteString, browserName: browserName(for: browserID), ruleLabel: ruleLabel), at: 0)
        if recent.count > 5 {
            recent.removeLast(recent.count - 5)
        }
    }
}
