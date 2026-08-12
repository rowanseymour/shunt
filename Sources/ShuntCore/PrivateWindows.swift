import Foundation

/// Which browsers can be told to open a URL in a private window, and how.
///
/// The switch only reaches the browser when its executable is launched directly —
/// macOS drops arguments when opening an app that's already running — but that is
/// how profile routing already works, and a running browser honours the switch.
public enum PrivateWindows {
    /// Command-line switch that opens a private window, keyed by bundle identifier.
    /// Safari is absent: it has no equivalent switch.
    private static let switches: [String: String] = [
        "com.google.Chrome": "--incognito",
        "com.google.Chrome.beta": "--incognito",
        "com.google.Chrome.dev": "--incognito",
        "com.google.Chrome.canary": "--incognito",
        "com.microsoft.edgemac": "--inprivate",
        "com.brave.Browser": "--incognito",
        "com.brave.Browser.beta": "--incognito",
        "com.brave.Browser.nightly": "--incognito",
        "com.vivaldi.Vivaldi": "--incognito",
        "org.chromium.Chromium": "--incognito",
        "org.mozilla.firefox": "--private-window",
        "org.mozilla.firefoxdeveloperedition": "--private-window",
    ]

    /// Switch that opens a private window in the given browser, or nil if it has none.
    public static func argument(forBundleID id: String) -> String? {
        switches[id]
    }

    public static func isSupported(bundleID: String) -> Bool {
        switches[bundleID] != nil
    }
}
