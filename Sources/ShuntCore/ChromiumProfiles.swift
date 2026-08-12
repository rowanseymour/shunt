import Foundation

/// A user profile within a Chromium-based browser.
public struct BrowserProfile: Identifiable, Hashable, Sendable {
    /// Profile directory name, e.g. "Default" or "Profile 1".
    public let directory: String
    /// Display name, e.g. "Work".
    public let name: String

    public var id: String { directory }

    public init(directory: String, name: String) {
        self.directory = directory
        self.name = name
    }
}

/// Knowledge of how Chromium-based browsers store their profiles, kept free of
/// AppKit so it's trivially testable. Profiles live in per-browser directories
/// under Application Support, described by a "Local State" JSON file.
public enum ChromiumProfiles {
    /// Application Support subdirectory for each browser known to support
    /// `--profile-directory`, keyed by bundle identifier.
    private static let dataDirectories: [String: String] = [
        "com.google.Chrome": "Google/Chrome",
        "com.google.Chrome.beta": "Google/Chrome Beta",
        "com.google.Chrome.dev": "Google/Chrome Dev",
        "com.google.Chrome.canary": "Google/Chrome Canary",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.brave.Browser": "BraveSoftware/Brave-Browser",
        "com.brave.Browser.beta": "BraveSoftware/Brave-Browser-Beta",
        "com.brave.Browser.nightly": "BraveSoftware/Brave-Browser-Nightly",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "org.chromium.Chromium": "Chromium",
    ]

    /// Application Support subdirectory holding the browser's "Local State",
    /// or nil if the browser isn't known to support profile routing.
    public static func dataDirectory(forBundleID id: String) -> String? {
        dataDirectories[id]
    }

    /// Extracts profiles from the contents of a "Local State" file.
    public static func parse(localState data: Data) -> [BrowserProfile] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else { return [] }
        return infoCache
            .compactMap { directory, value -> BrowserProfile? in
                guard let info = value as? [String: Any] else { return nil }
                let name = (info["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                return BrowserProfile(directory: directory, name: name ?? directory)
            }
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.directory < $1.directory : order == .orderedAscending
            }
    }
}
