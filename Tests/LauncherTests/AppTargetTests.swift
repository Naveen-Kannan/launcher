import Foundation
import Testing
@testable import Launcher

@Test func tunesFallbackTargetsInstalledApp() {
    #expect(AppTarget.tunes.fallbackPath == "/Applications/Electron Tunes.app")
    #expect(AppTarget.tunes.bundleIdentifier == "com.electrontunes.app")
}

@Test func claudeTargetRegistered() {
    #expect(AppTarget.claude.bundleIdentifier == "com.anthropic.claudefordesktop")
    #expect(LauncherCommands().commands["app.claude"] != nil)
}
