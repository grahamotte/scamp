import SwiftUI

struct PinkSplatterRecordTheme: RecordThemeDefinition {
    static let displayName = "Pink Splatter"
    private static let primaryColor = Color(red: 0.99, green: 0.18, blue: 0.50)
    private static let secondaryColor = Color(red: 0.94, green: 0.43, blue: 0.67)
    private static let streakCount = 280

    private static let overlayOpacity: Double = 0.76
    private static let blurRadiusMinimum: CGFloat = 0.16
    private static let blurRadiusScale: CGFloat = 0.0016

    private static let angleJitter: Double = 0.08
    private static let strokeStartRadiusMinimum: CGFloat = 0.02
    private static let strokeStartRadiusRange: CGFloat = 0.24
    private static let strokeEndRadiusMinimum: CGFloat = 0.78
    private static let strokeEndRadiusRange: CGFloat = 0.2
    private static let strokeLineWidthMinimum: CGFloat = 0.022
    private static let strokeLineWidthRange: CGFloat = 0.052
    private static let strokeOpacityMinimum: Double = 0.82
    private static let strokeOpacityRange: Double = 0.18
    private static let secondaryColorThreshold: CGFloat = 0.8

    private static let branchThreshold: CGFloat = 0.68
    private static let branchAngleJitter: Double = 0.22
    private static let branchLengthMinimum: CGFloat = 0.14
    private static let branchLengthRange: CGFloat = 0.2
    private static let branchOpacityMultiplier: Double = 0.72
    private static let branchLineWidthMultiplier: CGFloat = 0.6

    private static let marbleMinimumCount = 28
    private static let marbleDivisor = 4
    private static let marbleStartRadiusMinimum: CGFloat = 0.09
    private static let marbleStartRadiusRange: CGFloat = 0.34
    private static let marbleEndRadiusMinimum: CGFloat = 0.7
    private static let marbleEndRadiusRange: CGFloat = 0.24
    private static let marbleLineWidthMinimum: CGFloat = 0.008
    private static let marbleLineWidthRange: CGFloat = 0.028
    private static let marbleOpacityMinimum: Double = 0.16
    private static let marbleOpacityRange: Double = 0.24
    private static let marbleColor: Color = .white

    private struct OverlayView: View {
        let size: CGFloat

        var body: some View {
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = min(canvasSize.width, canvasSize.height) / 2
                context.addFilter(
                    .blur(
                        radius: max(
                            PinkSplatterRecordTheme.blurRadiusMinimum,
                            radius * PinkSplatterRecordTheme.blurRadiusScale
                        )
                    )
                )

                for streak in 0..<PinkSplatterRecordTheme.streakCount {
                    let seed = streak * 17
                    let unitAngle = deterministicUnit(seed + 1)
                    let angle = (Double(unitAngle) * Double.pi * 2) + (Double(deterministicSigned(seed + 2)) * PinkSplatterRecordTheme.angleJitter)
                    let startRadius = radius * (PinkSplatterRecordTheme.strokeStartRadiusMinimum + deterministicUnit(seed + 3) * PinkSplatterRecordTheme.strokeStartRadiusRange)
                    let endRadius = radius * (PinkSplatterRecordTheme.strokeEndRadiusMinimum + deterministicUnit(seed + 4) * PinkSplatterRecordTheme.strokeEndRadiusRange)
                    let lineWidth = radius * (PinkSplatterRecordTheme.strokeLineWidthMinimum + deterministicUnit(seed + 5) * PinkSplatterRecordTheme.strokeLineWidthRange)
                    let opacity = PinkSplatterRecordTheme.strokeOpacityMinimum + deterministicUnit(seed + 6) * PinkSplatterRecordTheme.strokeOpacityRange
                    let hueShift = deterministicUnit(seed + 6)

                    let color = hueShift > PinkSplatterRecordTheme.secondaryColorThreshold
                    ? PinkSplatterRecordTheme.secondaryColor
                    : PinkSplatterRecordTheme.primaryColor

                    let startPoint = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * startRadius,
                        y: center.y + CGFloat(sin(angle)) * startRadius
                    )
                    let endPoint = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * endRadius,
                        y: center.y + CGFloat(sin(angle)) * endRadius
                    )

                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)

                    context.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )

                    if deterministicUnit(seed + 7) > PinkSplatterRecordTheme.branchThreshold {
                        let branchAngle = angle + (Double(deterministicSigned(seed + 8)) * PinkSplatterRecordTheme.branchAngleJitter)
                        let branchLength = radius * (PinkSplatterRecordTheme.branchLengthMinimum + deterministicUnit(seed + 9) * PinkSplatterRecordTheme.branchLengthRange)
                        let branchEndPoint = CGPoint(
                            x: endPoint.x + CGFloat(cos(branchAngle)) * branchLength,
                            y: endPoint.y + CGFloat(sin(branchAngle)) * branchLength
                        )

                        var branchPath = Path()
                        branchPath.move(to: endPoint)
                        branchPath.addLine(to: branchEndPoint)

                        context.stroke(
                            branchPath,
                            with: .color(color.opacity(opacity * PinkSplatterRecordTheme.branchOpacityMultiplier)),
                            style: StrokeStyle(
                                lineWidth: lineWidth * PinkSplatterRecordTheme.branchLineWidthMultiplier,
                                lineCap: .round
                            )
                        )
                    }
                }

                let marbleCount = max(
                    PinkSplatterRecordTheme.marbleMinimumCount,
                    PinkSplatterRecordTheme.streakCount / max(1, PinkSplatterRecordTheme.marbleDivisor)
                )
                for marble in 0..<marbleCount {
                    let seed = marble * 31
                    let angle = Double(deterministicUnit(seed + 1)) * Double.pi * 2
                    let startRadius = radius * (PinkSplatterRecordTheme.marbleStartRadiusMinimum + deterministicUnit(seed + 2) * PinkSplatterRecordTheme.marbleStartRadiusRange)
                    let endRadius = radius * (PinkSplatterRecordTheme.marbleEndRadiusMinimum + deterministicUnit(seed + 3) * PinkSplatterRecordTheme.marbleEndRadiusRange)
                    let lineWidth = radius * (PinkSplatterRecordTheme.marbleLineWidthMinimum + deterministicUnit(seed + 4) * PinkSplatterRecordTheme.marbleLineWidthRange)
                    let opacity = PinkSplatterRecordTheme.marbleOpacityMinimum + deterministicUnit(seed + 5) * PinkSplatterRecordTheme.marbleOpacityRange

                    let startPoint = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * startRadius,
                        y: center.y + CGFloat(sin(angle)) * startRadius
                    )
                    let endPoint = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * endRadius,
                        y: center.y + CGFloat(sin(angle)) * endRadius
                    )

                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)

                    context.stroke(
                        path,
                        with: .color(PinkSplatterRecordTheme.marbleColor.opacity(opacity)),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                }
            }
            .opacity(PinkSplatterRecordTheme.overlayOpacity)
            .clipShape(Circle())
            .frame(width: size, height: size)
        }

        private func deterministicUnit(_ seed: Int) -> CGFloat {
            let value = sin(Double(seed) * 12.9898 + 78.233) * 43758.5453
            return CGFloat(value - floor(value))
        }

        private func deterministicSigned(_ seed: Int) -> CGFloat {
            (deterministicUnit(seed) * 2) - 1
        }
    }

    static let palette = RecordThemePalette(
        backgroundColor: Color(red: 0.97, green: 0.92, blue: 0.89),
        trackDividerColor: Color(red: 0.91, green: 0.72, blue: 0.79),
        bufferColor: Color(red: 0.91, green: 0.72, blue: 0.79),
        surfaceOverlay: RecordThemeSurfaceOverlay { size in
            OverlayView(size: size)
        }
    )
}
