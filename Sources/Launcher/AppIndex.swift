import AppKit

struct AppEntry: Equatable {
    let id: String        // bundle id, or path when missing
    let name: String      // localized display name
    let alt: [String]     // file name / CFBundleName when they differ
    let url: URL
}

// Own app list: Spotlight's index is shared with every file and goes stale or empty.
// Top-level folders are watched; a change rescans after a short debounce.
final class AppIndex {
    static let roots = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                        "/System/Library/CoreServices/Applications", "/System/Volumes/Preboot/Cryptexes/App/System/Applications",
                        NSHomeDirectory() + "/Applications"]
    static let extras = ["/System/Library/CoreServices/Finder.app"]

    private(set) var apps: [AppEntry] = []
    var onChange: (() -> Void)?
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.nkannan.launcher.index", qos: .utility)

    var started: Bool { !sources.isEmpty }

    func start() {
        guard !started else { return }
        refresh()
        for path in AppIndex.roots {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
            s.setEventHandler { [weak self] in self?.schedule() }
            s.setCancelHandler { close(fd) }
            s.resume()
            sources.append(s)
        }
    }

    private func schedule() {
        pending?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.refresh() }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: w)
    }

    private func refresh() {
        queue.async { [weak self] in
            let a = AppIndex.scan()
            DispatchQueue.main.async { self?.apps = a; self?.onChange?() }
        }
    }

    // .app bundles in each root and one folder level below (vendor folders); first id wins.
    static func scan(roots: [String] = roots, extras: [String] = extras) -> [AppEntry] {
        let fm = FileManager.default
        var urls: [URL] = extras.map { URL(fileURLWithPath: $0) }
        for root in roots {
            for name in (try? fm.contentsOfDirectory(atPath: root)) ?? [] where !name.hasPrefix(".") {
                let u = URL(fileURLWithPath: root).appendingPathComponent(name)
                if name.hasSuffix(".app") { urls.append(u); continue }
                var dir: ObjCBool = false
                guard fm.fileExists(atPath: u.path, isDirectory: &dir), dir.boolValue else { continue }
                for sub in (try? fm.contentsOfDirectory(atPath: u.path)) ?? [] where sub.hasSuffix(".app") {
                    urls.append(u.appendingPathComponent(sub))
                }
            }
        }
        var seen = Set<String>()
        return urls.compactMap(entry).filter { seen.insert($0.id).inserted }
    }

    static func entry(_ url: URL) -> AppEntry? {
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        if info["LSBackgroundOnly"] as? Bool == true { return nil }
        let file = url.deletingPathExtension().lastPathComponent
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        let alt = [file, info["CFBundleName"] as? String, info["CFBundleDisplayName"] as? String]
            .compactMap { $0 }.filter { !$0.isEmpty && $0 != name }
        return AppEntry(id: info["CFBundleIdentifier"] as? String ?? url.path, name: name, alt: Array(Set(alt)).sorted(), url: url)
    }
}
