import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var playback: PlaybackController
    @Binding var tableTheme: TableTheme
    @Binding var recordTheme: RecordTheme
    @Binding var controlsTheme: ControlsTheme
    @Binding var showsHowToUse: Bool
    let dismissHowToUse: () -> Void
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            EmptyView()
                .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
        } detail: {
            DeckWorkspaceView(
                playback: playback,
                tableTheme: $tableTheme,
                recordTheme: $recordTheme,
                controlsTheme: $controlsTheme
            )
        }
        .navigationSplitViewStyle(.balanced)
        .containerBackground(Color.clear, for: .window)
        .toolbar(removing: .sidebarToggle)
        .background(TitlebarSidebarButtonHider())
        .background(ThemeWindowConfigurator())
        .frame(width: ScampMicroDeckLayout.windowWidth, height: ScampMicroDeckLayout.windowHeight)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil, perform: handleFolderDrop(providers:))
        .sheet(isPresented: $showsHowToUse) {
            HowToUseSheet(onOK: dismissHowToUse)
                .interactiveDismissDisabled()
        }
    }

    private func handleFolderDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            Task { @MainActor in
                guard let folderURL = droppedURL(from: item), folderURL.isDirectory else {
                    showsHowToUse = true
                    return
                }

                guard await playback.folderHasPlayableTracks(folderURL) else {
                    showsHowToUse = true
                    return
                }

                playback.loadFolder(from: folderURL)
            }
        }

        return true
    }

    private func droppedURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }
}

#Preview {
    ContentView(
        playback: PlaybackController(),
        tableTheme: .constant(.wood),
        recordTheme: .constant(.black),
        controlsTheme: .constant(.silver),
        showsHowToUse: .constant(true),
        dismissHowToUse: {}
    )
}

private extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

private struct HowToUseSheet: View {
    let onOK: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How to Use")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                Text("Scamp Micro Deck is designed to feel a bit like using a real vinyl record player.")

                Text("To load your first album, click the \(Image(systemName: "eject.fill")) eject button.")
                Text("Choose a folder with audio files and album art, and Scamp Micro Deck will start playing from there.")
                Text("You can also drag a folder straight into the window to load it.")
                Text("Want a quick test? Use \(Text("Help > Load Demo Album").bold()) to load the bundled sample record.")
                Text("Want to switch albums? Just press \(Image(systemName: "eject.fill")) again and pick a different folder.")
                Text("You can always come back to this later from \(Text("Help > Scamp Micro Deck Help").bold()).")
            }
            .fixedSize(horizontal: false, vertical: true)

            Button {
                onOK()
            } label: {
                Text("OK")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 420)
    }
}
