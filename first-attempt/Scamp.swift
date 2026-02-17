import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct Track: Identifiable {
    let id = UUID()
    let url: URL
    let duration: TimeInterval

    var title: String { url.lastPathComponent }
}

@MainActor
final class PlaybackController: NSObject, ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var loadedFiles: [URL] = []
    @Published private(set) var coverArt: NSImage?
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var isTonearmScrubbing = false

    func loadTracksFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK else { return }

        let collected = panel.urls.flatMap(gatherFiles(from:))

        var seenPaths = Set<String>()
        let uniqueFiles = collected.filter { seenPaths.insert($0.path).inserted }
        let selectedFiles = uniqueFiles.sorted { lhs, rhs in
            let left = lhs.lastPathComponent.localizedLowercase
            let right = rhs.lastPathComponent.localizedLowercase
            if left == right {
                return lhs.path.localizedLowercase < rhs.path.localizedLowercase
            }
            return left < right
        }

        loadedFiles = selectedFiles
        if let imageURL = selectedFiles.first(where: isImageURL) {
            coverArt = NSImage(contentsOf: imageURL)
        } else {
            coverArt = nil
        }

        let newTracks = selectedFiles
            .filter(isAudioURL)
            .compactMap(makeTrack)
            .sorted { lhs, rhs in
                let left = lhs.title.localizedLowercase
                let right = rhs.title.localizedLowercase
                if left == right {
                    return lhs.url.path.localizedLowercase < rhs.url.path.localizedLowercase
                }
                return left < right
            }

        stopPlaybackAndResetState(clearLoadedMedia: false)
        tracks = newTracks
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
            isPlaying = false
            stopTimer()
            return
        }

        if let player {
            player.play()
            isPlaying = true
            startTimer()
            return
        }

        guard !tracks.isEmpty else { return }
        startPlayback(at: currentIndex ?? 0)
    }

    func playNextTrack() {
        guard !tracks.isEmpty else { return }
        let nextIndex = (currentIndex ?? -1) + 1
        guard tracks.indices.contains(nextIndex) else { return }
        startPlayback(at: nextIndex)
    }

    func playPreviousTrack() {
        guard !tracks.isEmpty else { return }
        guard let currentIndex else {
            startPlayback(at: 0)
            return
        }

        let previousIndex = currentIndex - 1
        guard tracks.indices.contains(previousIndex) else { return }
        startPlayback(at: previousIndex)
    }

    func trackProgress(at index: Int) -> Double {
        guard let currentIndex else { return 0 }
        if index < currentIndex { return 1 }
        if index > currentIndex { return 0 }

        let duration = tracks[index].duration
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var overallProgress: Double {
        let total = tracks.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return 0 }
        guard let currentIndex else { return 0 }

        let completed = tracks.prefix(currentIndex).reduce(0) { $0 + $1.duration }
        return min(max((completed + currentTime) / total, 0), 1)
    }

    var currentTrackTitle: String {
        guard let currentIndex, tracks.indices.contains(currentIndex) else {
            return "No Track Loaded"
        }
        return tracks[currentIndex].title
    }

    var currentTrackDisplayName: String {
        guard let currentIndex, tracks.indices.contains(currentIndex) else {
            return ""
        }
        return tracks[currentIndex].url.deletingPathExtension().lastPathComponent
    }

    func seekToOverallProgress(_ progress: Double) {
        guard !tracks.isEmpty else { return }

        let clampedProgress = min(max(progress, 0), 1)
        let totalDuration = tracks.reduce(0) { $0 + $1.duration }
        guard totalDuration > 0 else { return }

        let targetTime = clampedProgress * totalDuration
        var elapsed: TimeInterval = 0

        for (index, track) in tracks.enumerated() {
            let nextElapsed = elapsed + track.duration
            if targetTime <= nextElapsed || index == tracks.count - 1 {
                let offsetInTrack = targetTime - elapsed
                startPlayback(at: index, startTime: offsetInTrack)
                return
            }
            elapsed = nextElapsed
        }
    }

    func setTonearmScrubbing(_ isScrubbing: Bool) {
        isTonearmScrubbing = isScrubbing
        applyTonearmScrubMuteState()
    }

    private func startPlayback(at index: Int, startTime: TimeInterval = 0) {
        guard tracks.indices.contains(index) else { return }

        stopTimer()

        do {
            let player = try AVAudioPlayer(contentsOf: tracks[index].url)
            player.delegate = self
            player.prepareToPlay()
            let maxStartTime = max(player.duration - 0.05, 0)
            let boundedStartTime = min(max(startTime, 0), maxStartTime)
            player.currentTime = boundedStartTime
            player.volume = isTonearmScrubbing ? 0 : 1
            player.play()

            self.player = player
            currentIndex = index
            currentTime = boundedStartTime
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }

    private func stopPlaybackAndResetState(clearLoadedMedia: Bool) {
        player?.stop()
        player = nil
        isPlaying = false
        currentIndex = nil
        currentTime = 0
        stopTimer()

        if clearLoadedMedia {
            tracks = []
            loadedFiles = []
            coverArt = nil
        }
    }

    private func startTimer() {
        stopTimer()
        let newTimer = Timer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(handleTimerTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func gatherFiles(from url: URL) -> [URL] {
        var results: [URL] = []
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return results
        }

        if isDirectory.boolValue {
            let keys: [URLResourceKey] = [.isRegularFileKey]
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                guard isRegularFile(fileURL) else { continue }
                results.append(fileURL)
            }
        } else if isRegularFile(url) {
            results.append(url)
        }

        return results
    }

    private func isAudioURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return UTType(filenameExtension: ext)?.conforms(to: .audio) == true
    }

    private func isImageURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return UTType(filenameExtension: ext)?.conforms(to: .image) == true
    }

    private func isRegularFile(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
           let isRegularFile = values.isRegularFile {
            return isRegularFile
        }
        return false
    }

    private func makeTrack(from url: URL) -> Track? {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        let seconds = player.duration
        guard seconds.isFinite, seconds > 0 else { return nil }
        return Track(url: url, duration: seconds)
    }

    @objc private func handleTimerTick() {
        guard let player else { return }
        currentTime = player.currentTime
    }

    private func applyTonearmScrubMuteState() {
        guard let player else { return }
        player.volume = isTonearmScrubbing ? 0 : 1
    }
}

@MainActor
extension PlaybackController {
    private func handleTrackFinished(playerDuration: TimeInterval) {
        currentTime = playerDuration
        guard let currentIndex else {
            isPlaying = false
            stopTimer()
            return
        }

        let nextIndex = currentIndex + 1
        if tracks.indices.contains(nextIndex) {
            startPlayback(at: nextIndex)
        } else {
            isPlaying = false
            stopTimer()
            player = nil
        }
    }
}

extension PlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let duration = player.duration
        Task { @MainActor [weak self] in
            self?.handleTrackFinished(playerDuration: duration)
        }
    }
}

struct CoverArtView: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.9))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
        }
        .clipShape(Circle())
    }
}

private struct WoodGrainOverlay: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let strideValue: CGFloat = 8
                let rows = Int(size.height / strideValue) + 1

                for row in 0..<rows {
                    let y = CGFloat(row) * strideValue
                    let wave = sin(Double(row) * 0.28) + (sin(Double(row) * 0.11) * 0.6)
                    let thickness = 3 + (cos(Double(row) * 0.25) * 1.2)
                    let offset = CGFloat(wave) * 4
                    let rect = CGRect(x: -20, y: y + offset, width: size.width + 40, height: max(thickness, 1.5))
                    let shade = 0.08 + (abs(sin(Double(row) * 0.41)) * 0.08)
                    context.fill(Path(rect), with: .color(Color.black.opacity(shade)))
                }
            }
            .mask(
                Group {
                    if cornerRadius > 0 {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    } else {
                        Rectangle()
                    }
                }
            )
        }
        .allowsHitTesting(false)
    }
}

private struct TurntableControlRow: View {
    let systemImage: String
    let label: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.92), Color(white: 0.61), Color(white: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .stroke(Color.white.opacity(0.88), lineWidth: 1.4)
                        .padding(2)

                    Circle()
                        .stroke(Color.black.opacity(0.22), lineWidth: 1.3)
                        .padding(0.5)

                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(white: 0.2))
                }
                .frame(width: 33, height: 33)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
                .tracking(0.7)
        }
        .opacity(isDisabled ? 0.48 : 1)
    }
}

struct TurntableDeckView: View {
    let tonearmProgress: Double
    let recordRotationDegrees: Double
    let coverArt: NSImage?
    let trackDurations: [TimeInterval]
    let isPlaying: Bool
    let deckLabel: String
    let canPlayPrevious: Bool
    let canPlayNext: Bool
    let onLoadTapped: () -> Void
    let onPreviousTapped: () -> Void
    let onPlayPauseTapped: () -> Void
    let onNextTapped: () -> Void
    let onTonearmDragChanged: (Double) -> Void
    let onTonearmDragEnded: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let plinthRect = CGRect(origin: .zero, size: geometry.size)
            let recordInset = plinthRect.height * 0.05
            let recordDiameter = plinthRect.height - (recordInset * 2)
            let recordCenter = CGPoint(x: plinthRect.minX + recordInset + (recordDiameter / 2), y: plinthRect.midY)
            let pivot = CGPoint(x: plinthRect.minX + (plinthRect.width * 0.79), y: plinthRect.minY + (plinthRect.height * 0.2))
            let tonearmLength = width * 0.38
            let coverRadius = recordDiameter * 0.15
            let outerPlayableRadius = recordDiameter * 0.49
            let innerPlayableRadius = max(coverRadius + (recordDiameter * 0.02), recordDiameter * 0.17)
            let (sweepStartAngle, sweepEndAngle) = sweepAngles(
                pivot: pivot,
                recordCenter: recordCenter,
                tonearmLength: tonearmLength,
                outerPlayableRadius: outerPlayableRadius,
                innerPlayableRadius: innerPlayableRadius
            )
            let clampedProgress = min(max(tonearmProgress, 0), 1)
            let tonearmAngle = sweepStartAngle + (clampedProgress * (sweepEndAngle - sweepStartAngle))
            let tonearmTip = tipPoint(from: pivot, length: tonearmLength, angle: tonearmAngle)
            let tonearmPath = bentTonearmPath(pivot: pivot, tip: tonearmTip)
            let cartridgeCenter = tipPoint(from: tonearmTip, length: 16, angle: tonearmAngle)
            let counterweightAngle = tonearmAngle + 180
            let counterweightJoint = tipPoint(from: pivot, length: 34, angle: counterweightAngle)
            let counterweightCenter = tipPoint(from: pivot, length: 56, angle: counterweightAngle)
            let pivotPlateCenter = CGPoint(x: pivot.x + 4, y: pivot.y - 6)
            let screwOffsets = [
                CGSize(width: -34, height: -25),
                CGSize(width: 32, height: -25),
                CGSize(width: -34, height: 25),
                CGSize(width: 32, height: 25)
            ]
            let grooveRadii = grooveBoundaryRadii(
                outerPlayableRadius: outerPlayableRadius,
                innerPlayableRadius: innerPlayableRadius,
                trackDurations: trackDurations
            )

            ZStack {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.21), Color(white: 0.11)],
                                center: .center,
                                startRadius: 10,
                                endRadius: recordDiameter * 0.54
                            )
                        )

                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 2.6)
                        .padding(recordDiameter * 0.02)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.14), Color(white: 0.05)],
                                center: .center,
                                startRadius: 12,
                                endRadius: recordDiameter * 0.5
                            )
                        )
                        .padding(recordDiameter * 0.05)

                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1.4)
                        .frame(width: outerPlayableRadius * 2, height: outerPlayableRadius * 2)

                    ForEach(Array(grooveRadii.enumerated()), id: \.offset) { index, radius in
                        Circle()
                            .stroke(Color.white.opacity(index.isMultiple(of: 2) ? 0.13 : 0.09), lineWidth: 1.1)
                            .frame(width: radius * 2, height: radius * 2)
                    }

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.72), Color(white: 0.46)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: recordDiameter * 0.34, height: recordDiameter * 0.34)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.72), lineWidth: 1.2)
                                .padding(recordDiameter * 0.01)
                        )

                    CoverArtView(image: coverArt)
                        .frame(width: recordDiameter * 0.3, height: recordDiameter * 0.3)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.86), Color(white: 0.4)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: recordDiameter * 0.04
                            )
                        )
                        .frame(width: recordDiameter * 0.04, height: recordDiameter * 0.04)
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.8))
                }
                .frame(width: recordDiameter, height: recordDiameter)
                .rotationEffect(.degrees(recordRotationDegrees))
                .position(recordCenter)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.84), Color(white: 0.63)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.78), lineWidth: 1.4)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.24), lineWidth: 1.1)
                            .padding(0.8)
                    )
                    .position(pivotPlateCenter)

                ForEach(0..<screwOffsets.count, id: \.self) { index in
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 0.8))
                        .position(
                            x: pivotPlateCenter.x + screwOffsets[index].width,
                            y: pivotPlateCenter.y + screwOffsets[index].height
                        )
                }

                Path { path in
                    path.move(to: pivot)
                    path.addLine(to: counterweightJoint)
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(white: 0.92), Color(white: 0.66)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.86), Color(white: 0.58), Color(white: 0.76)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 22)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(counterweightAngle))
                    .position(counterweightCenter)

                tonearmPath
                    .stroke(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.67), Color(white: 0.84)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )

                tonearmPath
                    .stroke(
                        Color.white.opacity(0.5),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.9), Color(white: 0.56)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
                    .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1.2).padding(0.7))
                    .position(pivot)

                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: width * 0.44, height: height * 0.58)
                    .position(x: width * 0.72, y: height * 0.34)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let angle = clampedTonearmAngle(
                                    for: value.location,
                                    pivot: pivot,
                                    minAngle: sweepStartAngle,
                                    maxAngle: sweepEndAngle
                                )
                                onTonearmDragChanged(progress(for: angle, minAngle: sweepStartAngle, maxAngle: sweepEndAngle))
                            }
                            .onEnded { value in
                                let angle = clampedTonearmAngle(
                                    for: value.location,
                                    pivot: pivot,
                                    minAngle: sweepStartAngle,
                                    maxAngle: sweepEndAngle
                                )
                                onTonearmDragEnded(progress(for: angle, minAngle: sweepStartAngle, maxAngle: sweepEndAngle))
                            }
                    )

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.12), Color(white: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(tonearmAngle))
                    .position(cartridgeCenter)

                Circle()
                    .fill(Color(white: 0.95))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 0.8))
                    .position(tonearmTip)

                VStack(alignment: .leading, spacing: 8) {
                    TurntableControlRow(
                        systemImage: "square.and.arrow.down",
                        label: "Load",
                        isDisabled: false,
                        action: onLoadTapped
                    )
                    TurntableControlRow(
                        systemImage: "backward.fill",
                        label: "Prev",
                        isDisabled: !canPlayPrevious,
                        action: onPreviousTapped
                    )
                    TurntableControlRow(
                        systemImage: isPlaying ? "pause.fill" : "play.fill",
                        label: isPlaying ? "Pause" : "Play",
                        isDisabled: trackDurations.isEmpty,
                        action: onPlayPauseTapped
                    )
                    TurntableControlRow(
                        systemImage: "forward.fill",
                        label: "Next",
                        isDisabled: !canPlayNext,
                        action: onNextTapped
                    )
                }
                .position(x: pivot.x + 36, y: pivot.y + 126)

                Text(deckLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .position(x: plinthRect.maxX - 100, y: plinthRect.maxY - 28)
            }
        }
    }

    private func tipPoint(from pivot: CGPoint, length: CGFloat, angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: pivot.x + cos(radians) * length,
            y: pivot.y + sin(radians) * length
        )
    }

    private func bentTonearmPath(pivot: CGPoint, tip: CGPoint) -> Path {
        var path = Path()
        let dx = tip.x - pivot.x
        let dy = tip.y - pivot.y
        let distance = hypot(dx, dy)
        guard distance > 0.01 else {
            path.move(to: pivot)
            path.addLine(to: tip)
            return path
        }

        let unitX = dx / distance
        let unitY = dy / distance
        let perpendicularX = -unitY
        let perpendicularY = unitX
        let bend = min(max(distance * 0.13, 16), 42)

        let shoulder = CGPoint(
            x: pivot.x + (unitX * distance * 0.26) + (perpendicularX * bend * 0.54),
            y: pivot.y + (unitY * distance * 0.26) + (perpendicularY * bend * 0.54)
        )
        let elbow = CGPoint(
            x: pivot.x + (unitX * distance * 0.58) + (perpendicularX * bend),
            y: pivot.y + (unitY * distance * 0.58) + (perpendicularY * bend)
        )
        let neck = CGPoint(
            x: pivot.x + (unitX * distance * 0.83) + (perpendicularX * bend * 0.34),
            y: pivot.y + (unitY * distance * 0.83) + (perpendicularY * bend * 0.34)
        )

        path.move(to: pivot)
        path.addQuadCurve(
            to: shoulder,
            control: CGPoint(
                x: pivot.x + (unitX * distance * 0.11) + (perpendicularX * bend * 0.3),
                y: pivot.y + (unitY * distance * 0.11) + (perpendicularY * bend * 0.3)
            )
        )
        path.addQuadCurve(
            to: elbow,
            control: CGPoint(
                x: pivot.x + (unitX * distance * 0.42) + (perpendicularX * bend * 0.95),
                y: pivot.y + (unitY * distance * 0.42) + (perpendicularY * bend * 0.95)
            )
        )
        path.addQuadCurve(
            to: neck,
            control: CGPoint(
                x: pivot.x + (unitX * distance * 0.71) + (perpendicularX * bend * 0.86),
                y: pivot.y + (unitY * distance * 0.71) + (perpendicularY * bend * 0.86)
            )
        )
        path.addLine(to: tip)
        return path
    }

    private func clampedTonearmAngle(
        for location: CGPoint,
        pivot: CGPoint,
        minAngle: Double,
        maxAngle: Double
    ) -> Double {
        var angle = atan2(location.y - pivot.y, location.x - pivot.x) * 180 / .pi
        if angle < 0 { angle += 360 }
        return min(max(angle, minAngle), maxAngle)
    }

    private func progress(for angle: Double, minAngle: Double, maxAngle: Double) -> Double {
        let span = maxAngle - minAngle
        guard span > 0 else { return 0 }
        return min(max((angle - minAngle) / span, 0), 1)
    }

    private func sweepAngles(
        pivot: CGPoint,
        recordCenter: CGPoint,
        tonearmLength: CGFloat,
        outerPlayableRadius: CGFloat,
        innerPlayableRadius: CGFloat
    ) -> (Double, Double) {
        let fallbackStart = 104.0
        let fallbackEnd = 136.0

        guard
            let outerPoint = lowerIntersectionPoint(
                centerA: pivot,
                radiusA: tonearmLength,
                centerB: recordCenter,
                radiusB: outerPlayableRadius
            ),
            let innerPoint = lowerIntersectionPoint(
                centerA: pivot,
                radiusA: tonearmLength,
                centerB: recordCenter,
                radiusB: innerPlayableRadius
            )
        else {
            return (fallbackStart, fallbackEnd)
        }

        let start = angle(from: pivot, to: outerPoint)
        let end = angle(from: pivot, to: innerPoint)
        if end <= start { return (fallbackStart, fallbackEnd) }
        return (start, end)
    }

    private func grooveBoundaryRadii(
        outerPlayableRadius: CGFloat,
        innerPlayableRadius: CGFloat,
        trackDurations: [TimeInterval]
    ) -> [CGFloat] {
        guard trackDurations.count > 1 else { return [] }
        let totalDuration = trackDurations.reduce(0, +)
        guard totalDuration > 0 else { return [] }

        var elapsed: TimeInterval = 0
        var radii: [CGFloat] = []

        for duration in trackDurations.dropLast() {
            elapsed += duration
            let fraction = min(max(elapsed / totalDuration, 0), 1)
            let radius = outerPlayableRadius - (CGFloat(fraction) * (outerPlayableRadius - innerPlayableRadius))
            radii.append(radius)
        }

        return radii
    }

    private func lowerIntersectionPoint(
        centerA: CGPoint,
        radiusA: CGFloat,
        centerB: CGPoint,
        radiusB: CGFloat
    ) -> CGPoint? {
        let dx = centerB.x - centerA.x
        let dy = centerB.y - centerA.y
        let distance = hypot(dx, dy)

        guard distance > 0 else { return nil }
        guard abs(radiusA - radiusB) <= distance, distance <= radiusA + radiusB else {
            return nil
        }

        let a = ((radiusA * radiusA) - (radiusB * radiusB) + (distance * distance)) / (2 * distance)
        let squaredHeight = (radiusA * radiusA) - (a * a)
        guard squaredHeight >= 0 else { return nil }
        let height = sqrt(squaredHeight)

        let midX = centerA.x + (a * dx / distance)
        let midY = centerA.y + (a * dy / distance)
        let offsetX = -dy * (height / distance)
        let offsetY = dx * (height / distance)

        let point1 = CGPoint(x: midX + offsetX, y: midY + offsetY)
        let point2 = CGPoint(x: midX - offsetX, y: midY - offsetY)
        return point1.y >= point2.y ? point1 : point2
    }

    private func angle(from pivot: CGPoint, to point: CGPoint) -> Double {
        var degrees = atan2(point.y - pivot.y, point.x - pivot.x) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return degrees
    }
}

struct ContentView: View {
    @StateObject private var playback = PlaybackController()
    @State private var draggedTonearmProgress: Double?
    @State private var isDraggingTonearm = false
    private let platterRPM: Double = 33.0
    @State private var platterDegrees: Double = 0
    @State private var lastPlatterTick: Date?

    private var canPlayPrevious: Bool {
        guard let index = playback.currentIndex else { return false }
        return index > 0
    }

    private var canPlayNext: Bool {
        guard let index = playback.currentIndex else { return !playback.tracks.isEmpty }
        return index < playback.tracks.count - 1
    }

    private var displayedTonearmProgress: Double {
        if let draggedTonearmProgress {
            return draggedTonearmProgress
        }
        return playback.overallProgress
    }

    private var deckLabel: String {
        if playback.isPlaying {
            let name = playback.currentTrackDisplayName
            return name.isEmpty ? "SCAMP MICRO DECK" : name
        }
        return "SCAMP MICRO DECK"
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playback.isPlaying)) { context in
            TurntableDeckView(
                tonearmProgress: displayedTonearmProgress,
                recordRotationDegrees: platterDegrees,
                coverArt: playback.coverArt,
                trackDurations: playback.tracks.map(\.duration),
                isPlaying: playback.isPlaying,
                deckLabel: deckLabel,
                canPlayPrevious: canPlayPrevious,
                canPlayNext: canPlayNext,
                onLoadTapped: { playback.loadTracksFromOpenPanel() },
                onPreviousTapped: { playback.playPreviousTrack() },
                onPlayPauseTapped: { playback.togglePlayPause() },
                onNextTapped: { playback.playNextTrack() },
                onTonearmDragChanged: { progress in
                    if !isDraggingTonearm {
                        isDraggingTonearm = true
                        playback.setTonearmScrubbing(true)
                    }
                    draggedTonearmProgress = progress
                },
                onTonearmDragEnded: { progress in
                    isDraggingTonearm = false
                    draggedTonearmProgress = nil
                    playback.seekToOverallProgress(progress)
                    playback.setTonearmScrubbing(false)
                }
            )
            .onChange(of: context.date, initial: true) { _, date in
                stepPlatter(to: date)
            }
        }
        .frame(minWidth: 1040, minHeight: 680)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.24, green: 0.14, blue: 0.08),
                        Color(red: 0.18, green: 0.10, blue: 0.06),
                        Color(red: 0.28, green: 0.16, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                WoodGrainOverlay(cornerRadius: 0)
                    .blendMode(.overlay)
                    .opacity(0.62)
            }
        )
        .containerBackground(
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.14, blue: 0.08),
                    Color(red: 0.18, green: 0.10, blue: 0.06),
                    Color(red: 0.28, green: 0.16, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .window
        )
        .ignoresSafeArea(.container, edges: .top)
        .contentShape(Rectangle())
        .onChange(of: playback.isPlaying, initial: true) { _, isPlaying in
            lastPlatterTick = isPlaying ? Date() : nil
        }
    }

    private var platterDegreesPerSecond: Double {
        platterRPM * 6
    }

    private func stepPlatter(to date: Date) {
        guard playback.isPlaying else { return }
        let previous = lastPlatterTick ?? date
        let rawDelta = date.timeIntervalSince(previous)
        let delta = min(max(rawDelta, 0), 1.0 / 20.0)
        platterDegrees = (platterDegrees + (delta * platterDegreesPerSecond))
            .truncatingRemainder(dividingBy: 360)
        lastPlatterTick = date
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hostingController = NSHostingController(rootView: ContentView())
        let window = NSWindow(contentViewController: hostingController)

        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 1040, height: 680))
        window.minSize = NSSize(width: 1040, height: 680)
        window.maxSize = NSSize(width: 1040, height: 680)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false

        repositionTrafficLights(in: window)

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.isEnabled = false
            zoomButton.alphaValue = 0.45
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func repositionTrafficLights(in window: NSWindow) {
        guard
            let closeButton = window.standardWindowButton(.closeButton),
            let miniButton = window.standardWindowButton(.miniaturizeButton),
            let zoomButton = window.standardWindowButton(.zoomButton),
            let container = closeButton.superview
        else {
            return
        }

        let buttons = [closeButton, miniButton, zoomButton]
        let buttonSize = closeButton.frame.size
        let spacing: CGFloat = 7
        let totalWidth = (buttonSize.width * CGFloat(buttons.count)) + (spacing * CGFloat(buttons.count - 1))
        let topPadding: CGFloat = 14
        let trailingPadding: CGFloat = 24

        let y = container.bounds.height - buttonSize.height - topPadding
        var x = container.bounds.width - totalWidth - trailingPadding

        for button in buttons {
            button.setFrameOrigin(NSPoint(x: x, y: y))
            x += buttonSize.width + spacing
        }
    }
}

@main
struct ScampApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
