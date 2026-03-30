public struct LauncherCommands {
    public let name = "launcher"

    public let commands: [String: () -> Void] = [
        AppTarget.term.command: { AppLauncher.open(.term) },
        AppTarget.chrome.command: { AppLauncher.open(.chrome) },
        AppTarget.outlook.command: { AppLauncher.open(.outlook) },
        AppTarget.messages.command: { AppLauncher.open(.messages) },
        AppTarget.notes.command: { AppLauncher.open(.notes) },
        AppTarget.cursor.command: { AppLauncher.open(.cursor) },
        AppTarget.antigravity.command: { AppLauncher.open(.antigravity) },
        AppTarget.tunes.command: { AppLauncher.open(.tunes) },
    ]

    public init() {}
}
