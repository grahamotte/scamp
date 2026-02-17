import AppKit
import Combine
import Foundation

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var playlist: [PlaybackTrack] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false

    private let loader: PlaylistLoader
    private let engine: AudioPlayerEngine
    private var securityScopedFolderURL: URL?

    init(loader: PlaylistLoader, engine: AudioPlayerEngine) {
        self.loader = loader
        self.engine = engine
        bindAudioEngineCallbacks()
    }

    convenience init() {
        self.init(loader: PlaylistLoader(), engine: AudioPlayerEngine())
    }

    deinit {
        if let folderURL = securityScopedFolderURL {
            folderURL.stopAccessingSecurityScopedResource()
        }
    }

    var hasPlaylist: Bool {
        !playlist.isEmpty
    }

    var canPlayPrevious: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var canPlayNext: Bool {
        guard let currentIndex else { return false }
        return currentIndex + 1 < playlist.count
    }

    var currentTrackDisplayName: String? {
        guard let currentIndex, playlist.indices.contains(currentIndex) else {
            return nil
        }
        return playlist[currentIndex].displayName
    }

    // Forward-looking API for arm scrubbing: map a normalized arm position to playlist index.
    func play(atPlaylistProgress progress: Double) {
        guard !playlist.isEmpty else { return }

        let clamped = min(max(progress, 0), 1)
        let maxIndex = playlist.count - 1
        let targetIndex = Int(round(clamped * Double(maxIndex)))
        startTrack(at: targetIndex)
    }

    func loadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Load"
        panel.message = "Choose a folder containing audio files."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        loadPlaylist(from: folderURL)
    }

    func togglePlayPause() {
        guard !playlist.isEmpty else { return }

        if isPlaying {
            engine.pause()
            isPlaying = false
            return
        }

        if engine.hasLoadedTrack {
            engine.resume()
            isPlaying = true
            return
        }

        startTrack(at: currentIndex ?? 0)
    }

    func playNext() {
        guard !playlist.isEmpty else { return }

        let nextIndex: Int
        if let currentIndex {
            nextIndex = currentIndex + 1
        } else {
            nextIndex = 0
        }

        guard playlist.indices.contains(nextIndex) else { return }
        startTrack(at: nextIndex)
    }

    func playPrevious() {
        guard !playlist.isEmpty else { return }

        let previousIndex: Int
        if let currentIndex {
            previousIndex = currentIndex - 1
        } else {
            previousIndex = 0
        }

        guard playlist.indices.contains(previousIndex) else { return }
        startTrack(at: previousIndex)
    }

    private func bindAudioEngineCallbacks() {
        engine.onFinishPlaying = { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.playNextAfterCurrentTrackFinished()
                } else {
                    self.stopPlayback(clearSelection: true)
                }
            }
        }

        engine.onDecodeError = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopPlayback(clearSelection: true)
            }
        }
    }

    private func loadPlaylist(from folderURL: URL) {
        stopPlayback(clearSelection: true)
        beginSecurityScopedAccess(for: folderURL)

        do {
            let tracks = try loader.loadTracks(from: folderURL)
            playlist = tracks
            currentIndex = tracks.isEmpty ? nil : 0
        } catch {
            playlist = []
            currentIndex = nil
        }
    }

    private func beginSecurityScopedAccess(for folderURL: URL) {
        if let activeURL = securityScopedFolderURL {
            activeURL.stopAccessingSecurityScopedResource()
            securityScopedFolderURL = nil
        }

        if folderURL.startAccessingSecurityScopedResource() {
            securityScopedFolderURL = folderURL
        }
    }

    private func stopPlayback(clearSelection: Bool) {
        engine.stop()
        isPlaying = false

        if clearSelection {
            currentIndex = nil
        }
    }

    private func startTrack(at index: Int) {
        guard playlist.indices.contains(index) else {
            stopPlayback(clearSelection: true)
            return
        }

        let track = playlist[index]

        do {
            try engine.play(url: track.url)
            currentIndex = index
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    private func playNextAfterCurrentTrackFinished() {
        guard let currentIndex else {
            stopPlayback(clearSelection: true)
            return
        }

        let nextIndex = currentIndex + 1
        guard playlist.indices.contains(nextIndex) else {
            stopPlayback(clearSelection: true)
            return
        }

        startTrack(at: nextIndex)
    }
}
