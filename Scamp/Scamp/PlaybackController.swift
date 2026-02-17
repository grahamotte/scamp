import AppKit
import AVFoundation
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class PlaybackController: NSObject, ObservableObject {
    @Published private(set) var playlist: [URL] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false

    private var audioPlayer: AVAudioPlayer?
    private var securityScopedFolderURL: URL?

    var currentTrackDisplayName: String? {
        guard let index = currentIndex, playlist.indices.contains(index) else {
            return nil
        }
        return playlist[index].deletingPathExtension().lastPathComponent
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
            audioPlayer?.pause()
            isPlaying = false
            return
        }

        if let player = audioPlayer {
            player.play()
            isPlaying = true
            return
        }

        startTrack(at: currentIndex ?? 0, autoplay: true)
    }

    func playNext() {
        guard !playlist.isEmpty else { return }

        let nextIndex: Int
        if let index = currentIndex {
            nextIndex = index + 1
        } else {
            nextIndex = 0
        }

        guard playlist.indices.contains(nextIndex) else { return }
        startTrack(at: nextIndex, autoplay: true)
    }

    func playPrevious() {
        guard !playlist.isEmpty else { return }

        let previousIndex: Int
        if let index = currentIndex {
            previousIndex = index - 1
        } else {
            previousIndex = 0
        }

        guard playlist.indices.contains(previousIndex) else { return }
        startTrack(at: previousIndex, autoplay: true)
    }

    deinit {
        if let folderURL = securityScopedFolderURL {
            folderURL.stopAccessingSecurityScopedResource()
        }
    }

    private func loadPlaylist(from folderURL: URL) {
        stopPlayback(clearSelection: true)
        beginSecurityScopedAccess(for: folderURL)

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentTypeKey]
        let urls: [URL]

        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
        } catch {
            playlist = []
            return
        }

        let audioURLs = urls
            .filter { url in
                guard
                    let resourceValues = try? url.resourceValues(forKeys: keys),
                    resourceValues.isRegularFile == true
                else {
                    return false
                }

                if let contentType = resourceValues.contentType {
                    return contentType.conforms(to: .audio)
                }

                return false
            }
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }

        playlist = audioURLs
        currentIndex = audioURLs.isEmpty ? nil : 0
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
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false

        if clearSelection {
            currentIndex = nil
        }
    }

    private func startTrack(at index: Int, autoplay: Bool) {
        guard playlist.indices.contains(index) else {
            stopPlayback(clearSelection: true)
            return
        }

        let trackURL = playlist[index]

        do {
            let player = try AVAudioPlayer(contentsOf: trackURL)
            player.delegate = self
            player.prepareToPlay()
            audioPlayer = player
            currentIndex = index

            if autoplay {
                player.play()
                isPlaying = true
            } else {
                isPlaying = false
            }
        } catch {
            isPlaying = false
        }
    }

    private func playNextAfterCurrentTrackFinished() {
        guard let index = currentIndex else {
            stopPlayback(clearSelection: true)
            return
        }

        let nextIndex = index + 1
        guard playlist.indices.contains(nextIndex) else {
            stopPlayback(clearSelection: true)
            return
        }

        startTrack(at: nextIndex, autoplay: true)
    }
}

extension PlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if flag {
                self.playNextAfterCurrentTrackFinished()
            } else {
                self.stopPlayback(clearSelection: true)
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            self?.stopPlayback(clearSelection: true)
        }
    }
}
