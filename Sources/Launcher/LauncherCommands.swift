public struct LauncherCommands {
    public let name = "launcher"

    public let commands: [String: () -> Void] = [
        AppTarget.term.command: { AppLauncher.open(.term) },
        AppTarget.chrome.command: { AppLauncher.open(.chrome) },
        AppTarget.outlook.command: { AppLauncher.open(.outlook) },
        AppTarget.messages.command: { AppLauncher.open(.messages) },
        AppTarget.notes.command: { AppLauncher.open(.notes) },
        AppTarget.cursor.command: { AppLauncher.open(.cursor) },
        AppTarget.codex.command: { AppLauncher.open(.codex) },
        AppTarget.muse.command: { AppLauncher.open(.muse) },
        AppTarget.antigravity.command: { AppLauncher.open(.antigravity) },
        AppTarget.tunes.command: { AppLauncher.open(.tunes) },
        TunesAction.playPause.command: { AppLauncher.controlTunes(.playPause) },
        TunesAction.next.command: { AppLauncher.controlTunes(.next) },
        TunesAction.previous.command: { AppLauncher.controlTunes(.previous) },
        "app.search": { SearchPanel.shared.toggle() },
    ]

    public init() {}

    // Builds the app-search index in the background so the first app.search is instant.
    public func start() { SearchPanel.shared.warm() }
}
