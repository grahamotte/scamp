import AppKit
import SwiftUI

struct LibraryCommands: Commands {
    @ObservedObject var library: AlbumLibraryController
    let playback: PlaybackController
    @Binding var showsLibrary: Bool

    init(
        library: AlbumLibraryController,
        playback: PlaybackController,
        showsLibrary: Binding<Bool>
    ) {
        self.library = library
        self.playback = playback
        _showsLibrary = showsLibrary
    }

    var body: some Commands {
        CommandMenu("Library") {
            Button("Open Album Folder…") {
                openAlbumFolder()
            }
            .keyboardShortcut("o")

            Divider()

            Button(library.musicFolderURL == nil ? "Choose Music Folder…" : "Change Music Folder…") {
                chooseMusicFolder()
            }

            Button("Close Library") {
                showsLibrary = false
            }
            .disabled(!showsLibrary)

            Divider()

            Menu("Sort") {
                Picker("Sort", selection: sortOrder) {
                    ForEach(AlbumLibrarySort.allCases) { sortOrder in
                        Text(sortOrder.displayName)
                            .tag(sortOrder)
                    }
                }
                .pickerStyle(.inline)
            }

            Divider()

            Button("Clear Library and Stats") {
                clearLibraryAndStats()
            }
        }
    }

    private var sortOrder: Binding<AlbumLibrarySort> {
        Binding(
            get: { library.sortOrder },
            set: { library.setSortOrder($0) }
        )
    }

    private func openAlbumFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose an album folder containing MP3s and cover art."

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        playback.loadFolder(from: folderURL)
    }

    private func chooseMusicFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose your music folder. It should contain Artist › Album › songs and cover art."

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        Task {
            await library.setMusicFolder(folderURL)
        }
    }

    private func clearLibraryAndStats() {
        let alert = NSAlert()
        alert.messageText = "Clear Library and Stats?"
        alert.informativeText = "This will forget the selected music folder and permanently reset all library history and play counts."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        library.clearLibraryAndStats()
    }
}
