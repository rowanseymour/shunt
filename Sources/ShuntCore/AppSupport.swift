import Foundation

/// The Application Support directory everything reads from. SHUNT_APP_SUPPORT
/// overrides it so dev tooling (e.g. bin/screenshot) can run against fixture data.
public enum AppSupport {
    public static var directory: URL {
        if let override = ProcessInfo.processInfo.environment["SHUNT_APP_SUPPORT"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
