import Foundation
import ShuntCore
import Testing

@Suite struct HostMatching {
    @Test func exactMatch() {
        #expect(RuleMatcher.hostMatches(pattern: "example.com", host: "example.com"))
        #expect(RuleMatcher.hostMatches(pattern: "Example.COM", host: "example.com"))
        #expect(!RuleMatcher.hostMatches(pattern: "example.com", host: "www.example.com"))
        #expect(!RuleMatcher.hostMatches(pattern: "example.com", host: "example.org"))
    }

    @Test func wildcardSubdomains() {
        #expect(RuleMatcher.hostMatches(pattern: "*.atlassian.net", host: "acme.atlassian.net"))
        #expect(RuleMatcher.hostMatches(pattern: "*.atlassian.net", host: "a.b.atlassian.net"))
        #expect(!RuleMatcher.hostMatches(pattern: "*.atlassian.net", host: "atlassian.com"))
        #expect(!RuleMatcher.hostMatches(pattern: "*.atlassian.net", host: "notatlassian.net"))
    }

    @Test func wildcardMatchesApex() {
        #expect(RuleMatcher.hostMatches(pattern: "*.atlassian.net", host: "atlassian.net"))
    }

    @Test func infixWildcard() {
        #expect(RuleMatcher.hostMatches(pattern: "github.*", host: "github.io"))
        #expect(RuleMatcher.hostMatches(pattern: "*", host: "anything.example"))
    }

    @Test func emptyAndWhitespace() {
        #expect(!RuleMatcher.hostMatches(pattern: "", host: "example.com"))
        #expect(RuleMatcher.hostMatches(pattern: "  example.com ", host: "example.com"))
    }
}

@Suite struct RuleMatching {
    private let chrome = "com.google.Chrome"
    private let slack = "com.tinyspeck.slackmacgap"

    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func firstMatchWins() {
        let rules = [
            Rule(patterns: ["*.example.com"], browserID: "first"),
            Rule(patterns: ["www.example.com"], browserID: "second"),
        ]
        let match = RuleMatcher.firstMatch(for: url("https://www.example.com/x"), sourceApp: nil, in: rules)
        #expect(match?.browserID == "first")
    }

    @Test func disabledRulesAreSkipped() {
        let rules = [
            Rule(patterns: ["example.com"], browserID: "off", enabled: false),
            Rule(patterns: ["example.com"], browserID: "on"),
        ]
        let match = RuleMatcher.firstMatch(for: url("https://example.com"), sourceApp: nil, in: rules)
        #expect(match?.browserID == "on")
    }

    @Test func sourceAppOnlyRuleMatchesAnyURLFromThatApp() {
        let rule = Rule(sourceApp: slack, browserID: chrome)
        #expect(RuleMatcher.matches(rule, url: url("https://anything.example"), sourceApp: slack))
        #expect(!RuleMatcher.matches(rule, url: url("https://anything.example"), sourceApp: nil))
        #expect(!RuleMatcher.matches(rule, url: url("https://anything.example"), sourceApp: "com.apple.mail"))
    }

    @Test func sourceAppPlusPatternsRequiresBoth() {
        let rule = Rule(patterns: ["*.zoom.us"], sourceApp: slack, browserID: chrome)
        #expect(RuleMatcher.matches(rule, url: url("https://us02.zoom.us/j/1"), sourceApp: slack))
        #expect(!RuleMatcher.matches(rule, url: url("https://us02.zoom.us/j/1"), sourceApp: nil))
        #expect(!RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: slack))
    }

    @Test func patternRuleIgnoresSourceAppWhenUnset() {
        let rule = Rule(patterns: ["example.com"], browserID: chrome)
        #expect(RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: slack))
        #expect(RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: nil))
    }

    @Test func noPatternsNoSourceAppNeverMatches() {
        let rule = Rule(browserID: chrome)
        #expect(!RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: nil))
    }

    @Test func urlWithoutHostNeverMatches() {
        let rule = Rule(patterns: ["*"], browserID: chrome)
        #expect(!RuleMatcher.matches(rule, url: url("mailto:a@b.com"), sourceApp: nil))
    }
}

@Suite struct ConfigCodable {
    @Test func decodesMinimalHandEditedConfig() throws {
        let json = #"{"rules": [{"patterns": ["*.example.com"], "browserID": "com.google.Chrome"}]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(config.fallbackBrowserID == "com.apple.Safari")
        #expect(config.rules.count == 1)
        #expect(config.rules[0].enabled)
        #expect(config.rules[0].sourceApp == nil)
    }

    @Test func roundTrips() throws {
        let config = Config(
            fallbackBrowserID: "org.mozilla.firefox",
            rules: [Rule(patterns: ["localhost"], sourceApp: "com.apple.dt.Xcode", browserID: "com.google.Chrome", enabled: false)]
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded.fallbackBrowserID == config.fallbackBrowserID)
        #expect(decoded.rules == config.rules)
    }
}
