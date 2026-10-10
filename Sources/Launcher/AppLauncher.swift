import AppKit
import Foundation
import os.log

private let log = Logger(subsystem: "com.nkannan.launcher", category: "launcher")
private let tunesControlBaseURL = URL(string: "http://127.0.0.1:47631")!

enum AppLauncher {
    static func open(_ target: AppTarget) {
        open(target, activates: true)
    }

    static func open(_ target: AppTarget, activates: Bool) {
        guard let url = resolveURL(for: target) else {
            log.error("app not found: \(target.command, privacy: .public)")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = activates

        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                log.error("failed to open \(target.command, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func controlTunes(_ action: TunesAction) {
        sendTunesControl(action, logFailures: true) { _ in }
    }

    private static func resolveURL(for target: AppTarget) -> URL? {
        if let bundleIdentifier = target.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }

        guard let fallbackPath = target.fallbackPath else {
            return nil
        }
        return FileManager.default.fileExists(atPath: fallbackPath) ? URL(fileURLWithPath: fallbackPath) : nil
    }

    private static func sendTunesControl(
        _ action: TunesAction,
        logFailures: Bool = false,
        completion: @escaping (Bool) -> Void
    ) {
        let url = tunesControlBaseURL.appending(path: "control").appending(path: action.path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 0.4

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                if logFailures {
                    log.error("tunes control failed for \(action.command, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
                completion(false)
                return
            }

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                if logFailures {
                    log.error("tunes control rejected for \(action.command, privacy: .public)")
                }
                completion(false)
                return
            }

            completion(true)
        }.resume()
    }
}

struct AppTarget {
    let command: String
    let bundleIdentifier: String?
    let fallbackPath: String?

    static let term = AppTarget(
        command: "app.term",
        bundleIdentifier: "org.alacritty",
        fallbackPath: "/Applications/term.app"
    )

    static let chrome = AppTarget(
        command: "app.chrome",
        bundleIdentifier: "com.google.Chrome",
        fallbackPath: "/Applications/Google Chrome.app"
    )

    static let outlook = AppTarget(
        command: "app.outlook",
        bundleIdentifier: "com.microsoft.Outlook",
        fallbackPath: "/Applications/Microsoft Outlook.app"
    )

    static let messages = AppTarget(
        command: "app.messages",
        bundleIdentifier: "com.apple.MobileSMS",
        fallbackPath: "/System/Applications/Messages.app"
    )

    static let notes = AppTarget(
        command: "app.notes",
        bundleIdentifier: "com.apple.Notes",
        fallbackPath: "/System/Applications/Notes.app"
    )

    static let cursor = AppTarget(
        command: "app.cursor",
        bundleIdentifier: "com.todesktop.230313mzl4w4u92",
        fallbackPath: "/Applications/Cursor.app"
    )

    static let codex = AppTarget(
        command: "app.codex",
        bundleIdentifier: "com.openai.codex",
        fallbackPath: "/Applications/ChatGPT.app"
    )

    static let muse = AppTarget(
        command: "app.muse",
        bundleIdentifier: "com.meta.endo",
        fallbackPath: "/Applications/Muse.app"
    )

    static let antigravity = AppTarget(
        command: "app.antigravity",
        bundleIdentifier: "com.google.antigravity",
        fallbackPath: "/Applications/Antigravity.app"
    )

    static let tunes = AppTarget(
        command: "app.tunes",
        bundleIdentifier: "com.electrontunes.app",
        fallbackPath: workspaceRoot()
            .appendingPathComponent("tunes/electron-tunes/dist/mac-arm64/Electron Tunes.app")
            .path
    )

    private static func workspaceRoot(file: String = #filePath) -> URL {
        URL(fileURLWithPath: file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

enum TunesAction {
    case playPause
    case next
    case previous

    var command: String {
        switch self {
        case .playPause: "tunes.play_pause"
        case .next: "tunes.next"
        case .previous: "tunes.previous"
        }
    }

    var path: String {
        switch self {
        case .playPause: "play_pause"
        case .next: "next"
        case .previous: "previous"
        }
    }
}
