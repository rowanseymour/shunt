import Foundation

/// A routing rule: if a URL (and optionally its source app) matches, open it in the given browser.
public struct Rule: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    /// Host patterns, e.g. "*.atlassian.net" or "localhost". Empty means match any URL
    /// (only useful together with `sourceApp`).
    public var patterns: [String]
    /// Bundle identifier of the app the link was clicked in, e.g. "com.tinyspeck.slackmacgap".
    public var sourceApp: String?
    /// Bundle identifier of the browser to open the URL in.
    public var browserID: String
    public var enabled: Bool

    /// Short human-readable label for menus and the recent-routes list.
    public var label: String {
        patterns.first ?? sourceApp.map { "links from \($0)" } ?? "any URL"
    }

    enum CodingKeys: String, CodingKey {
        case id, patterns, sourceApp, browserID, enabled
    }

    public init(id: UUID = UUID(), patterns: [String] = [], sourceApp: String? = nil, browserID: String, enabled: Bool = true) {
        self.id = id
        self.patterns = patterns
        self.sourceApp = sourceApp
        self.browserID = browserID
        self.enabled = enabled
    }

    // Tolerant decoding so hand-edited config files can omit all but the essentials.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        patterns = try c.decodeIfPresent([String].self, forKey: .patterns) ?? []
        sourceApp = try c.decodeIfPresent(String.self, forKey: .sourceApp)
        browserID = try c.decode(String.self, forKey: .browserID)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
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
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules) ?? []
    }
}
