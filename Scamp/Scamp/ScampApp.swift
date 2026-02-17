import SwiftUI

@main
struct ScampApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: ScampLayout.windowWidth, height: ScampLayout.windowHeight)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
