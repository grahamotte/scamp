import SwiftUI

struct ContentView: View {
    @StateObject private var playback = PlaybackController()
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            EmptyView()
                .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
        } detail: {
            DeckWorkspaceView(playback: playback)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .background(TitlebarSidebarButtonHider())
        .frame(width: ScampLayout.windowWidth, height: ScampLayout.windowHeight)
    }
}

#Preview {
    ContentView()
}
