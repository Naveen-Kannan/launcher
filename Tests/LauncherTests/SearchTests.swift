import Foundation
import Testing
@testable import Launcher

private func app(_ name: String, _ id: String, alt: [String] = []) -> AppEntry {
    AppEntry(id: id, name: name, alt: alt, url: URL(fileURLWithPath: "/Applications/\(name).app"))
}
private func tmp() -> URL { URL(fileURLWithPath: "/private/tmp/launcher-tests-\(UUID().uuidString)") }

@Test func fuzzyTiersOrderAsDocumented() throws {
    let exact = try #require(Fuzzy.score("notes", "Notes"))
    let prefix = try #require(Fuzzy.score("not", "Notes"))
    let word = try #require(Fuzzy.score("code", "Visual Studio Code"))
    let initials = try #require(Fuzzy.score("vsc", "Visual Studio Code"))
    let scattered = try #require(Fuzzy.score("vsud", "Visual Studio Code"))
    #expect(exact > prefix && prefix > word && word > initials && initials > scattered)
    #expect(Fuzzy.score("edit", "TextEdit") != nil && Fuzzy.score("edit", "TextEdit")! >= 2000)
    #expect(Fuzzy.score("xyz", "Safari") == nil)
    #expect(Fuzzy.score("safarix", "Safari") == nil)
}

@Test func wordStartsSplitOnSeparatorsCamelCaseAndDigits() {
    #expect(Fuzzy.wordStarts(Array("Visual Studio-Code")) == [0, 7, 14])
    #expect(Fuzzy.wordStarts(Array("TextEdit")) == [0, 4])
    #expect(Fuzzy.wordStarts(Array("Office365")) == [0, 6])
}

@Test func rankingPrefersPrefixThenRememberedPick() {
    let apps = [app("Slack", "s"), app("Safari", "sa"), app("System Settings", "ss"), app("Messages", "m")]
    let f = Frecency(url: nil)
    #expect(Ranking.rank(apps, "sa", f).first?.id == "sa")
    #expect(Ranking.rank(apps, "s", f).map(\.id).prefix(2) == ["s", "sa"])  // shorter prefix first
    f.record("sa", query: "saf", now: 0)
    #expect(Ranking.rank(apps, "s", f, now: 0).first?.id == "sa")             // remembered for prefix "s"
    #expect(Ranking.rank(apps, "", f, now: 0).map(\.id) == ["sa"])            // empty query = used apps
    #expect(Ranking.rank(apps, "msg", f).first?.id == "m")                    // scattered still finds it
}

@Test func altNamesMatchSlightlyBelowPrimary() {
    let apps = [app("Visual Studio Code", "vs", alt: ["Code"]), app("Codex", "cx")]
    #expect(Ranking.rank(apps, "code", Frecency(url: nil)).map(\.id) == ["vs", "cx"])
}

@Test func frecencyDecaysAndPersists() throws {
    let url = tmp().appendingPathComponent("frecency.json")
    let f = Frecency(url: url)
    f.record("a", query: "ab", now: 0)
    f.record("a", query: "ab", now: 0)
    #expect(f.boost("a", now: 0) == 2)
    #expect(abs(f.boost("a", now: Frecency.halfLife) - 1) < 1e-9)
    #expect(f.remembered("A") == "a")
    f.flush()
    #expect(Frecency(url: url).file == f.file)
}

@Test func scanFindsBundlesOneLevelDownAndDedupes() throws {
    let root = tmp(), other = tmp()
    func make(_ dir: URL, _ name: String, _ id: String, background: Bool = false) throws {
        let c = dir.appendingPathComponent("\(name).app/Contents")
        try FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        var info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": name]
        if background { info["LSBackgroundOnly"] = true }
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: c.appendingPathComponent("Info.plist"))
    }
    try make(root, "Alpha", "x.alpha")
    try make(root.appendingPathComponent("Vendor"), "Beta", "x.beta")
    try make(root, "Ghost", "x.ghost", background: true)
    try make(other, "Alpha Copy", "x.alpha")
    let apps = AppIndex.scan(roots: [root.path, other.path], extras: [])
    #expect(Set(apps.map(\.id)) == ["x.alpha", "x.beta"])
}

@Test func realScanIsFastAndFindsSystemApps() {
    let t = Date()
    let apps = AppIndex.scan()
    let ms = Date().timeIntervalSince(t) * 1000
    #expect(apps.count > 20)
    #expect(apps.contains { $0.id == "com.apple.finder" })
    #expect(apps.contains { $0.id == "com.apple.Safari" })
    #expect(ms < 1500)
    print("scan: \(apps.count) apps in \(Int(ms)) ms")
}

@Test func searchCommandRegistered() {
    #expect(LauncherCommands().commands["app.search"] != nil)
}
