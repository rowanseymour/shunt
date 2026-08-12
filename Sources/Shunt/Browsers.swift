import AppKit

struct Browser: Identifiable, Hashable {
    let id: String
    let name: String
    let appURL: URL
}

@MainActor
enum Browsers {
    private static let probeURL = URL(string: "https://example.com")!

    /// All installed apps that can open https URLs, excluding Shunt itself.
    static func installed() -> [Browser] {
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
            .compactMap { appURL -> Browser? in
                guard let bundle = Bundle(url: appURL), let id = bundle.bundleIdentifier else { return nil }
                guard id != Bundle.main.bundleIdentifier, seen.insert(id).inserted else { return nil }
                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? appURL.deletingPathExtension().lastPathComponent
                return Browser(id: id, name: name, appURL: appURL)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func icon(for browser: Browser) -> NSImage {
        NSWorkspace.shared.icon(forFile: browser.appURL.path)
    }

    /// Bundle ID of the current default https handler, if any.
    static func currentDefaultBrowserID() -> String? {
        NSWorkspace.shared.urlForApplication(toOpen: probeURL)
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
    }

    static func open(_ url: URL, inBrowserWithID id: String) {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: id)
            ?? workspace.urlForApplication(withBundleIdentifier: "com.apple.Safari") else { return }
        workspace.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
