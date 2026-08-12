import Foundation
import ShuntCore
import Testing

@Suite struct URLMatching {
    private func matches(_ pattern: String, _ urlString: String) -> Bool {
        RuleMatcher.urlMatches(pattern: pattern, url: URL(string: urlString)!)
    }

    @Test func exactMatch() {
        #expect(matches("example.com", "https://example.com"))
        #expect(matches("Example.COM", "https://example.com"))
        #expect(!matches("example.com", "https://www.example.com"))
        #expect(!matches("example.com", "https://example.org"))
    }

    @Test func wildcardSubdomains() {
        #expect(matches("*.atlassian.net", "https://acme.atlassian.net"))
        #expect(matches("*.atlassian.net", "https://a.b.atlassian.net"))
        #expect(!matches("*.atlassian.net", "https://atlassian.com"))
        #expect(!matches("*.atlassian.net", "https://notatlassian.net"))
    }

    @Test func wildcardMatchesApex() {
        #expect(matches("*.atlassian.net", "https://atlassian.net"))
    }

    @Test func infixWildcard() {
        #expect(matches("github.*", "https://github.io"))
        #expect(matches("*", "https://anything.example"))
    }

    @Test func emptyAndWhitespace() {
        #expect(!matches("", "https://example.com"))
        #expect(matches("  example.com ", "https://example.com"))
    }

    @Test func hostPatternMatchesAnyPath() {
        #expect(matches("example.com", "https://example.com/"))
        #expect(matches("example.com", "https://example.com/some/deep/path"))
    }

    @Test func pathPatternNarrowsWithinAHost() {
        #expect(matches("github.com/nyaruka/*", "https://github.com/nyaruka/shunt"))
        #expect(matches("github.com/nyaruka/*", "https://github.com/nyaruka/shunt/pull/6"))
        #expect(!matches("github.com/nyaruka/*", "https://github.com/rowanseymour/shunt"))
        #expect(!matches("github.com/nyaruka/*", "https://gitlab.com/nyaruka/shunt"))
    }

    @Test func trailingWildcardAlsoMatchesTheBarePath() {
        #expect(matches("github.com/nyaruka/*", "https://github.com/nyaruka"))
        #expect(!matches("github.com/nyaruka/*", "https://github.com"))
    }

    @Test func pathPatternCombinesWithSubdomainWildcard() {
        #expect(matches("*.atlassian.net/wiki/*", "https://acme.atlassian.net/wiki/spaces/ENG"))
        #expect(matches("*.atlassian.net/wiki/*", "https://atlassian.net/wiki"))
        #expect(!matches("*.atlassian.net/wiki/*", "https://acme.atlassian.net/browse/ENG-1"))
    }

    @Test func trailingSlashesAreIgnoredOnBothSides() {
        #expect(matches("example.com/docs", "https://example.com/docs/"))
        #expect(matches("example.com/docs/", "https://example.com/docs"))
    }

    @Test func queryStringsAreNotMatched() {
        #expect(matches("github.com/nyaruka", "https://github.com/nyaruka?tab=repositories"))
        #expect(!matches("github.com/*tab=repositories*", "https://github.com/nyaruka?tab=repositories"))
    }
}

@Suite struct RuleMatching {
    private let chrome = "com.google.Chrome"
    private let slack = "com.tinyspeck.slackmacgap"

    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func firstMatchWins() {
        let rules = [
            Rule(pattern: "*.example.com", browserID: "first"),
            Rule(pattern: "www.example.com", browserID: "second"),
        ]
        let match = RuleMatcher.firstMatch(for: url("https://www.example.com/x"), sourceApp: nil, in: rules)
        #expect(match?.browserID == "first")
    }

    @Test func disabledRulesAreSkipped() {
        let rules = [
            Rule(pattern: "example.com", browserID: "off", enabled: false),
            Rule(pattern: "example.com", browserID: "on"),
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

    @Test func sourceAppPlusPatternRequiresBoth() {
        let rule = Rule(pattern: "*.zoom.us", sourceApp: slack, browserID: chrome)
        #expect(RuleMatcher.matches(rule, url: url("https://us02.zoom.us/j/1"), sourceApp: slack))
        #expect(!RuleMatcher.matches(rule, url: url("https://us02.zoom.us/j/1"), sourceApp: nil))
        #expect(!RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: slack))
    }

    @Test func patternRuleIgnoresSourceAppWhenUnset() {
        let rule = Rule(pattern: "example.com", browserID: chrome)
        #expect(RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: slack))
        #expect(RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: nil))
    }

    @Test func noPatternNoSourceAppNeverMatches() {
        let rule = Rule(browserID: chrome)
        #expect(!RuleMatcher.matches(rule, url: url("https://example.com"), sourceApp: nil))
    }

    @Test func urlWithoutHostNeverMatches() {
        let rule = Rule(pattern: "*", browserID: chrome)
        #expect(!RuleMatcher.matches(rule, url: url("mailto:a@b.com"), sourceApp: nil))
    }
}

@Suite struct ChromiumProfileParsing {
    @Test func parsesInfoCacheSortedByName() {
        let json = #"""
        {"profile": {"info_cache": {
            "Profile 1": {"name": "Work", "gaia_name": "Rowan"},
            "Default": {"name": "Personal"}
        }}}
        """#
        let profiles = ChromiumProfiles.parse(localState: Data(json.utf8))
        #expect(profiles == [
            BrowserProfile(directory: "Default", name: "Personal"),
            BrowserProfile(directory: "Profile 1", name: "Work"),
        ])
    }

    @Test func fallsBackToDirectoryWhenNameMissingOrEmpty() {
        let json = #"{"profile": {"info_cache": {"Profile 2": {"name": ""}, "Profile 3": {}}}}"#
        let profiles = ChromiumProfiles.parse(localState: Data(json.utf8))
        #expect(profiles.map(\.name) == ["Profile 2", "Profile 3"])
    }

    @Test func malformedLocalStateGivesNoProfiles() {
        #expect(ChromiumProfiles.parse(localState: Data("not json".utf8)).isEmpty)
        #expect(ChromiumProfiles.parse(localState: Data("{}".utf8)).isEmpty)
        #expect(ChromiumProfiles.parse(localState: Data(#"{"profile": {}}"#.utf8)).isEmpty)
    }

    @Test func dataDirectoriesForKnownBrowsersOnly() {
        #expect(ChromiumProfiles.dataDirectory(forBundleID: "com.google.Chrome") == "Google/Chrome")
        #expect(ChromiumProfiles.dataDirectory(forBundleID: "com.brave.Browser") == "BraveSoftware/Brave-Browser")
        #expect(ChromiumProfiles.dataDirectory(forBundleID: "com.apple.Safari") == nil)
        #expect(ChromiumProfiles.dataDirectory(forBundleID: "org.mozilla.firefox") == nil)
    }
}

@Suite struct ConfigCodable {
    @Test func decodesMinimalHandEditedConfig() throws {
        let json = #"{"rules": [{"pattern": "*.example.com", "browserID": "com.google.Chrome"}]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(config.fallbackBrowserID == "com.apple.Safari")
        #expect(config.rules.count == 1)
        #expect(config.rules[0].enabled)
        #expect(config.rules[0].sourceApp == nil)
        #expect(config.rules[0].profile == nil)
    }

    @Test func legacyPatternListExpandsIntoOneRulePerPattern() throws {
        let json = #"""
        {"rules": [
            {"patterns": ["localhost", "127.0.0.1"], "browserID": "com.google.Chrome", "profile": "Profile 1"},
            {"sourceApp": "com.tinyspeck.slackmacgap", "browserID": "com.apple.Safari"}
        ]}
        """#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(config.rules.map(\.pattern) == ["localhost", "127.0.0.1", nil])
        #expect(config.rules.prefix(2).allSatisfy { $0.browserID == "com.google.Chrome" && $0.profile == "Profile 1" })
        #expect(config.rules[2].sourceApp == "com.tinyspeck.slackmacgap")
        // Expanded rules can't share an identity or SwiftUI lists misbehave.
        #expect(Set(config.rules.map(\.id)).count == 3)
    }

    @Test func roundTrips() throws {
        let config = Config(
            fallbackBrowserID: "org.mozilla.firefox",
            rules: [Rule(pattern: "localhost", sourceApp: "com.apple.dt.Xcode", browserID: "com.google.Chrome", profile: "Profile 1", enabled: false)]
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded.fallbackBrowserID == config.fallbackBrowserID)
        #expect(decoded.rules == config.rules)
    }
}
