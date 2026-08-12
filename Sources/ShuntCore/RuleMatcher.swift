import Foundation

/// Pure matching logic, kept free of AppKit so it's trivially testable.
public enum RuleMatcher {
    /// Case-insensitive match of a pattern against a URL, where `*` stands for any run
    /// of characters. A pattern without a `/` is matched against the URL's host alone;
    /// one with a `/` against host and path together. Query strings are never matched.
    ///
    /// As a convenience `*.example.com` also matches the bare apex `example.com`, and
    /// `example.com/dir/*` also matches the bare `example.com/dir`.
    public static func urlMatches(pattern: String, url: URL) -> Bool {
        let pattern = trimmed(pattern)
        guard !pattern.isEmpty, let host = url.host?.lowercased() else { return false }
        let target = pattern.contains("/") ? host + trimmed(url.path) : host
        return target.range(of: regex(for: pattern), options: .regularExpression) != nil
    }

    /// Lowercased, with surrounding whitespace and any trailing slash removed, so that
    /// "example.com/" and a URL's "/" root path both reduce to plain "example.com".
    private static func trimmed(_ string: String) -> String {
        var string = string.trimmingCharacters(in: .whitespaces).lowercased()
        while string.hasSuffix("/") { string.removeLast() }
        return string
    }

    private static func regex(for pattern: String) -> String {
        var pattern = pattern
        var prefix = ""
        var suffix = ""
        if pattern.hasPrefix("*.") {
            prefix = "(?:.*\\.)?"
            pattern.removeFirst(2)
        }
        if pattern.hasSuffix("/*") {
            suffix = "(?:/.*)?"
            pattern.removeLast(2)
        }
        let body = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        return "^\(prefix)\(body)\(suffix)$"
    }

    public static func matches(_ rule: Rule, url: URL, sourceApp: String?) -> Bool {
        guard rule.enabled else { return false }
        let pattern = rule.pattern ?? ""
        if let requiredSource = rule.sourceApp, !requiredSource.isEmpty {
            guard requiredSource.caseInsensitiveCompare(sourceApp ?? "") == .orderedSame else { return false }
            if pattern.isEmpty { return true }
        }
        return urlMatches(pattern: pattern, url: url)
    }

    /// First match wins — rules are evaluated in list order.
    public static func firstMatch(for url: URL, sourceApp: String?, in rules: [Rule]) -> Rule? {
        rules.first { matches($0, url: url, sourceApp: sourceApp) }
    }
}
