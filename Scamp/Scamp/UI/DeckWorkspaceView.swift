import SwiftUI

struct DeckWorkspaceView: View {
    @ObservedObject var playback: PlaybackController
    @State private var scrubDragProgress: Double?

    private var bottomBarTitle: String {
        if playback.isPlaying, let currentTrackDisplayName = playback.currentTrackDisplayName {
            return currentTrackDisplayName
        }
        return ScampLayout.statusFallbackTitle
    }

    var body: some View {
        ZStack {
            WoodGrainBackground()
                .ignoresSafeArea()

            GeometryReader { geometry in
                let chromeInset = geometry.safeAreaInsets.top
                let squareSize = max(0, geometry.size.height - chromeInset)
                let controlsWidth = max(0, geometry.size.width - chromeInset - squareSize)
                let scrubProgress = scrubDragProgress ?? playback.playlistProgress

                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: chromeInset)

                            RecordAreaPlaceholderView(size: squareSize, playback: playback)

                            ControlsAreaView(
                                width: controlsWidth,
                                height: squareSize,
                                playback: playback
                            )
                        }

                        if playback.hasPlaylist {
                            TonearmWorkspaceOverlay(
                                deckWidth: geometry.size.width,
                                deckHeight: squareSize,
                                recordOriginX: chromeInset,
                                recordDiameter: squareSize,
                                controlsWidth: controlsWidth,
                                progress: scrubProgress,
                                onScrubChanged: { progress in
                                    scrubDragProgress = progress
                                },
                                onScrubEnded: { progress in
                                    scrubDragProgress = nil
                                    playback.seek(toPlaylistProgress: progress)
                                }
                            )
                        }
                    }
                    .frame(width: geometry.size.width, height: squareSize, alignment: .topLeading)

                    BottomStatusBarView(
                        title: bottomBarTitle,
                        height: chromeInset
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TonearmWorkspaceOverlay: View {
    let deckWidth: CGFloat
    let deckHeight: CGFloat
    let recordOriginX: CGFloat
    let recordDiameter: CGFloat
    let controlsWidth: CGFloat
    let progress: Double
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void

    private static let scrubGuideAngleDegrees: Double = -65
    private let layout = VinylRecordLayout()

    var body: some View {
        let recordGeometry = layout.resolved(forDiameter: recordDiameter)
        let scrubGuide = scrubGuideGeometry(for: recordGeometry, progress: progress)
        let holderDiameter = recordDiameter * 0.25
        let pivotPoint = CGPoint(
            x: recordOriginX + recordDiameter + (controlsWidth / 2),
            y: holderDiameter / 2
        )
        let armDirection = normalizedVector(from: pivotPoint, to: scrubGuide.handle)
        let armAngle = Angle(radians: atan2(armDirection.y, armDirection.x))
        let armRearLength = max(26, recordDiameter * 0.09)
        let armRearPoint = CGPoint(
            x: pivotPoint.x - (armDirection.x * armRearLength),
            y: pivotPoint.y - (armDirection.y * armRearLength)
        )
        let armShaftLength = distance(from: armRearPoint, to: scrubGuide.handle)
        let armShaftCenter = midpoint(between: armRearPoint, and: scrubGuide.handle)
        let armShaftThickness = max(8, recordDiameter * 0.015)
        let headWidth = max(24, recordDiameter * 0.08)
        let headHeight = max(14, recordDiameter * 0.042)
        let debugDotDiameter = max(3, recordDiameter * 0.012)
        let debugHandleDiameter = max(3, recordDiameter * 0.009)
        let stylusNormal = stylusDownwardNormal(
            armDirection: armDirection,
            headCenter: scrubGuide.handle,
            recordCenter: scrubGuide.recordCenter
        )
        let stylusPoint = CGPoint(
            x: scrubGuide.handle.x + (stylusNormal.x * (headHeight * 0.52)),
            y: scrubGuide.handle.y + (stylusNormal.y * (headHeight * 0.52))
        )
        let scrubGesture = dragGesture(start: scrubGuide.start, end: scrubGuide.end)

        return ZStack {
            Group {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.82), Color(white: 0.52)],
                            center: .topLeading,
                            startRadius: holderDiameter * 0.08,
                            endRadius: holderDiameter * 0.62
                        )
                    )
                    .frame(width: holderDiameter, height: holderDiameter)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: max(1.2, recordDiameter * 0.002))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.24), lineWidth: max(1.2, recordDiameter * 0.002))
                            .padding(holderDiameter * 0.08)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .position(pivotPoint)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.86), Color(white: 0.62), Color(white: 0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: armShaftLength, height: armShaftThickness)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                    .rotationEffect(armAngle)
                    .position(armShaftCenter)
                    .shadow(color: .black.opacity(0.24), radius: 3, x: 0, y: 2)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.74), Color(white: 0.54)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: max(30, recordDiameter * 0.1),
                        height: max(16, recordDiameter * 0.05)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                    )
                    .rotationEffect(armAngle)
                    .position(
                        x: pivotPoint.x - (armDirection.x * (armRearLength * 0.68)),
                        y: pivotPoint.y - (armDirection.y * (armRearLength * 0.68))
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.9), Color(white: 0.58)],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: max(8, recordDiameter * 0.022)
                        )
                    )
                    .frame(
                        width: max(14, recordDiameter * 0.05),
                        height: max(14, recordDiameter * 0.05)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.22), lineWidth: 1)
                    )
                    .position(pivotPoint)

                RoundedRectangle(cornerRadius: max(2.5, headHeight * 0.2), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.87), Color(white: 0.66), Color(white: 0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: headWidth, height: headHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: max(2.5, headHeight * 0.2), style: .continuous)
                            .stroke(Color.black.opacity(0.22), lineWidth: 1)
                    )
                    .rotationEffect(armAngle)
                    .position(scrubGuide.handle)

                Circle()
                    .fill(Color.black.opacity(0.92))
                    .frame(width: max(3, recordDiameter * 0.008), height: max(3, recordDiameter * 0.008))
                    .position(stylusPoint)
            }
            .allowsHitTesting(false)

            Circle()
                .fill(Color.clear)
                .frame(
                    width: max(28, headWidth * 1.3),
                    height: max(28, headWidth * 1.3)
                )
                .contentShape(Circle())
                .position(scrubGuide.handle)
                .gesture(scrubGesture)

            Group {
                Path { path in
                    path.move(to: scrubGuide.start)
                    path.addLine(to: scrubGuide.end)
                }
                .stroke(Color.red, style: StrokeStyle(lineWidth: max(1, recordDiameter * 0.003), lineCap: .round))

                Circle()
                    .fill(Color.red)
                    .frame(width: debugDotDiameter, height: debugDotDiameter)
                    .position(scrubGuide.start)

                Circle()
                    .fill(Color.red)
                    .frame(width: debugDotDiameter, height: debugDotDiameter)
                    .position(scrubGuide.end)
            }
            .allowsHitTesting(false)

            Circle()
                .fill(Color.clear)
                .frame(width: max(18, debugHandleDiameter * 2), height: max(18, debugHandleDiameter * 2))
                .overlay {
                    Circle()
                        .fill(Color.green)
                        .frame(width: debugHandleDiameter, height: debugHandleDiameter)
                }
                .contentShape(Circle())
                .position(scrubGuide.handle)
                .gesture(scrubGesture)
        }
        .frame(width: deckWidth, height: deckHeight, alignment: .topLeading)
        .clipped()
    }

    private func scrubGuideGeometry(
        for recordGeometry: VinylRecordGeometry,
        progress: Double
    ) -> ScrubGuideGeometry {
        let direction = scrubGuideDirection()
        let center = CGPoint(x: recordOriginX + (recordDiameter / 2), y: recordDiameter / 2)
        let start = CGPoint(
            x: center.x + (direction.x * recordGeometry.trackBandOuterRadius),
            y: center.y + (direction.y * recordGeometry.trackBandOuterRadius)
        )
        let end = CGPoint(
            x: center.x + (direction.x * recordGeometry.trackBandInnerRadius),
            y: center.y + (direction.y * recordGeometry.trackBandInnerRadius)
        )
        return ScrubGuideGeometry(
            recordCenter: center,
            start: start,
            end: end,
            handle: pointOnScrubGuide(for: progress, start: start, end: end)
        )
    }

    private func pointOnScrubGuide(for progress: Double, start: CGPoint, end: CGPoint) -> CGPoint {
        let t = min(max(progress, 0), 1)
        return CGPoint(
            x: start.x + ((end.x - start.x) * t),
            y: start.y + ((end.y - start.y) * t)
        )
    }

    private func projectedScrubProgress(for location: CGPoint, start: CGPoint, end: CGPoint) -> Double {
        let segmentDX = end.x - start.x
        let segmentDY = end.y - start.y
        let segmentLengthSquared = (segmentDX * segmentDX) + (segmentDY * segmentDY)
        guard segmentLengthSquared > 0 else { return 0 }

        let localX = location.x - start.x
        let localY = location.y - start.y
        let projection = ((localX * segmentDX) + (localY * segmentDY)) / segmentLengthSquared
        return min(max(Double(projection), 0), 1)
    }

    private func dragGesture(start: CGPoint, end: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onScrubChanged(projectedScrubProgress(for: value.location, start: start, end: end))
            }
            .onEnded { value in
                onScrubEnded(projectedScrubProgress(for: value.location, start: start, end: end))
            }
    }

    private func scrubGuideDirection() -> CGPoint {
        let radians = Self.scrubGuideAngleDegrees * .pi / 180
        // SwiftUI's Y axis grows downward, so invert sine to preserve unit-circle angle semantics.
        return CGPoint(x: cos(radians), y: -sin(radians))
    }

    private func midpoint(between first: CGPoint, and second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let dx = second.x - first.x
        let dy = second.y - first.y
        return sqrt((dx * dx) + (dy * dy))
    }

    private func normalizedVector(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let magnitude = sqrt((dx * dx) + (dy * dy))
        guard magnitude > 0.0001 else { return CGPoint(x: -1, y: 0) }
        return CGPoint(x: dx / magnitude, y: dy / magnitude)
    }

    private func stylusDownwardNormal(
        armDirection: CGPoint,
        headCenter: CGPoint,
        recordCenter: CGPoint
    ) -> CGPoint {
        var normal = CGPoint(x: -armDirection.y, y: armDirection.x)
        let toRecordCenter = CGPoint(
            x: recordCenter.x - headCenter.x,
            y: recordCenter.y - headCenter.y
        )
        let dot = (normal.x * toRecordCenter.x) + (normal.y * toRecordCenter.y)
        if dot < 0 {
            normal = CGPoint(x: -normal.x, y: -normal.y)
        }
        return normal
    }
}

private struct ScrubGuideGeometry {
    let recordCenter: CGPoint
    let start: CGPoint
    let end: CGPoint
    let handle: CGPoint
}
