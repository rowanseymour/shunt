import Foundation

/// A routing rule: if a URL (and optionally its source app) matches, open it in the given browser.
public struct Rule: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    /// Host pattern, optionally narrowed to a path, e.g. "*.atlassian.net" or
    /// "github.com/nyaruka/*". Nil means match any URL (only useful together with
    /// `sourceApp`).
    public var pattern: String?
    /// Bundle identifier of the app the link was clicked in, e.g. "com.tinyspeck.slackmacgap".
    public var sourceApp: String?
    /// Bundle identifier of the browser to open the URL in.
    public var browserID: String
    /// Profile directory to open the URL in, e.g. "Profile 1". Only supported for
    /// Chromium-based browsers; nil means the browser's last-used profile.
    public var profile: String?
    /// Open in a private window. Independent of `profile`, so a rule can ask for an
    /// incognito window of a particular profile. Ignored by browsers without one.
    public var privateWindow: Bool
    public var enabled: Bool

    /// Short human-readable label for menus and the recent-routes list.
    public var label: String {
        if let pattern, !pattern.isEmpty { return pattern }
        if let sourceApp, !sourceApp.isEmpty { return "links from \(sourceApp)" }
        return "any URL"
    }

    enum CodingKeys: String, CodingKey {
        case id, pattern, sourceApp, browserID, profile, privateWindow, enabled
    }

    public init(id: UUID = UUID(), pattern: String? = nil, sourceApp: String? = nil, browserID: String, profile: String? = nil, privateWindow: Bool = false, enabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.sourceApp = sourceApp
        self.browserID = browserID
        self.profile = profile
        self.privateWindow = privateWindow
        self.enabled = enabled
    }

    // Tolerant decoding so hand-edited config files can omit all but the essentials.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern)
        sourceApp = try c.decodeIfPresent(String.self, forKey: .sourceApp)
        browserID = try c.decode(String.self, forKey: .browserID)
        profile = try c.decodeIfPresent(String.self, forKey: .profile)
        privateWindow = try c.decodeIfPresent(Bool.self, forKey: .privateWindow) ?? false
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// A rule as it may appear on disk, where it could once carry a list of patterns.
/// Each pattern now gets its own rule, so such a rule expands into several on load.
private struct StoredRule: Decodable {
    let rules: [Rule]

    private enum CodingKeys: String, CodingKey {
        case patterns
    }

    init(from decoder: Decoder) throws {
        let rule = try Rule(from: decoder)
        let patterns = try decoder.container(keyedBy: CodingKeys.self)
            .decodeIfPresent([String].self, forKey: .patterns) ?? []
        guard rule.pattern == nil, !patterns.isEmpty else {
            rules = [rule]
            return
        }
        rules = patterns.enumerated().map { index, pattern in
            var expanded = rule
            // The first rule inherits the original identity; the rest need their own.
            if index > 0 { expanded.id = UUID() }
            expanded.pattern = pattern
            return expanded
        }
    }
}

public struct Config: Sendable, Codable {
    /// Browser that gets any URL no rule matches.
    public var fallbackBrowserID: String
    public var rules: [Rule]

    enum CodingKeys: String, CodingKey {
        case fallbackBrowserID, rules
    }

    public init(fallbackBrowserID: String = "com.apple.Safari", rules: [Rule] = []) {
        self.fallbackBrowserID = fallbackBrowserID
        self.rules = rules
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fallbackBrowserID = try c.decodeIfPresent(String.self, forKey: .fallbackBrowserID) ?? "com.apple.Safari"
        rules = try (c.decodeIfPresent([StoredRule].self, forKey: .rules) ?? []).flatMap(\.rules)
    }
}
