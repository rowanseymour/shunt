import AppKit
import Observation
import ShuntCore

/// A single routed URL, shown in the menu bar dropdown.
struct RouteRecord: Identifiable, Sendable {
    let id = UUID()
    let url: String
    let destination: String
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
    /// Profiles per browser bundle ID; browsers without profile support are absent.
    var profilesByBrowser: [String: [BrowserProfile]] = [:]

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
        profilesByBrowser = Dictionary(uniqueKeysWithValues: browsers.compactMap { browser in
            let profiles = Browsers.profiles(forBrowserWithID: browser.id)
            return profiles.isEmpty ? nil : (browser.id, profiles)
        })
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

    /// Human-readable target, e.g. "Chrome", "Chrome (Work)" or "Chrome (Work, Private)".
    func destinationName(browserID: String, profile: String?, privateWindow: Bool = false) -> String {
        let name = browserName(for: browserID)
        var qualifiers: [String] = []
        if let profile {
            qualifiers.append(profilesByBrowser[browserID]?.first { $0.directory == profile }?.name ?? profile)
        }
        if privateWindow, PrivateWindows.isSupported(bundleID: browserID) {
            qualifiers.append("Private")
        }
        guard !qualifiers.isEmpty else { return name }
        return "\(name) (\(qualifiers.joined(separator: ", ")))"
    }

    func route(_ url: URL, from sourceApp: String?) {
        let matched = paused ? nil : RuleMatcher.firstMatch(for: url, sourceApp: sourceApp, in: config.rules)
        let browserID = matched?.browserID ?? config.fallbackBrowserID
        let profile = matched?.profile
        let privateWindow = matched?.privateWindow ?? false
        let ruleLabel = matched?.label ?? (paused ? "paused" : "fallback")

        Browsers.open(url, inBrowserWithID: browserID, profile: profile, privateWindow: privateWindow)
        recent.insert(RouteRecord(
            url: url.absoluteString,
            destination: destinationName(browserID: browserID, profile: profile, privateWindow: privateWindow),
            ruleLabel: ruleLabel
        ), at: 0)
        if recent.count > 5 {
            recent.removeLast(recent.count - 5)
        }
    }
}
