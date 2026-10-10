import Foundation
import Testing
@testable import Launcher

@Test func tunesFallbackTargetsInstalledApp() {
    #expect(AppTarget.tunes.fallbackPath == "/Applications/Electron Tunes.app")
    #expect(AppTarget.tunes.bundleIdentifier == "com.electrontunes.app")
}
