import AppKit
import Foundation
import MediaPlayer

final class PlaybackMediaRemoteBridge {
    typealias CommandHandler = () -> Bool

    private struct NowPlayingSnapshot: Equatable {
        let trackTitle: String?
        let albumTitle: String?
        let artworkIdentifier: ObjectIdentifier?
        let durationBucket: Int
        let elapsedBucket: Int
        let playbackRateBucket: Int
        let isPlaying: Bool
        let canSkipNext: Bool
        let canSkipPrevious: Bool
    }

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private var lastSnapshot: NowPlayingSnapshot?
    private var cachedArtworkIdentifier: ObjectIdentifier?
    private var cachedArtwork: MPMediaItemArtwork?

    deinit {
        clear()
    }

    func configureCommands(
        onTogglePlayPause: @escaping CommandHandler,
        onPlay: @escaping CommandHandler,
        onPause: @escaping CommandHandler,
        onNextTrack: @escaping CommandHandler,
        onPreviousTrack: @escaping CommandHandler
    ) {
        resetCommandTargets()

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            onTogglePlayPause() ? .success : .commandFailed
        }
        commandCenter.playCommand.addTarget { _ in
            onPlay() ? .success : .commandFailed
        }
        commandCenter.pauseCommand.addTarget { _ in
            onPause() ? .success : .commandFailed
        }
        commandCenter.nextTrackCommand.addTarget { _ in
            onNextTrack() ? .success : .commandFailed
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            onPreviousTrack() ? .success : .commandFailed
        }
    }

    func updateNowPlaying(
        trackTitle: String?,
        albumTitle: String?,
        artworkImage: NSImage?,
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        playbackRate: Double,
        isPlaying: Bool,
        canSkipNext: Bool,
        canSkipPrevious: Bool
    ) {
        let artworkIdentifier = artworkImage.map(ObjectIdentifier.init)
        let snapshot = NowPlayingSnapshot(
            trackTitle: trackTitle,
            albumTitle: albumTitle,
            artworkIdentifier: artworkIdentifier,
            durationBucket: Int(max(duration, 0).rounded()),
            elapsedBucket: Int((max(elapsedTime, 0) * 2).rounded()),
            playbackRateBucket: Int((max(playbackRate, 0) * 100).rounded()),
            isPlaying: isPlaying,
            canSkipNext: canSkipNext,
            canSkipPrevious: canSkipPrevious
        )

        if snapshot == lastSnapshot {
            return
        }
        lastSnapshot = snapshot

        let hasTrack = trackTitle != nil
        commandCenter.playCommand.isEnabled = hasTrack
        commandCenter.pauseCommand.isEnabled = hasTrack
        commandCenter.togglePlayPauseCommand.isEnabled = hasTrack
        commandCenter.nextTrackCommand.isEnabled = canSkipNext
        commandCenter.previousTrackCommand.isEnabled = canSkipPrevious

        guard let trackTitle else {
            nowPlayingInfoCenter.nowPlayingInfo = nil
            nowPlayingInfoCenter.playbackState = .stopped
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: trackTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(elapsedTime, 0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? max(playbackRate, 0) : 0
        ]

        if let albumTitle, !albumTitle.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        if let artwork = resolvedArtwork(from: artworkImage) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        if duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        nowPlayingInfoCenter.playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        lastSnapshot = nil
        cachedArtworkIdentifier = nil
        cachedArtwork = nil
        resetCommandTargets()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        nowPlayingInfoCenter.nowPlayingInfo = nil
        nowPlayingInfoCenter.playbackState = .stopped
    }

    private func resetCommandTargets() {
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
    }

    private func resolvedArtwork(from image: NSImage?) -> MPMediaItemArtwork? {
        guard let image else {
            cachedArtworkIdentifier = nil
            cachedArtwork = nil
            return nil
        }

        let identifier = ObjectIdentifier(image)
        if cachedArtworkIdentifier == identifier {
            return cachedArtwork
        }

        let imageSize = image.size
        let boundsSize: CGSize
        if imageSize.width > 0, imageSize.height > 0 {
            boundsSize = CGSize(width: imageSize.width, height: imageSize.height)
        } else {
            boundsSize = CGSize(width: 512, height: 512)
        }

        let artwork = MPMediaItemArtwork(boundsSize: boundsSize) { _ in image }
        cachedArtworkIdentifier = identifier
        cachedArtwork = artwork
        return artwork
    }
}
