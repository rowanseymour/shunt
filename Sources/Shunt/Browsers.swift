import AppKit
import ShuntCore

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

    /// Profiles of the given browser, or empty if it doesn't support profile routing.
    static func profiles(forBrowserWithID id: String) -> [BrowserProfile] {
        guard let dataDirectory = ChromiumProfiles.dataDirectory(forBundleID: id) else { return [] }
        let localState = AppSupport.directory
            .appendingPathComponent(dataDirectory)
            .appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: localState) else { return [] }
        return ChromiumProfiles.parse(localState: data)
    }

    static func open(_ url: URL, inBrowserWithID id: String, profile: String? = nil, privateWindow: Bool = false) {
        var arguments: [String] = []
        if let profile, ChromiumProfiles.dataDirectory(forBundleID: id) != nil {
            arguments.append("--profile-directory=\(profile)")
        }
        if privateWindow, let argument = PrivateWindows.argument(forBundleID: id) {
            arguments.append(argument)
        }
        if !arguments.isEmpty, launch(url, browserID: id, arguments: arguments) { return }

        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: id)
            ?? workspace.urlForApplication(withBundleIdentifier: "com.apple.Safari") else { return }
        workspace.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// NSWorkspace can't pass arguments to an already-running app, so any routing that
    /// needs a switch launches the browser executable directly — it hands the URL and
    /// switches over to an existing instance and exits.
    private static func launch(_ url: URL, browserID: String, arguments: [String]) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserID),
              let executable = Bundle(url: appURL)?.executableURL else { return false }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments + [url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            NSLog("Shunt: failed to launch \(executable.path): \(error)")
            return false
        }
    }
}
