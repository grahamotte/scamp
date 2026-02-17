import SwiftUI

struct RecordAreaPlaceholderView: View {
    let size: CGFloat
    @ObservedObject var playback: PlaybackController

    private static let platterRPM: Double = 33
    private static let scrubGuideAngleDegrees: Double = -65
    private let layout = VinylRecordLayout()
    private let bufferBandColor = Color(white: 0.11)

    @State private var rotationAnchorDate: Date?
    @State private var persistedRotationDegrees: Double = 0

    var body: some View {
        let geometry = layout.resolved(forDiameter: size)

        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !playback.isPlaying)) { context in
                let rotationDegrees = rotationDegrees(at: context.date)

                recordSurface(for: geometry)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotationDegrees))
            }

            if playback.hasPlaylist {
                playlistScrubGuide(for: geometry)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if playback.isPlaying, rotationAnchorDate == nil {
                rotationAnchorDate = Date()
            }
        }
        .onChange(of: playback.isPlaying) { _, isPlaying in
            syncRotationState(isPlaying: isPlaying, now: Date())
        }
    }

    @ViewBuilder
    private func recordSurface(for geometry: VinylRecordGeometry) -> some View {
        if playback.hasPlaylist {
            loadedRecordSurface(for: geometry)
        } else {
            emptyRecordSurface
        }
    }

    private func loadedRecordSurface(for geometry: VinylRecordGeometry) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.18), Color(white: 0.07)],
                        center: .center,
                        startRadius: size * 0.02,
                        endRadius: size * 0.54
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: max(1, size * 0.0024))
                .padding(size * 0.003)

            Circle()
                .stroke(
                    bufferBandColor,
                    style: StrokeStyle(lineWidth: max(1, geometry.outerBufferWidth))
                )
                .frame(
                    width: (geometry.trackBandOuterRadius + (geometry.outerBufferWidth / 2)) * 2,
                    height: (geometry.trackBandOuterRadius + (geometry.outerBufferWidth / 2)) * 2
                )

            Circle()
                .stroke(
                    Color.black.opacity(0.76),
                    style: StrokeStyle(lineWidth: geometry.trackBandWidth, lineCap: .round)
                )
                .frame(width: geometry.trackBandMidRadius * 2, height: geometry.trackBandMidRadius * 2)

            ForEach(0..<72, id: \.self) { grooveIndex in
                let fraction = CGFloat(grooveIndex) / 71
                let trackBandWidth = geometry.trackBandRadiusBounds.upperBound - geometry.trackBandRadiusBounds.lowerBound
                let grooveRadius = geometry.trackBandRadiusBounds.upperBound - (trackBandWidth * fraction)
                Circle()
                    .stroke(Color.white.opacity(grooveIndex.isMultiple(of: 6) ? 0.024 : 0.012), lineWidth: 0.55)
                    .frame(width: grooveRadius * 2, height: grooveRadius * 2)
            }

            ForEach(Array(trackDivisionRadii(in: geometry).enumerated()), id: \.offset) { _, radius in
                Circle()
                    .stroke(Color.white.opacity(0.085), lineWidth: max(0.6, size * 0.0018))
                    .frame(width: radius * 2, height: radius * 2)
            }

            Circle()
                .stroke(
                    bufferBandColor,
                    style: StrokeStyle(lineWidth: max(1, geometry.innerBufferWidth))
                )
                .frame(
                    width: (geometry.labelRadius + (geometry.innerBufferWidth / 2)) * 2,
                    height: (geometry.labelRadius + (geometry.innerBufferWidth / 2)) * 2
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.66, green: 0.24, blue: 0.2), Color(red: 0.35, green: 0.08, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                .overlay {
                    if playback.albumArtImage == nil {
                        Circle()
                            .stroke(Color.white.opacity(0.42), lineWidth: max(1, size * 0.0025))
                    }
                }
                .overlay {
                    if let albumArtImage = playback.albumArtImage {
                        Image(nsImage: albumArtImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                            .clipShape(Circle())
                    } else {
                        Text(playback.currentTrackDisplayName ?? "SCAMP")
                            .font(.system(size: max(11, size * 0.028), weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(size * 0.04)
                    }
                }

            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: max(5, size * 0.02), height: max(5, size * 0.02))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private var emptyRecordSurface: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.17), Color(white: 0.08)],
                        center: .center,
                        startRadius: size * 0.01,
                        endRadius: size * 0.44
                    )
                )
                .frame(width: size * 0.92, height: size * 0.92)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: max(1, size * 0.0023))
                )

            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: max(5, size * 0.018), height: max(5, size * 0.018))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private func trackDivisionRadii(in geometry: VinylRecordGeometry) -> [CGFloat] {
        let durations = playback.trackDurations.filter { $0.isFinite && $0 > 0 }
        guard durations.count > 1 else { return [] }

        let totalDuration = durations.reduce(0, +)
        guard totalDuration > 0 else { return [] }

        var elapsed: TimeInterval = 0
        let trackBandWidth = geometry.trackBandRadiusBounds.upperBound - geometry.trackBandRadiusBounds.lowerBound
        return durations.dropLast().map { duration in
            elapsed += duration
            let fraction = min(max(elapsed / totalDuration, 0), 1)
            return geometry.trackBandRadiusBounds.upperBound - (trackBandWidth * CGFloat(fraction))
        }
    }

    private func playlistScrubGuide(for geometry: VinylRecordGeometry) -> some View {
        let direction = scrubGuideDirection()
        let center = CGPoint(x: size / 2, y: size / 2)
        let start = CGPoint(
            x: center.x + (direction.x * geometry.trackBandInnerRadius),
            y: center.y + (direction.y * geometry.trackBandInnerRadius)
        )
        let end = CGPoint(
            x: center.x + (direction.x * geometry.trackBandOuterRadius),
            y: center.y + (direction.y * geometry.trackBandOuterRadius)
        )
        let lineWidth = max(1, size * 0.003)
        let dotDiameter = max(3, size * 0.012)

        return ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(Color.red, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .fill(Color.red)
                .frame(width: dotDiameter, height: dotDiameter)
                .position(start)

            Circle()
                .fill(Color.red)
                .frame(width: dotDiameter, height: dotDiameter)
                .position(end)
        }
    }

    private func scrubGuideDirection() -> CGPoint {
        let radians = Self.scrubGuideAngleDegrees * .pi / 180
        // SwiftUI's Y axis grows downward, so invert sine to preserve unit-circle angle semantics.
        return CGPoint(x: cos(radians), y: -sin(radians))
    }

    private func syncRotationState(isPlaying: Bool, now: Date) {
        if isPlaying {
            if rotationAnchorDate == nil {
                rotationAnchorDate = now
            }
            return
        }

        if rotationAnchorDate != nil {
            persistedRotationDegrees = rotationDegrees(at: now)
            rotationAnchorDate = nil
        }
    }

    private func rotationDegrees(at now: Date) -> Double {
        let wrappedPersistedDegrees = persistedRotationDegrees.truncatingRemainder(dividingBy: 360)
        guard playback.isPlaying, let rotationAnchorDate else {
            return wrappedPersistedDegrees
        }

        let elapsed = max(0, now.timeIntervalSince(rotationAnchorDate))
        let degreesPerSecond = (Self.platterRPM / 60) * 360
        return (wrappedPersistedDegrees + (elapsed * degreesPerSecond)).truncatingRemainder(dividingBy: 360)
    }
}

struct VinylRecordLayout {
    var outerBufferFraction: CGFloat = 0.03
    var trackBandFraction: CGFloat = 0.60
    var innerBufferFraction: CGFloat = 0.03
    var labelFraction: CGFloat = 0.34

    // Normalized radius bounds used by track area and future tonearm travel constraints.
    var normalizedTrackBandBounds: ClosedRange<CGFloat> {
        let total = max(outerBufferFraction + trackBandFraction + innerBufferFraction + labelFraction, 0.0001)
        let lower = (labelFraction + innerBufferFraction) / total
        let upper = (labelFraction + innerBufferFraction + trackBandFraction) / total
        return lower...upper
    }

    func resolved(forDiameter diameter: CGFloat) -> VinylRecordGeometry {
        let halfDiameter = max(0, diameter / 2)
        let total = max(outerBufferFraction + trackBandFraction + innerBufferFraction + labelFraction, 0.0001)
        let unit = halfDiameter / total

        let labelRadius = labelFraction * unit
        let innerBufferWidth = innerBufferFraction * unit
        let trackBandInnerRadius = labelRadius + innerBufferWidth
        let trackBandOuterRadius = trackBandInnerRadius + (trackBandFraction * unit)
        let outerBufferWidth = outerBufferFraction * unit

        return VinylRecordGeometry(
            outerRadius: trackBandOuterRadius + outerBufferWidth,
            labelRadius: labelRadius,
            trackBandInnerRadius: trackBandInnerRadius,
            trackBandOuterRadius: trackBandOuterRadius,
            trackBandRadiusBounds: (normalizedTrackBandBounds.lowerBound * halfDiameter)...(normalizedTrackBandBounds.upperBound * halfDiameter),
            outerBufferWidth: outerBufferWidth,
            innerBufferWidth: innerBufferWidth
        )
    }
}

struct VinylRecordGeometry {
    let outerRadius: CGFloat
    let labelRadius: CGFloat
    let trackBandInnerRadius: CGFloat
    let trackBandOuterRadius: CGFloat
    let trackBandRadiusBounds: ClosedRange<CGFloat>
    let outerBufferWidth: CGFloat
    let innerBufferWidth: CGFloat

    var trackBandWidth: CGFloat {
        trackBandOuterRadius - trackBandInnerRadius
    }

    var trackBandMidRadius: CGFloat {
        (trackBandInnerRadius + trackBandOuterRadius) / 2
    }
}
