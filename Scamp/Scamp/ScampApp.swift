import SwiftUI

@main
struct ScampApp: App {
    @StateObject private var playback = PlaybackController()

    var body: some Scene {
        WindowGroup {
            ContentView(playback: playback)
        }
        .defaultSize(width: ScampLayout.windowWidth, height: ScampLayout.windowHeight)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
