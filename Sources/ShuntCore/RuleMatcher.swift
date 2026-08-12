import Foundation

/// Pure matching logic, kept free of AppKit so it's trivially testable.
public enum RuleMatcher {
    /// Case-insensitive host match supporting `*` wildcards.
    /// As a convenience, `*.example.com` also matches the bare apex `example.com`.
    public static func hostMatches(pattern: String, host: String) -> Bool {
        let pattern = pattern.trimmingCharacters(in: .whitespaces).lowercased()
        let host = host.lowercased()
        guard !pattern.isEmpty else { return false }

        if !pattern.contains("*") {
            return pattern == host
        }
        if pattern.hasPrefix("*."), String(pattern.dropFirst(2)) == host {
            return true
        }
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        return host.range(of: "^\(escaped)$", options: .regularExpression) != nil
    }

    public static func matches(_ rule: Rule, url: URL, sourceApp: String?) -> Bool {
        guard rule.enabled else { return false }
        if let requiredSource = rule.sourceApp, !requiredSource.isEmpty {
            guard requiredSource.caseInsensitiveCompare(sourceApp ?? "") == .orderedSame else { return false }
            if rule.patterns.isEmpty { return true }
        }
        guard let host = url.host else { return false }
        return rule.patterns.contains { hostMatches(pattern: $0, host: host) }
    }

    /// First match wins — rules are evaluated in list order.
    public static func firstMatch(for url: URL, sourceApp: String?, in rules: [Rule]) -> Rule? {
        rules.first { matches($0, url: url, sourceApp: sourceApp) }
    }
}
