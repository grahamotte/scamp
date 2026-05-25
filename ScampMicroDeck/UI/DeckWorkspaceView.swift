import SwiftUI

struct DeckWorkspaceView: View {
    @ObservedObject var playback: PlaybackController
    @Binding var tableTheme: TableTheme
    @Binding var recordTheme: RecordTheme
    @Binding var controlsTheme: ControlsTheme
    @State private var scrubDragProgress: Double?
    @State private var showsTonearmDebugGuides = false
    @State private var debugLightSource: CGPoint?
    @State private var isRecordHoldGestureActive = false

    var body: some View {
        ZStack {
            TableThemeBackground(theme: tableTheme)
                .ignoresSafeArea()

            GeometryReader { geometry in
                let windowSize = geometry.size
                let chromeInset = geometry.safeAreaInsets.top
                let squareSize = max(0, geometry.size.height - chromeInset)
                let controlsWidth = max(0, geometry.size.width - chromeInset - squareSize)
                let scrubProgress = scrubDragProgress ?? playback.playlistProgress
                let lightSource = ThemeLighting.clampedSource(
                    debugLightSource ?? ThemeLighting.initialSource(in: windowSize),
                    in: windowSize
                )

                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            HStack(spacing: 0) {
                                Color.clear
                                    .frame(width: chromeInset)

                                RecordAreaPlaceholderView(
                                    size: squareSize,
                                    playback: playback,
                                    theme: recordTheme
                                )
                                .contentShape(Circle())
                                .onLongPressGesture(
                                    minimumDuration: 0,
                                    maximumDistance: .greatestFiniteMagnitude,
                                    pressing: { isPressing in
                                        guard isRecordHoldGestureActive != isPressing else { return }
                                        isRecordHoldGestureActive = isPressing
                                        playback.setRecordHoldActive(isPressing)
                                    },
                                    perform: {}
                                )

                                ControlsAreaView(
                                    width: controlsWidth,
                                    height: squareSize,
                                    edgeInset: chromeInset,
                                    controlsTheme: controlsTheme,
                                    playback: playback
                                )
                            }

                            TonearmWorkspaceOverlay(
                                deckWidth: geometry.size.width,
                                deckHeight: squareSize,
                                recordOriginX: chromeInset,
                                recordDiameter: squareSize,
                                controlsTheme: controlsTheme,
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

                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: chromeInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    if showsTonearmDebugGuides {
                        ThemeLightSourceHandle(
                            source: lightSourceBinding(in: windowSize),
                            windowSize: windowSize
                        )
                        .zIndex(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .coordinateSpace(name: ThemeLighting.coordinateSpaceName)
                .environment(\.themeLighting, ThemeLighting(source: lightSource))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            if isRecordHoldGestureActive {
                isRecordHoldGestureActive = false
                playback.setRecordHoldActive(false)
            }
        }
    }

    private func lightSourceBinding(in size: CGSize) -> Binding<CGPoint> {
        Binding(
            get: {
                ThemeLighting.clampedSource(
                    debugLightSource ?? ThemeLighting.initialSource(in: size),
                    in: size
                )
            },
            set: { newSource in
                debugLightSource = ThemeLighting.clampedSource(newSource, in: size)
            }
        )
    }
}

private struct TonearmWorkspaceOverlay: View {
    let deckWidth: CGFloat
    let deckHeight: CGFloat
    let recordOriginX: CGFloat
    let recordDiameter: CGFloat
    let controlsTheme: ControlsTheme
    let progress: Double
    let showsDebugGuides: Bool
    let onCounterweightTapped: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void

    private static let scrubGuideAngleDegrees: Double = -33
    private static let scrubCurveDepthFraction: CGFloat = 0.12
    private let layout = VinylRecordLayout()
    private var palette: ControlsThemePalette { controlsTheme.palette }

    var body: some View {
        let recordGeometry = layout.resolved(forDiameter: recordDiameter)
        let tonearm = resolveTonearmGeometry(for: recordGeometry)
        let armPath = straightTonearmPath(
            armRear: tonearm.armRearPoint,
            pivot: tonearm.pivotPoint,
            needle: tonearm.needlePoint
        )
        let tonearmThemeGeometry = TonearmThemeGeometry(
            recordDiameter: recordDiameter,
            holderDiameter: tonearm.holderDiameter,
            headWidth: tonearm.headWidth,
            headHeight: tonearm.headHeight,
            counterweightWidth: tonearm.counterweightWidth,
            counterweightHeight: tonearm.counterweightHeight,
            armShaftThickness: tonearm.armShaftThickness,
            armRotation: tonearm.armRotation
        )
        let tonearmScrubGesture = tonearmDragGesture(
            start: tonearm.scrubGuide.start,
            control: tonearm.orangeCurveControl,
            end: tonearm.scrubGuide.end
        )

        return ZStack {
            Group {
                palette.tonearmHolder
                    .makeView(tonearmThemeGeometry)
                    .position(tonearm.pivotPoint)

                palette.tonearmArm.makeView(armPath, tonearmThemeGeometry)

                palette.tonearmCounterweight
                    .makeView(tonearmThemeGeometry)
                    .rotationEffect(tonearm.armRotation)
                    .position(tonearm.counterweightPosition)

                palette.tonearmPeg
                    .makeView(tonearmThemeGeometry)
                    .position(tonearm.pivotPoint)

                palette.tonearmHead
                    .makeView(tonearmThemeGeometry)
                    .rotationEffect(tonearm.armRotation)
                    .position(tonearm.needlePoint)
            }
            .allowsHitTesting(false)

            Capsule()
                .fill(Color.clear)
                .frame(
                    width: max(36, tonearm.counterweightWidth * 1.2),
                    height: max(24, tonearm.counterweightHeight * 1.4)
                )
                .contentShape(Capsule())
                .rotationEffect(tonearm.armRotation)
                .position(tonearm.counterweightPosition)
                .onTapGesture {
                    onCounterweightTapped()
                }

            Circle()
                .fill(Color.clear)
                .frame(
                    width: max(28, tonearm.headWidth * 1.3),
                    height: max(28, tonearm.headWidth * 1.3)
                )
                .contentShape(Circle())
                .position(tonearm.needlePoint)
                .gesture(tonearmScrubGesture)

            if showsDebugGuides {
                Group {
                    Path { path in
                        path.move(to: tonearm.scrubGuide.start)
                        path.addLine(to: tonearm.scrubGuide.end)
                    }
                    .stroke(Color.red, style: StrokeStyle(lineWidth: max(1, recordDiameter * 0.003), lineCap: .round))

                    Circle()
                        .fill(Color.red)
                        .frame(width: tonearm.debugDotDiameter, height: tonearm.debugDotDiameter)
                        .position(tonearm.scrubGuide.start)

                    Circle()
                        .fill(Color.red)
                        .frame(width: tonearm.debugDotDiameter, height: tonearm.debugDotDiameter)
                        .position(tonearm.scrubGuide.end)
                }
                .allowsHitTesting(false)

                Path { path in
                    path.move(to: tonearm.scrubGuide.start)
                    path.addQuadCurve(to: tonearm.scrubGuide.end, control: tonearm.orangeCurveControl)
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: max(1, recordDiameter * 0.003), lineCap: .round))
                .allowsHitTesting(false)

                Path { path in
                    path.move(to: tonearm.pivotPoint)
                    path.addLine(to: tonearm.needlePoint)
                }
                .stroke(
                    Color.orange,
                    style: StrokeStyle(
                        lineWidth: max(1, recordDiameter * 0.003),
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [8, 8]
                    )
                )
                .allowsHitTesting(false)

                Circle()
                    .fill(Color.clear)
                    .frame(
                        width: max(18, tonearm.debugHandleDiameter * 2),
                        height: max(18, tonearm.debugHandleDiameter * 2)
                    )
                    .overlay {
                        Circle()
                            .fill(Color.green)
                            .frame(width: tonearm.debugHandleDiameter, height: tonearm.debugHandleDiameter)
                    }
                    .contentShape(Circle())
                    .position(tonearm.needlePoint)
                    .gesture(tonearmScrubGesture)
            }
        }
        .frame(width: deckWidth, height: deckHeight, alignment: .topLeading)
        .clipped()
    }

    private func resolveTonearmGeometry(
        for recordGeometry: VinylRecordGeometry
    ) -> TonearmGeometry {
        let scrubGuide = scrubGuideGeometry(for: recordGeometry)
        let holderDiameter = recordDiameter * 0.25
        let pivotPoint = CGPoint(
            x: deckWidth - recordOriginX - (holderDiameter / 2),
            y: holderDiameter / 2
        )
        let redGuideMidpoint = midpoint(between: scrubGuide.start, and: scrubGuide.end)
        let redGuideLength = distance(from: scrubGuide.start, to: scrubGuide.end)
        let midpointAwayFromPivotDirection = normalizedVector(from: pivotPoint, to: redGuideMidpoint)
        let orangeCurveOffset = max(redGuideLength * Self.scrubCurveDepthFraction, recordDiameter * 0.02)
        let orangeCurveControl = CGPoint(
            x: redGuideMidpoint.x + (midpointAwayFromPivotDirection.x * orangeCurveOffset),
            y: redGuideMidpoint.y + (midpointAwayFromPivotDirection.y * orangeCurveOffset)
        )
        let clampedProgress = min(max(progress, 0), 1)
        let needlePoint = pointOnQuadraticBezier(
            start: scrubGuide.start,
            control: orangeCurveControl,
            end: scrubGuide.end,
            progress: clampedProgress
        )
        let armDirection = normalizedVector(from: pivotPoint, to: needlePoint)
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

        return TonearmGeometry(
            scrubGuide: scrubGuide,
            pivotPoint: pivotPoint,
            orangeCurveControl: orangeCurveControl,
            needlePoint: needlePoint,
            armDirection: armDirection,
            armRearPoint: armRearPoint,
            counterweightWidth: counterweightWidth,
            counterweightHeight: counterweightHeight,
            counterweightPosition: counterweightPosition,
            holderDiameter: holderDiameter,
            headWidth: max(24, recordDiameter * 0.08),
            headHeight: max(14, recordDiameter * 0.042),
            armShaftThickness: max(11, recordDiameter * 0.02),
            debugDotDiameter: max(3, recordDiameter * 0.012),
            debugHandleDiameter: max(3, recordDiameter * 0.009)
        )
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

    private func straightTonearmPath(
        armRear: CGPoint,
        pivot: CGPoint,
        needle: CGPoint
    ) -> Path {
        Path { path in
            path.move(to: armRear)
            path.addLine(to: pivot)
            path.addLine(to: needle)
        }
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
}

private struct ScrubGuideGeometry {
    let start: CGPoint
    let end: CGPoint
}

private struct TonearmGeometry {
    let scrubGuide: ScrubGuideGeometry
    let pivotPoint: CGPoint
    let orangeCurveControl: CGPoint
    let needlePoint: CGPoint
    let armDirection: CGPoint
    let armRearPoint: CGPoint
    let counterweightWidth: CGFloat
    let counterweightHeight: CGFloat
    let counterweightPosition: CGPoint
    let holderDiameter: CGFloat
    let headWidth: CGFloat
    let headHeight: CGFloat
    let armShaftThickness: CGFloat
    let debugDotDiameter: CGFloat
    let debugHandleDiameter: CGFloat

    var armRotation: Angle {
        Angle(radians: atan2(armDirection.y, armDirection.x))
    }
}
