import SwiftUI

struct ContentView: View {
    @ObservedObject var playback: PlaybackController
    @Binding var tableTheme: TableTheme
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            EmptyView()
                .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
        } detail: {
            DeckWorkspaceView(playback: playback, tableTheme: $tableTheme)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .background(TitlebarSidebarButtonHider())
        .frame(width: ScampLayout.windowWidth, height: ScampLayout.windowHeight)
    }
}

#Preview {
    ContentView(
        playback: PlaybackController(),
        tableTheme: .constant(.wood)
    )
}
