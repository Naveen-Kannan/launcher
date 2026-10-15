import Foundation

// Tiers: exact > prefix > word start > initials ("vsc") > scattered letters.
// Inside a tier: shorter/earlier wins; scattered matches earn word-start and run bonuses, lose on gaps.
enum Fuzzy {
    static func score(_ query: String, _ name: String) -> Int? {
        let orig = Array(name), c = orig.map { Character($0.lowercased()) }, q = Array(query.lowercased())
        guard !q.isEmpty else { return 0 }
        guard q.count <= c.count else { return nil }
        if q == c { return 5000 }
        if c.starts(with: q) { return 4000 - (c.count - q.count) }
        let starts = wordStarts(orig)
        if let s = starts.first(where: { c[$0...].starts(with: q) }) { return 3000 - s }
        if starts.map({ c[$0] }).starts(with: q) { return 2500 - starts.count }
        return scattered(q, c, Set(starts))
    }

    // Word starts: index 0, after separators, lower->Upper (camelCase), letter->digit.
    static func wordStarts(_ s: [Character]) -> [Int] {
        var out: [Int] = []
        for i in s.indices {
            let cur = s[i]
            guard cur.isLetter || cur.isNumber else { continue }
            if i == 0 { out.append(i); continue }
            let prev = s[i - 1]
            if !(prev.isLetter || prev.isNumber) || (prev.isLowercase && cur.isUppercase) || (prev.isLetter && cur.isNumber) {
                out.append(i)
            }
        }
        return out
    }

    private static func scattered(_ q: [Character], _ c: [Character], _ starts: Set<Int>) -> Int? {
        var score = 1000, pos = 0, last = -2
        for ch in q {
            guard let i = c[pos...].firstIndex(of: ch) else { return nil }
            score += (starts.contains(i) ? 12 : 0) + (i == last + 1 ? 8 : 0) - min(i - pos, 6)
            last = i
            pos = i + 1
        }
        return max(1, score)
    }
}

// Picks decay with a 10-day half-life; the last app picked for a typed prefix is remembered.
final class Frecency {
    struct Hit: Codable, Equatable { var s: Double; var t: Double }
    struct File: Codable, Equatable { var apps: [String: Hit] = [:]; var queries: [String: String] = [:] }

    static let halfLife = 10.0 * 86400, maxQueries = 600
    private(set) var file = File()
    private let url: URL?
    private let io = DispatchQueue(label: "com.nkannan.launcher.frecency", qos: .utility)

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("launcher/frecency.json")
    }

    init(url: URL?) {
        self.url = url
        guard let url, let data = try? Data(contentsOf: url) else { return }
        file = (try? JSONDecoder().decode(File.self, from: data)) ?? File()
    }

    func boost(_ id: String, now: Double = Date().timeIntervalSince1970) -> Double {
        guard let h = file.apps[id] else { return 0 }
        return h.s * pow(0.5, max(0, now - h.t) / Frecency.halfLife)
    }

    func remembered(_ query: String) -> String? { file.queries[query.lowercased()] }

    func record(_ id: String, query: String, now: Double = Date().timeIntervalSince1970) {
        file.apps[id] = Hit(s: boost(id, now: now) + 1, t: now)
        let q = Array(query.lowercased())
        for n in stride(from: 1, through: min(q.count, 8), by: 1) { file.queries[String(q[..<n])] = id }
        if file.queries.count > Frecency.maxQueries { file.queries = file.queries.filter { $0.key.count <= 3 } }
        save()
    }

    func flush() { io.sync {} }

    private func save() {
        guard let url else { return }
        let snapshot = file
        io.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }
}

enum Ranking {
    // Remembered pick for this exact prefix first, then tier score + capped frecency.
    // Empty query = most-used apps.
    static func rank(_ apps: [AppEntry], _ query: String, _ f: Frecency, limit: Int = 8, now: Double = Date().timeIntervalSince1970) -> [AppEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            return Array(apps.filter { f.boost($0.id, now: now) > 0.05 }.sorted { f.boost($0.id, now: now) > f.boost($1.id, now: now) }.prefix(limit))
        }
        let pick = f.remembered(q)
        var scored: [(AppEntry, Double)] = []
        for a in apps {
            let best = ([a.name].compactMap { Fuzzy.score(q, $0) } + a.alt.compactMap { Fuzzy.score(q, $0).map { $0 - 50 } }).max()
            guard let s = best else { continue }
            scored.append((a, Double(s) + min(400, f.boost(a.id, now: now) * 40) + (a.id == pick ? 3000 : 0)))
        }
        return scored.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name < $1.0.name }.prefix(limit).map(\.0)
    }
}
