import AppKit
import Combine
import Foundation
import MediaPlayer

@MainActor
final class PlaybackController: ObservableObject {
    private static let demoAlbumFilenames = [
        "ISTANBUL (Not Constantinople) - FRANKIE VAUGHAN.mp3",
        "Mr. Sandman - The Chordettes - Archie Bleyer.mp3",
        "Smoke on the Water - Pancho Baird - Pancho Bairds Gitfiddlers-restored.mp3",
        "cover.jpg"
    ]

    @Published private(set) var playlist: [PlaybackTrack] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var turntableSpeed: Double = 0
    @Published private(set) var albumArtImage: NSImage?
    @Published private(set) var playlistProgress: Double = 0
    @Published private(set) var currentAlbumFolderURL: URL?

    private static let spinUpDuration: TimeInterval = 1.6
    private static let spinDownDuration: TimeInterval = 2.0
    private static let spinRecoveryDuration: TimeInterval = 0.8
    private static let recordHoldRampDownDuration: TimeInterval = 0.12
    private static let recordHoldRampUpDuration: TimeInterval = 0.16
    private static let recordHoldSlowMultiplier: Double = 0.5
    private static let minimumPlaybackRate: Double = 0.5
    private static let playbackRateCurveExponent: Double = 1.9
    private static let playbackVolumeCurveExponent: Double = 0.8
    private static let rampFrameNanoseconds: UInt64 = 16_666_667
    private static let progressFrameNanoseconds: UInt64 = 16_666_667
    private static let sessionPersistEveryProgressTicks = 60
    private static let movingThreshold: Double = 0.001
    private static let platterRPM: Double = 33
    private static let persistedSessionDefaultsKey = "playback.session.v1"

    private struct PersistedPlaybackSession: Codable {
        let folderBookmarkData: Data
        let currentTrackPath: String?
        let currentTrackTime: TimeInterval
        let recordRotationDegrees: Double
    }

    private enum SpinDownAction {
        case none
        case pause
        case stop(clearSelection: Bool)
    }

    private let loader: PlaylistLoader
    private let engine: AudioPlayerEngine
    private let mediaRemoteBridge = PlaybackMediaRemoteBridge()
    private var securityScopedFolderURL: URL?
    private var spinRampTask: Task<Void, Never>?
    private var recordHoldRampTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var playlistLoadTask: Task<Void, Never>?
    private var progressTickCount = 0
    private var pendingSpinDownAction: SpinDownAction = .none
    private var baseTurntableSpeed: Double = 0
    private var recordHoldMultiplier: Double = 1
    private var isRecordHoldActive = false
    private var recordRotationOffsetDegrees: Double = 0
    private var recordRotationAnchorDate: Date?
    private var recordRotationAnchorSpeed: Double = 0
    private var restingTrackTime: TimeInterval = 0
    private var pendingResumeTrackPath: String?
    private var pendingResumeTrackTime: TimeInterval = 0

    init(loader: PlaylistLoader, engine: AudioPlayerEngine) {
        self.loader = loader
        self.engine = engine
        configureMediaRemoteCommands()
        bindAudioEngineCallbacks()
        restorePersistedSessionIfAvailable()
        syncMediaRemoteState()
    }

    convenience init() {
        self.init(loader: PlaylistLoader(), engine: AudioPlayerEngine())
    }

    deinit {
        spinRampTask?.cancel()
        recordHoldRampTask?.cancel()
        progressTask?.cancel()
        playlistLoadTask?.cancel()

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

    func recordRotationDegrees(at now: Date = Date()) -> Double {
        guard
            let anchorDate = recordRotationAnchorDate,
            recordRotationAnchorSpeed > 0
        else {
            return recordRotationOffsetDegrees
        }

        let elapsed = max(0, now.timeIntervalSince(anchorDate))
        let degreesPerSecond = (Self.platterRPM / 60) * 360 * recordRotationAnchorSpeed
        return recordRotationOffsetDegrees + (elapsed * degreesPerSecond)
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
        let clampedCurrentTrackTime = min(max(currentTrackElapsedTime, 0), currentTrackDuration)
        let elapsed = elapsedBeforeCurrentTrack + clampedCurrentTrackTime
        return min(max(elapsed / totalDuration, 0), 1)
    }

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
        let shouldAutoplay = isPlaying

        let durations = trackDurations
        let totalDuration = durations.reduce(0, +)
        guard totalDuration > 0 else {
            if shouldAutoplay {
                play(atPlaylistProgress: progress)
            } else {
                let clamped = min(max(progress, 0), 1)
                let maxIndex = playlist.count - 1
                let targetIndex = Int(round(clamped * Double(maxIndex)))
                stagePausedSeekTarget(at: targetIndex, startTime: 0)
            }
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
                engine.seek(to: offsetInTrack)
                restingTrackTime = offsetInTrack
                if shouldAutoplay {
                    cancelSpinRamp()
                    pendingSpinDownAction = .none
                    engine.resume(
                        rate: currentPlaybackRate,
                        volume: currentPlaybackVolume
                    )
                    isPlaying = true
                    syncProgressTask()
                    updatePlaylistProgress(allowBackwardJump: true)
                    if !isTurntableMoving {
                        setTurntableSpeed(0)
                    }
                    rampTurntable(to: 1, duration: Self.spinUpDuration, completionAction: .none)
                    persistSessionState()
                } else {
                    isPlaying = false
                    setTurntableSpeed(0)
                    syncProgressTask()
                    updatePlaylistProgress(allowBackwardJump: true)
                    persistSessionState()
                }
            } else {
                if shouldAutoplay {
                    startTrack(
                        at: index,
                        startTime: offsetInTrack,
                        preserveMomentum: isPlaying || isTurntableMoving
                    )
                } else {
                    stagePausedSeekTarget(at: index, startTime: offsetInTrack)
                }
            }
            return
        }
    }

    func setRecordHoldActive(_ isActive: Bool) {
        guard isRecordHoldActive != isActive else { return }
        isRecordHoldActive = isActive

        rampRecordHoldMultiplier(
            to: isActive ? Self.recordHoldSlowMultiplier : 1,
            duration: isActive ? Self.recordHoldRampDownDuration : Self.recordHoldRampUpDuration
        )
    }

    func loadFolder(from folderURL: URL) {
        playlistLoadTask?.cancel()
        playlistLoadTask = Task { @MainActor [weak self] in
            await self?.loadPlaylist(from: folderURL)
        }
    }

    func loadAlbum(from folderURL: URL) {
        let startsPlaying = isPlaying
        playlistLoadTask?.cancel()
        currentAlbumFolderURL = folderURL
        playlistLoadTask = Task { @MainActor [weak self] in
            await self?.loadPlaylist(from: folderURL, startsPlaying: startsPlaying)
        }
    }

    func folderHasPlayableTracks(_ folderURL: URL) async -> Bool {
        let didStartAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let tracks = try? await loader.loadTracks(from: folderURL) else {
            return false
        }

        return !tracks.isEmpty
    }

    func loadDemoAlbum() {
        guard
            let resourcesURL = Bundle.main.resourceURL,
            let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            return
        }

        let demoAlbumURL = applicationSupportURL
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "ScampMicroDeck", isDirectory: true)
            .appendingPathComponent("Demo Album", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: demoAlbumURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            for filename in Self.demoAlbumFilenames {
                let bundledFileURL = resourcesURL.appendingPathComponent(filename)
                guard FileManager.default.fileExists(atPath: bundledFileURL.path) else {
                    return
                }

                let stagedFileURL = demoAlbumURL.appendingPathComponent(filename)
                if !FileManager.default.fileExists(atPath: stagedFileURL.path) {
                    try FileManager.default.copyItem(at: bundledFileURL, to: stagedFileURL)
                }
            }

            playlistLoadTask?.cancel()
            playlistLoadTask = Task { @MainActor [weak self] in
                await self?.loadPlaylist(from: demoAlbumURL)
            }
        } catch {
            return
        }
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
                rate: currentPlaybackRate,
                volume: currentPlaybackVolume
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

    private func configureMediaRemoteCommands() {
        mediaRemoteBridge.configureCommands(
            onTogglePlayPause: { [weak self] in
                self?.handleRemoteTogglePlayPause() ?? false
            },
            onPlay: { [weak self] in
                self?.handleRemotePlay() ?? false
            },
            onPause: { [weak self] in
                self?.handleRemotePause() ?? false
            },
            onNextTrack: { [weak self] in
                self?.handleRemoteNextTrack() ?? false
            },
            onPreviousTrack: { [weak self] in
                self?.handleRemotePreviousTrack() ?? false
            }
        )
    }

    private func handleRemoteTogglePlayPause() -> Bool {
        guard hasPlaylist else { return false }
        togglePlayPause()
        return true
    }

    private func handleRemotePlay() -> Bool {
        guard hasPlaylist else { return false }
        guard !isPlaying else { return true }
        togglePlayPause()
        return true
    }

    private func handleRemotePause() -> Bool {
        guard hasPlaylist else { return false }
        guard isPlaying else { return true }
        togglePlayPause()
        return true
    }

    private func handleRemoteNextTrack() -> Bool {
        guard !playlist.isEmpty else { return false }
        if let currentIndex, currentIndex + 1 >= playlist.count {
            return false
        }
        playNext()
        return true
    }

    private func handleRemotePreviousTrack() -> Bool {
        guard !playlist.isEmpty else { return false }
        if let currentIndex, currentIndex <= 0 {
            return false
        }
        playPrevious()
        return true
    }

    private func syncMediaRemoteState() {
        guard
            let currentIndex,
            playlist.indices.contains(currentIndex)
        else {
            mediaRemoteBridge.updateNowPlaying(
                trackTitle: nil,
                albumTitle: nil,
                artworkImage: nil,
                duration: 0,
                elapsedTime: 0,
                playbackRate: 0,
                isPlaying: false,
                canSkipNext: false,
                canSkipPrevious: false
            )
            return
        }

        let currentTrack = playlist[currentIndex]
        mediaRemoteBridge.updateNowPlaying(
            trackTitle: currentTrack.displayName,
            albumTitle: currentTrack.albumTitle,
            artworkImage: albumArtImage,
            duration: currentTrack.duration,
            elapsedTime: currentTrackElapsedTime,
            playbackRate: isPlaying ? Double(currentPlaybackRate) : 0,
            isPlaying: isPlaying,
            canSkipNext: canPlayNext,
            canSkipPrevious: canPlayPrevious
        )
    }

    private func loadPlaylist(from folderURL: URL, startsPlaying: Bool = false) async {
        stopPlayback(clearSelection: true, withSpinDown: false)
        resetRecordRotation()
        albumArtImage = nil
        restingTrackTime = 0
        clearPendingResumeState()
        beginSecurityScopedAccess(for: folderURL)

        do {
            let tracks = try await loader.loadTracks(from: folderURL)
            guard !Task.isCancelled else { return }
            playlist = tracks
            currentIndex = tracks.isEmpty ? nil : 0
            currentAlbumFolderURL = tracks.isEmpty ? nil : folderURL
            updatePlaylistProgress(allowBackwardJump: true)

            if let artworkURL = try? loader.loadFirstArtworkURL(from: folderURL) {
                albumArtImage = NSImage(contentsOf: artworkURL)
            }
            syncMediaRemoteState()
            if startsPlaying, !tracks.isEmpty {
                startTrack(at: 0, preserveMomentum: false)
            } else {
                persistSessionState()
            }
        } catch {
            playlist = []
            currentIndex = nil
            albumArtImage = nil
            currentAlbumFolderURL = nil
            restingTrackTime = 0
            updatePlaylistProgress(allowBackwardJump: true)
            clearPersistedSessionState()
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
        resetRecordHoldState()
        pendingSpinDownAction = .none
        engine.stop()
        isPlaying = false
        setTurntableSpeed(0)
        syncProgressTask()

        if clearSelection {
            currentIndex = nil
            restingTrackTime = 0
            clearPendingResumeState()
        }
        updatePlaylistProgress(allowBackwardJump: true)
        persistSessionState()
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
        let resolvedStartTime = resolvedStartTime(for: track, requestedStartTime: startTime)
        let shouldRampFromRest = !preserveMomentum
        let startRate = shouldRampFromRest ? playbackRate(for: 0) : currentPlaybackRate
        let startVolume = shouldRampFromRest ? playbackVolume(for: 0) : currentPlaybackVolume

        do {
            cancelSpinRamp()
            pendingSpinDownAction = .none
            try engine.play(url: track.url, rate: startRate, volume: startVolume)
            if resolvedStartTime > 0 {
                engine.seek(to: resolvedStartTime)
            }
            currentIndex = index
            restingTrackTime = resolvedStartTime
            consumePendingResumeState(for: track)
            isPlaying = true
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
            if shouldRampFromRest {
                setTurntableSpeed(0)
                rampTurntable(to: 1, duration: Self.spinUpDuration, completionAction: .none)
            } else if baseTurntableSpeed < 1 {
                rampTurntable(
                    to: 1,
                    duration: Self.spinRecoveryDuration,
                    completionAction: .none
                )
            } else {
                setTurntableSpeed(1)
            }
            persistSessionState()
        } catch {
            isPlaying = false
            setTurntableSpeed(0)
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
            persistSessionState()
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

    private func stagePausedSeekTarget(at index: Int, startTime: TimeInterval) {
        guard playlist.indices.contains(index) else { return }

        cancelSpinRamp()
        pendingSpinDownAction = .none
        engine.stop()
        currentIndex = index
        restingTrackTime = max(startTime, 0)
        pendingResumeTrackPath = playlist[index].url.path
        pendingResumeTrackTime = restingTrackTime
        isPlaying = false
        setTurntableSpeed(0)
        syncProgressTask()
        updatePlaylistProgress(allowBackwardJump: true)
        persistSessionState()
    }

    private func pauseWithSpinDown() {
        guard engine.hasLoadedTrack else {
            isPlaying = false
            setTurntableSpeed(0)
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
            persistSessionState()
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
        let startingSpeed = min(max(baseTurntableSpeed, 0), 1)

        guard duration > 0, clampedTargetSpeed != startingSpeed else {
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
            restingTrackTime = engine.currentTime
            isPlaying = false
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
            persistSessionState()
        case let .stop(clearSelection):
            engine.stop()
            isPlaying = false
            if clearSelection {
                currentIndex = nil
                restingTrackTime = 0
                clearPendingResumeState()
            }
            syncProgressTask()
            updatePlaylistProgress(allowBackwardJump: true)
            persistSessionState()
        }
    }

    private func cancelSpinRamp() {
        spinRampTask?.cancel()
        spinRampTask = nil
    }

    private func rampRecordHoldMultiplier(to targetMultiplier: Double, duration: TimeInterval) {
        cancelRecordHoldRamp()

        let clampedTargetMultiplier = min(max(targetMultiplier, Self.recordHoldSlowMultiplier), 1)
        let startingMultiplier = min(max(recordHoldMultiplier, Self.recordHoldSlowMultiplier), 1)

        guard duration > 0 else {
            setRecordHoldMultiplier(clampedTargetMultiplier)
            return
        }

        recordHoldRampTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let startDate = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startDate)
                let progress = min(max(elapsed / duration, 0), 1)
                let easedProgress = self.easeInOut(progress)
                let nextMultiplier = startingMultiplier + ((clampedTargetMultiplier - startingMultiplier) * easedProgress)
                self.setRecordHoldMultiplier(nextMultiplier)

                if progress >= 1 {
                    break
                }

                do {
                    try await Task.sleep(nanoseconds: Self.rampFrameNanoseconds)
                } catch {
                    return
                }
            }

            self.setRecordHoldMultiplier(clampedTargetMultiplier)
            self.recordHoldRampTask = nil
        }
    }

    private func cancelRecordHoldRamp() {
        recordHoldRampTask?.cancel()
        recordHoldRampTask = nil
    }

    private func resetRecordHoldState() {
        isRecordHoldActive = false
        cancelRecordHoldRamp()
        recordHoldMultiplier = 1
    }

    private func setRecordHoldMultiplier(_ multiplier: Double) {
        recordHoldMultiplier = min(max(multiplier, Self.recordHoldSlowMultiplier), 1)
        syncRecordRotation(to: effectiveTurntableSpeed, now: Date())
        applyTurntableState()
    }

    private func setTurntableSpeed(_ speed: Double) {
        let clampedSpeed = min(max(speed, 0), 1)
        let previousEffectiveSpeed = effectiveTurntableSpeed
        baseTurntableSpeed = clampedSpeed
        let nextEffectiveSpeed = effectiveTurntableSpeed
        if nextEffectiveSpeed != previousEffectiveSpeed || (nextEffectiveSpeed > 0 && recordRotationAnchorDate == nil) {
            syncRecordRotation(to: nextEffectiveSpeed, now: Date())
        }
        applyTurntableState()
    }

    private func syncRecordRotation(to targetSpeed: Double, now: Date) {
        recordRotationOffsetDegrees = recordRotationDegrees(at: now)
        recordRotationAnchorSpeed = targetSpeed
        recordRotationAnchorDate = targetSpeed > 0 ? now : nil
    }

    private func resetRecordRotation() {
        recordRotationOffsetDegrees = 0
        recordRotationAnchorDate = nil
        recordRotationAnchorSpeed = 0
    }

    private func setRecordRotationOffset(_ degrees: Double) {
        recordRotationOffsetDegrees = degrees
        recordRotationAnchorDate = nil
        recordRotationAnchorSpeed = 0
    }

    private func applyTurntableState() {
        turntableSpeed = effectiveTurntableSpeed

        guard isPlaying, engine.hasLoadedTrack else { return }
        engine.setPlaybackRate(currentPlaybackRate)
        engine.setPlaybackVolume(currentPlaybackVolume)
    }

    private func updatePlaylistProgress(allowBackwardJump: Bool = false) {
        let measuredProgress = measuredPlaylistProgress
        if allowBackwardJump || measuredProgress >= playlistProgress {
            playlistProgress = measuredProgress
        }
        syncMediaRemoteState()
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
                self.progressTickCount += 1
                if self.progressTickCount >= Self.sessionPersistEveryProgressTicks {
                    self.progressTickCount = 0
                    self.persistSessionState()
                }
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
        progressTickCount = 0
    }

    private func playbackRate(for normalizedSpeed: Double) -> Float {
        let clampedSpeed = min(max(normalizedSpeed, 0), 1)
        let curvedSpeed = pow(clampedSpeed, Self.playbackRateCurveExponent)
        let rate = Self.minimumPlaybackRate + ((1 - Self.minimumPlaybackRate) * curvedSpeed)
        return Float(rate)
    }

    private func playbackVolume(for normalizedSpeed: Double) -> Float {
        let clampedSpeed = min(max(normalizedSpeed, 0), 1)
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

    private var effectiveTurntableSpeed: Double {
        min(max(baseTurntableSpeed * recordHoldMultiplier, 0), 1)
    }

    private var currentPlaybackRate: Float {
        let baseRate = playbackRate(for: baseTurntableSpeed)
        let scaledRate = max(Float(Self.minimumPlaybackRate), baseRate * Float(recordHoldMultiplier))
        return scaledRate
    }

    private var currentPlaybackVolume: Float {
        playbackVolume(for: effectiveTurntableSpeed)
    }

    private var isSpinDownPendingPause: Bool {
        if case .pause = pendingSpinDownAction {
            return true
        }
        return false
    }

    private var currentTrackElapsedTime: TimeInterval {
        if engine.hasLoadedTrack {
            return engine.currentTime
        }
        return restingTrackTime
    }

    private var currentTrackURL: URL? {
        guard let currentIndex, playlist.indices.contains(currentIndex) else {
            return nil
        }
        return playlist[currentIndex].url
    }

    private func resolvedStartTime(
        for track: PlaybackTrack,
        requestedStartTime: TimeInterval
    ) -> TimeInterval {
        guard requestedStartTime <= 0 else {
            return max(requestedStartTime, 0)
        }

        guard pendingResumeTrackPath == track.url.path else {
            return max(requestedStartTime, 0)
        }

        return max(pendingResumeTrackTime, 0)
    }

    private func consumePendingResumeState(for track: PlaybackTrack) {
        guard pendingResumeTrackPath == track.url.path else { return }
        clearPendingResumeState()
    }

    private func clearPendingResumeState() {
        pendingResumeTrackPath = nil
        pendingResumeTrackTime = 0
    }

    private func persistSessionState() {
        guard
            let folderURL = securityScopedFolderURL,
            !playlist.isEmpty
        else {
            clearPersistedSessionState()
            return
        }

        guard
            let bookmarkData = try? folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        else {
            return
        }

        let session = PersistedPlaybackSession(
            folderBookmarkData: bookmarkData,
            currentTrackPath: currentTrackURL?.path,
            currentTrackTime: max(currentTrackElapsedTime, 0),
            recordRotationDegrees: recordRotationDegrees(at: Date())
        )

        guard let encoded = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.persistedSessionDefaultsKey)
    }

    private func clearPersistedSessionState() {
        UserDefaults.standard.removeObject(forKey: Self.persistedSessionDefaultsKey)
    }

    private func restorePersistedSessionIfAvailable() {
        Task { @MainActor [weak self] in
            await self?.restorePersistedSession()
        }
    }

    private func restorePersistedSession() async {
        guard
            let encoded = UserDefaults.standard.data(forKey: Self.persistedSessionDefaultsKey),
            let session = try? JSONDecoder().decode(PersistedPlaybackSession.self, from: encoded)
        else {
            return
        }

        var bookmarkIsStale = false
        guard
            let folderURL = try? URL(
                resolvingBookmarkData: session.folderBookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &bookmarkIsStale
            )
        else {
            clearPersistedSessionState()
            return
        }

        await loadPlaylist(from: folderURL)
        guard !playlist.isEmpty else { return }

        if
            let currentTrackPath = session.currentTrackPath,
            let restoredIndex = playlist.firstIndex(where: { $0.url.path == currentTrackPath })
        {
            currentIndex = restoredIndex
        } else {
            currentIndex = 0
        }

        let trackIndex = currentIndex ?? 0
        let trackDuration = max(trackDurations[trackIndex], 0)
        let restoredTime = min(max(session.currentTrackTime, 0), max(trackDuration - 0.001, 0))
        restingTrackTime = restoredTime

        if let currentIndex, playlist.indices.contains(currentIndex) {
            pendingResumeTrackPath = playlist[currentIndex].url.path
            pendingResumeTrackTime = restoredTime
        } else {
            clearPendingResumeState()
        }

        setRecordRotationOffset(session.recordRotationDegrees)
        updatePlaylistProgress(allowBackwardJump: true)

        if bookmarkIsStale {
            persistSessionState()
        }
    }
}
