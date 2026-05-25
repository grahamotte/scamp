import SwiftUI

struct RecordAreaPlaceholderView: View, Equatable {
    let size: CGFloat
    let playback: PlaybackController
    let theme: RecordTheme
    private let turntableSpeed: Double
    private let hasPlaylist: Bool
    private let albumArtImage: NSImage?
    private let albumArtIdentifier: ObjectIdentifier?
    private let currentTrackDisplayName: String?
    private let trackDurations: [TimeInterval]

    private let layout = VinylRecordLayout()
    private let unloadedBackdropColor = Color(white: 0.02)
    private let unloadedBackdropTrackColor = Color(white: 0.12)
    private var palette: RecordThemePalette { theme.palette }

    init(size: CGFloat, playback: PlaybackController, theme: RecordTheme) {
        self.size = size
        self.playback = playback
        self.theme = theme
        turntableSpeed = playback.turntableSpeed
        hasPlaylist = playback.hasPlaylist
        albumArtImage = playback.albumArtImage
        albumArtIdentifier = playback.albumArtImage.map(ObjectIdentifier.init)
        currentTrackDisplayName = playback.currentTrackDisplayName
        trackDurations = playback.trackDurations
    }

    static func == (lhs: RecordAreaPlaceholderView, rhs: RecordAreaPlaceholderView) -> Bool {
        lhs.size == rhs.size &&
            lhs.playback === rhs.playback &&
            lhs.theme == rhs.theme &&
            lhs.turntableSpeed == rhs.turntableSpeed &&
            lhs.hasPlaylist == rhs.hasPlaylist &&
            lhs.albumArtIdentifier == rhs.albumArtIdentifier &&
            lhs.trackDurations == rhs.trackDurations &&
            (lhs.albumArtIdentifier != nil || lhs.currentTrackDisplayName == rhs.currentTrackDisplayName)
    }

    var body: some View {
        let geometry = layout.resolved(forDiameter: size)
        let centerPegDiameter = hasPlaylist ? max(5, size * 0.02) : max(5, size * 0.018)
        let divisionRadii = hasPlaylist ? trackDivisionRadii(in: geometry) : []
        let surface = recordSurface(for: geometry, trackDivisionRadii: divisionRadii)

        Group {
            if hasPlaylist {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: turntableSpeed <= 0.0001)) { context in
                    let rotationDegrees = playback.recordRotationDegrees(at: context.date)

                    ZStack {
                        surface
                            .id(surfaceCacheKey)
                            .frame(width: size, height: size)
                            .drawingGroup(opaque: false, colorMode: .linear)
                            .rotationEffect(.degrees(rotationDegrees))
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                    }
                }
            } else {
                surface
                    .id(surfaceCacheKey)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            recordLightingOverlay(for: geometry)
        }
        .overlay {
            centerPeg(diameter: centerPegDiameter)
        }
    }

    @ViewBuilder
    private func recordSurface(for geometry: VinylRecordGeometry, trackDivisionRadii: [CGFloat]) -> some View {
        if hasPlaylist {
            loadedRecordSurface(for: geometry, trackDivisionRadii: trackDivisionRadii)
        } else {
            emptyRecordSurface()
        }
    }

    @ViewBuilder
    private func loadedRecordSurface(for geometry: VinylRecordGeometry, trackDivisionRadii: [CGFloat]) -> some View {
        if theme == .black {
            BlackRecordTheme.loadedSurface(
                size: size,
                geometry: geometry,
                trackDivisionRadii: trackDivisionRadii,
                albumArtImage: albumArtImage,
                currentTrackDisplayName: currentTrackDisplayName
            )
        } else {
            ZStack {
            Circle()
                .fill(palette.backgroundColor)
                .overlay {
                    RadialGradient(
                        colors: [Color.clear, Color.black.opacity(0.04)],
                        center: .center,
                        startRadius: size * 0.01,
                        endRadius: size * 0.54
                    )
                }
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.01), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(Circle())

            Circle()
                .stroke(palette.trackDividerColor.opacity(0.32), lineWidth: max(1, size * 0.0024))
                .padding(size * 0.003)

            Circle()
                .stroke(
                    palette.bufferColor,
                    style: StrokeStyle(lineWidth: max(1, geometry.outerBufferWidth))
                )
                .frame(
                    width: (geometry.trackBandOuterRadius + (geometry.outerBufferWidth / 2)) * 2,
                    height: (geometry.trackBandOuterRadius + (geometry.outerBufferWidth / 2)) * 2
                )

            Circle()
                .stroke(
                    palette.backgroundColor.opacity(0.96),
                    style: StrokeStyle(lineWidth: geometry.trackBandWidth, lineCap: .round)
                )
                .frame(width: geometry.trackBandMidRadius * 2, height: geometry.trackBandMidRadius * 2)

            ForEach(0..<72, id: \.self) { grooveIndex in
                let fraction = CGFloat(grooveIndex) / 71
                let trackBandWidth = geometry.trackBandRadiusBounds.upperBound - geometry.trackBandRadiusBounds.lowerBound
                let grooveRadius = geometry.trackBandRadiusBounds.upperBound - (trackBandWidth * fraction)
                Circle()
                    .stroke(
                        palette.trackDividerColor.opacity(grooveIndex.isMultiple(of: 6) ? 0.5 : 0.22),
                        lineWidth: 0.55
                    )
                    .frame(width: grooveRadius * 2, height: grooveRadius * 2)
            }

            ForEach(Array(trackDivisionRadii.enumerated()), id: \.offset) { _, radius in
                Circle()
                    .stroke(palette.trackDividerColor.opacity(0.6), lineWidth: max(0.6, size * 0.0018))
                    .frame(width: radius * 2, height: radius * 2)
            }

            if let surfaceOverlay = palette.surfaceOverlay {
                surfaceOverlay.makeView(size)
            }

            Circle()
                .stroke(
                    palette.bufferColor,
                    style: StrokeStyle(lineWidth: max(1, geometry.innerBufferWidth))
                )
                .frame(
                    width: (geometry.labelRadius + (geometry.innerBufferWidth / 2)) * 2,
                    height: (geometry.labelRadius + (geometry.innerBufferWidth / 2)) * 2
                )

            Circle()
                .fill(palette.backgroundColor)
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.01), Color.black.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(Circle())
                .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                .overlay {
                    if albumArtImage == nil {
                        Circle()
                            .stroke(palette.trackDividerColor.opacity(0.72), lineWidth: max(1, size * 0.0025))
                    }
                }
                .overlay {
                    if let albumArtImage {
                        Image(nsImage: albumArtImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                            .clipShape(Circle())
                    } else {
                        Text(currentTrackDisplayName ?? "SCAMP")
                            .font(.system(size: max(11, size * 0.028), weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(size * 0.04)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emptyRecordSurface() -> some View {
        if theme == .black {
            BlackRecordTheme.emptySurface(size: size)
        } else {
            ZStack {
            Circle()
                .fill(unloadedBackdropColor)
                .overlay {
                    RadialGradient(
                        colors: [Color.white.opacity(0.06), Color.black.opacity(0.22)],
                        center: .center,
                        startRadius: size * 0.01,
                        endRadius: size * 0.44
                    )
                }
                .clipShape(Circle())
                .frame(width: size * 0.92, height: size * 0.92)
                .overlay(
                    Circle()
                        .stroke(unloadedBackdropTrackColor.opacity(0.34), lineWidth: max(1, size * 0.0023))
                )
            }
        }
    }

    @ViewBuilder
    private func recordLightingOverlay(for geometry: VinylRecordGeometry) -> some View {
        if theme == .black {
            if hasPlaylist {
                BlackRecordTheme.loadedLightingOverlay(size: size, geometry: geometry)
            }
        }
    }

    @ViewBuilder
    private func centerPeg(diameter: CGFloat) -> some View {
        if theme == .black {
            BlackRecordTheme.centerPeg(diameter: diameter, bufferColor: palette.bufferColor)
        } else {
        let bufferRingWidth = max(0.32, diameter * 0.045)
        let bufferRingDiameter = diameter + bufferRingWidth

            ZStack {
            Circle()
                .stroke(palette.bufferColor.opacity(0.94), lineWidth: bufferRingWidth)
                .frame(width: bufferRingDiameter, height: bufferRingDiameter)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: max(0.2, bufferRingWidth * 0.45))
                        .frame(width: bufferRingDiameter, height: bufferRingDiameter)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.93), Color(white: 0.66), Color(white: 0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: max(0.6, diameter * 0.08))
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.24), lineWidth: max(0.5, diameter * 0.06))
                )
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.46))
                        .frame(width: diameter * 0.34, height: diameter * 0.34)
                        .offset(x: -diameter * 0.16, y: -diameter * 0.16)
                )
                .shadow(color: .black.opacity(0.22), radius: max(0.8, diameter * 0.14), x: 0, y: max(0.5, diameter * 0.08))
            }
        }
    }

    private func trackDivisionRadii(in geometry: VinylRecordGeometry) -> [CGFloat] {
        let durations = trackDurations.filter { $0.isFinite && $0 > 0 }
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

    private var surfaceCacheKey: RecordSurfaceCacheKey {
        RecordSurfaceCacheKey(
            size: size,
            theme: theme,
            hasPlaylist: hasPlaylist,
            albumArtIdentifier: albumArtIdentifier,
            currentTrackDisplayName: currentTrackDisplayName,
            trackDurations: trackDurations
        )
    }

}

private struct RecordSurfaceCacheKey: Hashable {
    let size: CGFloat
    let theme: RecordTheme
    let hasPlaylist: Bool
    let albumArtIdentifier: ObjectIdentifier?
    let currentTrackDisplayName: String?
    let trackDurations: [TimeInterval]
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
