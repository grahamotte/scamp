import SwiftUI

struct BlueSplatterRecordTheme: RecordThemeDefinition {
    static let displayName = "Blue Splatter"
    private static let primaryColor = Color(red: 0.15, green: 0.84, blue: 0.92)
    private static let secondaryColor = Color(red: 0.03, green: 0.46, blue: 0.63)

    private static let streakCount = 220
    private static let cloudCount = 6

    private static let overlayOpacity: Double = 0.8
    private static let blurRadiusMinimum: CGFloat = 0.12
    private static let blurRadiusScale: CGFloat = 0.0012

    private static let angleJitter: Double = 0.07
    private static let strokeStartRadiusMinimum: CGFloat = 0.06
    private static let strokeStartRadiusRange: CGFloat = 0.22
    private static let strokeEndRadiusMinimum: CGFloat = 0.8
    private static let strokeEndRadiusRange: CGFloat = 0.16
    private static let strokeLineWidthMinimum: CGFloat = 0.012
    private static let strokeLineWidthRange: CGFloat = 0.028
    private static let strokeOpacityMinimum: Double = 0.52
    private static let strokeOpacityRange: Double = 0.24
    private static let secondaryColorThreshold: CGFloat = 0.74

    private static let tipDotThreshold: CGFloat = 0.58
    private static let tipDotRadiusMinimum: CGFloat = 0.005
    private static let tipDotRadiusRange: CGFloat = 0.02
    private static let tipDotOpacityMinimum: Double = 0.72
    private static let tipDotOpacityRange: Double = 0.2

    private static let cloudRadiusMinimum: CGFloat = 0.16
    private static let cloudRadiusRange: CGFloat = 0.12
    private static let cloudOpacityMinimum: Double = 0.44
    private static let cloudOpacityRange: Double = 0.18
    private static let cloudColor: Color = .white

    private struct OverlayView: View {
        let size: CGFloat

        var body: some View {
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = min(canvasSize.width, canvasSize.height) / 2
                context.addFilter(
                    .blur(
                        radius: max(
                            BlueSplatterRecordTheme.blurRadiusMinimum,
                            radius * BlueSplatterRecordTheme.blurRadiusScale
                        )
                    )
                )

                for streak in 0..<BlueSplatterRecordTheme.streakCount {
                    let seed = streak * 19
                    let baseAngle = Double(deterministicUnit(seed + 1)) * Double.pi * 2
                    let angle = baseAngle + (Double(deterministicSigned(seed + 2)) * BlueSplatterRecordTheme.angleJitter)
                    let startRadius = radius * (
                        BlueSplatterRecordTheme.strokeStartRadiusMinimum
                        + deterministicUnit(seed + 3) * BlueSplatterRecordTheme.strokeStartRadiusRange
                    )
                    let endRadius = radius * (
                        BlueSplatterRecordTheme.strokeEndRadiusMinimum
                        + deterministicUnit(seed + 4) * BlueSplatterRecordTheme.strokeEndRadiusRange
                    )
                    let lineWidth = radius * (
                        BlueSplatterRecordTheme.strokeLineWidthMinimum
                        + deterministicUnit(seed + 5) * BlueSplatterRecordTheme.strokeLineWidthRange
                    )
                    let opacity = BlueSplatterRecordTheme.strokeOpacityMinimum
                    + deterministicUnit(seed + 6) * BlueSplatterRecordTheme.strokeOpacityRange
                    let color = deterministicUnit(seed + 7) > BlueSplatterRecordTheme.secondaryColorThreshold
                    ? BlueSplatterRecordTheme.secondaryColor
                    : BlueSplatterRecordTheme.primaryColor

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

                    if deterministicUnit(seed + 8) > BlueSplatterRecordTheme.tipDotThreshold {
                        let dotRadius = radius * (
                            BlueSplatterRecordTheme.tipDotRadiusMinimum
                            + deterministicUnit(seed + 9) * BlueSplatterRecordTheme.tipDotRadiusRange
                        )
                        let dotOpacity = BlueSplatterRecordTheme.tipDotOpacityMinimum
                        + deterministicUnit(seed + 10) * BlueSplatterRecordTheme.tipDotOpacityRange
                        let dotDrift = radius * (0.015 + deterministicUnit(seed + 11) * 0.04)
                        let dotAngle = angle + Double(deterministicSigned(seed + 12)) * 0.12
                        let dotCenter = CGPoint(
                            x: endPoint.x + CGFloat(cos(dotAngle)) * dotDrift,
                            y: endPoint.y + CGFloat(sin(dotAngle)) * dotDrift
                        )

                        let dotRect = CGRect(
                            x: dotCenter.x - dotRadius,
                            y: dotCenter.y - dotRadius,
                            width: dotRadius * 2,
                            height: dotRadius * 2
                        )

                        context.fill(
                            Path(ellipseIn: dotRect),
                            with: .color(BlueSplatterRecordTheme.secondaryColor.opacity(dotOpacity))
                        )
                    }
                }

                for cloud in 0..<BlueSplatterRecordTheme.cloudCount {
                    let seed = cloud * 47
                    let angle = Double(deterministicUnit(seed + 1)) * Double.pi * 2
                    let cloudRadius = radius * (
                        BlueSplatterRecordTheme.cloudRadiusMinimum
                        + deterministicUnit(seed + 2) * BlueSplatterRecordTheme.cloudRadiusRange
                    )
                    let cloudDistance = radius * (0.26 + deterministicUnit(seed + 3) * 0.28)
                    let cloudOpacity = BlueSplatterRecordTheme.cloudOpacityMinimum
                    + deterministicUnit(seed + 4) * BlueSplatterRecordTheme.cloudOpacityRange
                    let cloudCenter = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * cloudDistance,
                        y: center.y + CGFloat(sin(angle)) * cloudDistance
                    )
                    let cloudRect = CGRect(
                        x: cloudCenter.x - cloudRadius,
                        y: cloudCenter.y - cloudRadius,
                        width: cloudRadius * 2,
                        height: cloudRadius * 2
                    )

                    context.fill(
                        Path(ellipseIn: cloudRect),
                        with: .color(BlueSplatterRecordTheme.cloudColor.opacity(cloudOpacity))
                    )
                }
            }
            .opacity(BlueSplatterRecordTheme.overlayOpacity)
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
        backgroundColor: Color(red: 0.96, green: 0.97, blue: 0.96),
        trackDividerColor: Color(red: 0.58, green: 0.82, blue: 0.9),
        bufferColor: Color(red: 0.67, green: 0.86, blue: 0.92),
        surfaceOverlay: RecordThemeSurfaceOverlay { size in
            OverlayView(size: size)
        }
    )
}
