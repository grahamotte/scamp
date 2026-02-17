import SwiftUI

struct DeckWorkspaceView: View {
    @ObservedObject var playback: PlaybackController
    @State private var scrubDragProgress: Double?
    @State private var showsTonearmDebugGuides = false

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

                        TonearmWorkspaceOverlay(
                            deckWidth: geometry.size.width,
                            deckHeight: squareSize,
                            recordOriginX: chromeInset,
                            recordDiameter: squareSize,
                            controlsWidth: controlsWidth,
                            progress: scrubProgress,
                            showsDebugGuides: showsTonearmDebugGuides,
                            onCounterweightTapped: {
                                showsTonearmDebugGuides.toggle()
                            },
                            onScrubChanged: { progress in
                                scrubDragProgress = progress
                            },
                            onScrubEnded: { progress in
                                scrubDragProgress = nil
                                playback.seek(toPlaylistProgress: progress)
                            }
                        )
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
    let showsDebugGuides: Bool
    let onCounterweightTapped: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void

    private static let scrubGuideAngleDegrees: Double = -45
    private let layout = VinylRecordLayout()

    var body: some View {
        let recordGeometry = layout.resolved(forDiameter: recordDiameter)
        let scrubGuide = scrubGuideGeometry(for: recordGeometry)
        let holderDiameter = recordDiameter * 0.25
        let controlsTrailingInset = recordOriginX
        let pivotPoint = CGPoint(
            x: deckWidth - controlsTrailingInset - (holderDiameter / 2),
            y: holderDiameter / 2
        )
        let redGuideDirection = normalizedVector(from: scrubGuide.start, to: scrubGuide.end)
        let midpointGuidePerpendicular = CGPoint(x: -redGuideDirection.y, y: redGuideDirection.x)
        let redGuideMidpoint = midpoint(between: scrubGuide.start, and: scrubGuide.end)
        let controlDirection = orientedToward(
            unit: midpointGuidePerpendicular,
            targetVector: CGPoint(
                x: redGuideMidpoint.x - pivotPoint.x,
                y: redGuideMidpoint.y - pivotPoint.y
            )
        )
        let redGuideLength = distance(from: scrubGuide.start, to: scrubGuide.end)
        let orangeCurveOffset = max(redGuideLength * 0.27, recordDiameter * 0.045)
        let orangeCurveControl = CGPoint(
            x: redGuideMidpoint.x + (controlDirection.x * orangeCurveOffset),
            y: redGuideMidpoint.y + (controlDirection.y * orangeCurveOffset)
        )
        let clampedProgress = min(max(progress, 0), 1)
        let needlePoint = pointOnQuadraticBezier(
            start: scrubGuide.start,
            control: orangeCurveControl,
            end: scrubGuide.end,
            progress: clampedProgress
        )
        let armDirection = normalizedVector(from: pivotPoint, to: needlePoint)
        let headAxisDirection = CGPoint(x: -redGuideDirection.y, y: redGuideDirection.x)
        let headAngle = Angle(radians: atan2(headAxisDirection.y, headAxisDirection.x))
        let armRearLength = max(26, recordDiameter * 0.09)
        let armRearPoint = CGPoint(
            x: pivotPoint.x - (armDirection.x * armRearLength),
            y: pivotPoint.y - (armDirection.y * armRearLength)
        )
        let counterweightWidth = max(30, recordDiameter * 0.1)
        let counterweightHeight = max(16, recordDiameter * 0.05)
        let counterweightPosition = CGPoint(
            x: pivotPoint.x - (armDirection.x * (armRearLength * 0.68)),
            y: pivotPoint.y - (armDirection.y * (armRearLength * 0.68))
        )
        let armShaftThickness = max(8, recordDiameter * 0.015)
        let headWidth = max(24, recordDiameter * 0.08)
        let headHeight = max(14, recordDiameter * 0.042)
        let debugDotDiameter = max(3, recordDiameter * 0.012)
        let debugHandleDiameter = max(3, recordDiameter * 0.009)
        let tonearmScrubGesture = tonearmDragGesture(
            start: scrubGuide.start,
            control: orangeCurveControl,
            end: scrubGuide.end
        )

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

                Path { path in
                    path.move(to: armRearPoint)
                    path.addLine(to: needlePoint)
                }
                .stroke(style: StrokeStyle(lineWidth: armShaftThickness, lineCap: .round, lineJoin: .round))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(white: 0.88), Color(white: 0.64), Color(white: 0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.24), radius: 3, x: 0, y: 2)
                .overlay {
                    Path { path in
                        path.move(to: armRearPoint)
                        path.addLine(to: needlePoint)
                    }
                    .stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.74), Color(white: 0.54)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: counterweightWidth,
                        height: counterweightHeight
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                    )
                    .rotationEffect(Angle(radians: atan2(armDirection.y, armDirection.x)))
                    .position(counterweightPosition)

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
                    .rotationEffect(headAngle)
                    .position(needlePoint)
            }
            .allowsHitTesting(false)

            Capsule()
                .fill(Color.clear)
                .frame(width: max(36, counterweightWidth * 1.2), height: max(24, counterweightHeight * 1.4))
                .contentShape(Capsule())
                .rotationEffect(Angle(radians: atan2(armDirection.y, armDirection.x)))
                .position(counterweightPosition)
                .onTapGesture {
                    onCounterweightTapped()
                }

            Circle()
                .fill(Color.clear)
                .frame(
                    width: max(28, headWidth * 1.3),
                    height: max(28, headWidth * 1.3)
                )
                .contentShape(Circle())
                .position(needlePoint)
                .gesture(tonearmScrubGesture)

            if showsDebugGuides {
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

                Path { path in
                    path.move(to: scrubGuide.start)
                    path.addQuadCurve(to: scrubGuide.end, control: orangeCurveControl)
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: max(1, recordDiameter * 0.003), lineCap: .round))
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
                    .position(needlePoint)
                    .gesture(tonearmScrubGesture)
            }
        }
        .frame(width: deckWidth, height: deckHeight, alignment: .topLeading)
        .clipped()
    }

    private func scrubGuideGeometry(
        for recordGeometry: VinylRecordGeometry
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
            end: end
        )
    }

    private func pointOnQuadraticBezier(
        start: CGPoint,
        control: CGPoint,
        end: CGPoint,
        progress: Double
    ) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let oneMinusT = 1 - CGFloat(t)
        let tCGFloat = CGFloat(t)
        return CGPoint(
            x: (oneMinusT * oneMinusT * start.x) + (2 * oneMinusT * tCGFloat * control.x) + (tCGFloat * tCGFloat * end.x),
            y: (oneMinusT * oneMinusT * start.y) + (2 * oneMinusT * tCGFloat * control.y) + (tCGFloat * tCGFloat * end.y)
        )
    }

    private func tonearmDragGesture(
        start: CGPoint,
        control: CGPoint,
        end: CGPoint
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onScrubChanged(projectedTonearmProgress(
                    for: value.location,
                    start: start,
                    control: control,
                    end: end
                ))
            }
            .onEnded { value in
                onScrubEnded(projectedTonearmProgress(
                    for: value.location,
                    start: start,
                    control: control,
                    end: end
                ))
            }
    }

    private func projectedTonearmProgress(
        for location: CGPoint,
        start: CGPoint,
        control: CGPoint,
        end: CGPoint
    ) -> Double {
        let samples = 180
        var bestDistanceSquared = CGFloat.infinity
        var bestProgress: Double = 0
        var previous = pointOnQuadraticBezier(start: start, control: control, end: end, progress: 0)

        for sampleIndex in 1...samples {
            let sampleProgress = Double(sampleIndex) / Double(samples)
            let current = pointOnQuadraticBezier(
                start: start,
                control: control,
                end: end,
                progress: sampleProgress
            )
            let segment = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
            let segmentLengthSquared = (segment.x * segment.x) + (segment.y * segment.y)

            let projection: CGFloat
            if segmentLengthSquared > 0.0001 {
                let toLocation = CGPoint(x: location.x - previous.x, y: location.y - previous.y)
                projection = min(
                    max(((toLocation.x * segment.x) + (toLocation.y * segment.y)) / segmentLengthSquared, 0),
                    1
                )
            } else {
                projection = 0
            }

            let projectedPoint = CGPoint(
                x: previous.x + (segment.x * projection),
                y: previous.y + (segment.y * projection)
            )
            let dx = location.x - projectedPoint.x
            let dy = location.y - projectedPoint.y
            let distanceSquared = (dx * dx) + (dy * dy)

            if distanceSquared < bestDistanceSquared {
                bestDistanceSquared = distanceSquared
                bestProgress = (Double(sampleIndex - 1) + Double(projection)) / Double(samples)
            }

            previous = current
        }

        return min(max(bestProgress, 0), 1)
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

    private func orientedToward(unit: CGPoint, targetVector: CGPoint) -> CGPoint {
        let dot = (unit.x * targetVector.x) + (unit.y * targetVector.y)
        if dot >= 0 {
            return unit
        }
        return CGPoint(x: -unit.x, y: -unit.y)
    }

}

private struct ScrubGuideGeometry {
    let recordCenter: CGPoint
    let start: CGPoint
    let end: CGPoint
}
