import AppKit
import Combine
import Foundation

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var playlist: [PlaybackTrack] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var turntableSpeed: Double = 0
    @Published private(set) var albumArtImage: NSImage?
    @Published private(set) var playlistProgress: Double = 0

    private static let spinUpDuration: TimeInterval = 1.6
    private static let spinDownDuration: TimeInterval = 2.0
    private static let spinRecoveryDuration: TimeInterval = 0.8
    private static let minimumPlaybackRate: Double = 0.5
    private static let playbackRateCurveExponent: Double = 1.9
    private static let playbackVolumeCurveExponent: Double = 0.8
    private static let rampFrameNanoseconds: UInt64 = 16_666_667
    private static let progressFrameNanoseconds: UInt64 = 16_666_667
    private static let movingThreshold: Double = 0.001

    private enum SpinDownAction {
        case none
        case pause
        case stop(clearSelection: Bool)
    }

    private let loader: PlaylistLoader
    private let engine: AudioPlayerEngine
    private var securityScopedFolderURL: URL?
    private var spinRampTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var pendingSpinDownAction: SpinDownAction = .none

    init(loader: PlaylistLoader, engine: AudioPlayerEngine) {
        self.loader = loader
        self.engine = engine
        bindAudioEngineCallbacks()
    }

    convenience init() {
        self.init(loader: PlaylistLoader(), engine: AudioPlayerEngine())
    }

    deinit {
        spinRampTask?.cancel()
        progressTask?.cancel()

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

    var trackDurations: [TimeInterval] {
        playlist.map { track in
            max(track.duration, 1)
        }
    }

    private var measuredPlaylistProgress: Double {
        guard
            let currentIndex,
            !playlist.isEmpty
        else {
            return 0
        }

        let durations = trackDurations
        let totalDuration = durations.reduce(0, +)
        guard totalDuration > 0, durations.indices.contains(currentIndex) else {
            return 0
        }

        let elapsedBeforeCurrentTrack = durations.prefix(currentIndex).reduce(0, +)
        let currentTrackDuration = durations[currentIndex]
        let clampedCurrentTrackTime = min(max(engine.currentTime, 0), currentTrackDuration)
        let elapsed = elapsedBeforeCurrentTrack + clampedCurrentTrackTime
        return min(max(elapsed / totalDuration, 0), 1)
    }

    // Forward-looking API for arm scrubbing: map a normalized arm position to playlist index.
    func play(atPlaylistProgress progress: Double) {
        guard !playlist.isEmpty else { return }

        let clamped = min(max(progress, 0), 1)
        let maxIndex = playlist.count - 1
        let targetIndex = Int(round(clamped * Double(maxIndex)))
        startTrack(
            at: targetIndex,
            preserveMomentum: isPlaying || isTurntableMoving
        )
    }

    func seek(toPlaylistProgress progress: Double) {
        guard !playlist.isEmpty else { return }

        let durations = trackDurations
        let totalDuration = durations.reduce(0, +)
        guard totalDuration > 0 else {
            play(atPlaylistProgress: progress)
            return
        }

        let clampedProgress = min(max(progress, 0), 1)
        let targetElapsed = clampedProgress * totalDuration

        var elapsed: TimeInterval = 0
        for (index, duration) in durations.enumerated() {
            let nextElapsed = elapsed + duration
            let isTargetTrack = targetElapsed < nextElapsed || index == durations.count - 1
            if !isTargetTrack {
                elapsed = nextElapsed
                continue
            }

            let offsetInTrack = min(max(targetElapsed - elapsed, 0), max(duration - 0.001, 0))
            if currentIndex == index, engine.hasLoadedTrack {
                cancelSpinRamp()
                pendingSpinDownAction = .none
                engine.seek(to: offsetInTrack)
                engine.resume(
                    rate: playbackRate(for: turntableSpeed),
                    volume: playbackVolume(for: turntableSpeed)
                )
                isPlaying = true
                syncProgressTask()
                updatePlaylistProgress(allowBackwardJump: true)
                if !isTurntableMoving {
                    setTurntableSpeed(0)
                }
                rampTurntable(to: 1, duration: Self.spinUpDuration, completionAction: .none)
            } else {
                startTrack(
                    at: index,
                    startTime: offsetInTrack,
                    preserveMomentum: isPlaying || isTurntableMoving
                )
            }
            return
        }
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
            if isSpinDownPendingPause {
                pendingSpinDownAction = .none
                rampTurntable(
                    to: 1,
                    duration: Self.spinRecoveryDuration,
                    completionAction: .none
                )
            } else {
                pauseWithSpinDown()
            }
            return
        }

        if engine.hasLoadedTrack {
            cancelSpinRamp()
            pendingSpinDownAction = .none
            isPlaying = true
            syncProgressTask()
            engine.resume(
                rate: playbackRate(for: turntableSpeed),
                volume: playbackVolume(for: turntableSpeed)
            )
            updatePlaylistProgress(allowBackwardJump: true)
            if !isTurntableMoving {
                setTurntableSpeed(0)
            }
            rampTurntable(to: 1, duration: Self.spinUpDuration, completionAction: .none)
            return
        }

        startTrack(at: currentIndex ?? 0, preserveMomentum: false)
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
        startTrack(
            at: nextIndex,
            preserveMomentum: isPlaying || isTurntableMoving
        )
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
        startTrack(
            at: previousIndex,
            preserveMomentum: isPlaying || isTurntableMoving
        )
    }

    private func bindAudioEngineCallbacks() {
        engine.onFinishPlaying = { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.playNextAfterCurrentTrackFinished()
                } else {
                    self.stopPlayback(clearSelection: true, withSpinDown: false)
                }
            }
        }

        engine.onDecodeError = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopPlayback(clearSelection: true, withSpinDown: false)
            }
        }
    }

    private func loadPlaylist(from folderURL: URL) {
        stopPlayback(clearSelection: true, withSpinDown: false)
        albumArtImage = nil
        beginSecurityScopedAccess(for: folderURL)

        do {
            let tracks = try loader.loadTracks(from: folderURL)
            playlist = tracks
            currentIndex = tracks.isEmpty ? nil : 0
            updatePlaylistProgress(allowBackwardJump: true)

            if let artworkURL = try? loader.loadFirstArtworkURL(from: folderURL) {
                albumArtImage = NSImage(contentsOf: artworkURL)
            }
        } catch {
            playlist = []
            currentIndex = nil
            albumArtImage = nil
            updatePlaylistProgress(allowBackwardJump: true)
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

    private func stopPlayback(clearSelection: Bool, withSpinDown: Bool) {
        guard !withSpinDown else {
            guard isPlaying, engine.hasLoadedTrack else {
                finishStopPlayback(clearSelection: clearSelection)
                return
            }

            rampTurntable(
                to: 0,
                duration: Self.spinDownDuration,
                completionAction: .stop(clearSelection: clearSelection)
            )
            return
        }

        finishStopPlayback(clearSelection: clearSelection)
    }

    private func finishStopPlayback(clearSelection: Bool) {
        cancelSpinRamp()
        pendingSpinDownAction = .none
        engine.stop()
        isPlaying = false
        setTurntableSpeed(0)
        syncProgressTask()

        if clearSelection {
            currentIndex = nil
        }
        updatePlaylistProgress(allowBackwardJump: true)
    }

    private func startTrack(
        at index: Int,
        startTime: TimeInterval = 0,
        preserveMomentum: Bool
    ) {
        guard playlist.indices.contains(index) else {
            stopPlayback(clearSelection: true, withSpinDown: false)
            return
        }

        let track = playlist[index]
        let shouldRampFromRest = !preserveMomentum
        let startRate = shouldRampFromRest ? playbackRate(for: 0) : 1
        let startVolume = shouldRampFromRest ? playbackVolume(for: 0) : 1

        do {
            cancelSpinRamp()
            pendingSpinDownAction = .none
            try engine.play(url: track.url, rate: startRate, volume: startVolume)
            if startTime > 0 {
                engine.seek(to: startTime)
            }
            currentIndex = index
            isPlaying = true
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
            if shouldRampFromRest {
                setTurntableSpeed(0)
                rampTurntable(to: 1, duration: Self.spinUpDuration, completionAction: .none)
            } else if turntableSpeed < 1 {
                rampTurntable(
                    to: 1,
                    duration: Self.spinRecoveryDuration,
                    completionAction: .none
                )
            } else {
                setTurntableSpeed(1)
            }
        } catch {
            isPlaying = false
            setTurntableSpeed(0)
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
        }
    }

    private func playNextAfterCurrentTrackFinished() {
        guard let currentIndex else {
            stopPlayback(clearSelection: true, withSpinDown: true)
            return
        }

        let nextIndex = currentIndex + 1
        guard playlist.indices.contains(nextIndex) else {
            stopPlayback(clearSelection: true, withSpinDown: true)
            return
        }

        startTrack(at: nextIndex, preserveMomentum: true)
    }

    private func pauseWithSpinDown() {
        guard engine.hasLoadedTrack else {
            isPlaying = false
            setTurntableSpeed(0)
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
            return
        }

        rampTurntable(
            to: 0,
            duration: Self.spinDownDuration,
            completionAction: .pause
        )
    }

    private func rampTurntable(
        to targetSpeed: Double,
        duration: TimeInterval,
        completionAction: SpinDownAction
    ) {
        cancelSpinRamp()
        pendingSpinDownAction = completionAction

        let clampedTargetSpeed = min(max(targetSpeed, 0), 1)
        let startingSpeed = min(max(turntableSpeed, 0), 1)

        guard duration > 0 else {
            setTurntableSpeed(clampedTargetSpeed)
            completeSpinRamp()
            return
        }

        spinRampTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let startDate = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startDate)
                let progress = min(max(elapsed / duration, 0), 1)
                let easedProgress = self.easeInOut(progress)
                let nextSpeed = startingSpeed + ((clampedTargetSpeed - startingSpeed) * easedProgress)
                self.setTurntableSpeed(nextSpeed)

                if progress >= 1 {
                    break
                }

                do {
                    try await Task.sleep(nanoseconds: Self.rampFrameNanoseconds)
                } catch {
                    return
                }
            }

            self.setTurntableSpeed(clampedTargetSpeed)
            self.completeSpinRamp()
        }
    }

    private func completeSpinRamp() {
        spinRampTask = nil
        let completionAction = pendingSpinDownAction
        pendingSpinDownAction = .none

        switch completionAction {
        case .none:
            return
        case .pause:
            engine.pause()
            isPlaying = false
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
        case let .stop(clearSelection):
            engine.stop()
            isPlaying = false
            if clearSelection {
                currentIndex = nil
            }
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
        }
    }

    private func cancelSpinRamp() {
        spinRampTask?.cancel()
        spinRampTask = nil
    }

    private func setTurntableSpeed(_ speed: Double) {
        let clampedSpeed = min(max(speed, 0), 1)
        turntableSpeed = clampedSpeed

        guard isPlaying, engine.hasLoadedTrack else { return }
        engine.setPlaybackRate(playbackRate(for: clampedSpeed))
        engine.setPlaybackVolume(playbackVolume(for: clampedSpeed))
    }

    private func updatePlaylistProgress(allowBackwardJump: Bool = false) {
        let measuredProgress = measuredPlaylistProgress
        if allowBackwardJump || measuredProgress >= playlistProgress {
            playlistProgress = measuredProgress
        }
    }

    private func syncProgressTask() {
        if isPlaying, engine.hasLoadedTrack {
            startProgressTaskIfNeeded()
            return
        }
        cancelProgressTask()
    }

    private func startProgressTaskIfNeeded() {
        guard progressTask == nil else { return }

        progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.updatePlaylistProgress()
                do {
                    try await Task.sleep(nanoseconds: Self.progressFrameNanoseconds)
                } catch {
                    return
                }
            }
        }
    }

    private func cancelProgressTask() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func playbackRate(for normalizedSpeed: Double) -> Float {
        let clampedSpeed = min(max(normalizedSpeed, 0), 1)
        let curvedSpeed = pow(clampedSpeed, Self.playbackRateCurveExponent)
        let rate = Self.minimumPlaybackRate + ((1 - Self.minimumPlaybackRate) * curvedSpeed)
        return Float(rate)
    }

    private func playbackVolume(for normalizedSpeed: Double) -> Float {
        let clampedSpeed = min(max(normalizedSpeed, 0), 1)
        // Keep audio present longer at low speeds so pitch/rate stretch is clearly audible.
        let loudness = pow(clampedSpeed, Self.playbackVolumeCurveExponent)
        return Float(loudness)
    }

    private func easeInOut(_ progress: Double) -> Double {
        if progress < 0.5 {
            return 4 * progress * progress * progress
        }

        let shifted = (-2 * progress) + 2
        return 1 - ((shifted * shifted * shifted) / 2)
    }

    private var isTurntableMoving: Bool {
        turntableSpeed > Self.movingThreshold
    }

    private var isSpinDownPendingPause: Bool {
        if case .pause = pendingSpinDownAction {
            return true
        }
        return false
    }
}
