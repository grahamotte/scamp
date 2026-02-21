import SwiftUI

struct WoodGrainBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.29, blue: 0.17),
                    Color(red: 0.31, green: 0.20, blue: 0.12),
                    Color(red: 0.45, green: 0.31, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WoodFigureOverlay()
                .blendMode(.softLight)
                .opacity(0.42)

            WoodGrainOverlay()
                .blendMode(.multiply)
                .opacity(0.6)
        }
    }
}

private struct WoodFigureOverlay: View {
    var body: some View {
        Canvas { context, size in
            let bandCount = 12
            let stepY = size.height / CGFloat(bandCount)
            let waveStep: CGFloat = 28

            for index in 0...bandCount {
                let baseY = CGFloat(index) * stepY
                let amplitude = 8 + (sin(Double(index) * 0.7) * 3)
                let wavelength = max(size.width * 0.75, 260)
                let thickness = stepY * 1.7
                let isWarmBand = index.isMultiple(of: 2)

                var bandPath = Path()
                var topPoints: [CGPoint] = []
                var bottomPoints: [CGPoint] = []

                var x: CGFloat = -32
                while x <= size.width + 32 {
                    let wave = sin((Double(x / wavelength) * .pi * 2) + (Double(index) * 0.45))
                    let y = baseY + CGFloat(wave) * amplitude
                    topPoints.append(CGPoint(x: x, y: y))
                    bottomPoints.append(CGPoint(x: x, y: y + thickness))
                    x += waveStep
                }

                if let first = topPoints.first {
                    bandPath.move(to: first)
                    for point in topPoints.dropFirst() {
                        bandPath.addLine(to: point)
                    }
                    for point in bottomPoints.reversed() {
                        bandPath.addLine(to: point)
                    }
                    bandPath.closeSubpath()
                }

                let bandColor: Color = isWarmBand
                    ? Color(red: 0.73, green: 0.52, blue: 0.33).opacity(0.11)
                    : Color.black.opacity(0.05)
                context.fill(bandPath, with: .color(bandColor))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WoodGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let strideValue: CGFloat = 7
            let rows = Int(size.height / strideValue) + 1
            let startX: CGFloat = -24
            let endX = size.width + 24
            let waveStep: CGFloat = 22
            let wavelengthPrimary = max(size.width * 0.22, 120)
            let wavelengthSecondary = max(size.width * 0.48, 200)

            for row in 0..<rows {
                let baseY = CGFloat(row) * strideValue
                let rowPhaseA = Double(row) * 0.21
                let rowPhaseB = Double(row) * 0.09
                let amplitude = 3.2 + (sin(Double(row) * 0.17) * 1.8)
                let thickness = 1.4 + (cos(Double(row) * 0.18) * 0.9)
                let shade = 0.05 + (abs(sin(Double(row) * 0.37)) * 0.08)
                let warmShade = 0.025 + (abs(cos(Double(row) * 0.31)) * 0.05)
                let highlightShade = 0.01 + (abs(sin(Double(row) * 0.29)) * 0.026)

                var grainPath = Path()
                grainPath.move(to: CGPoint(x: startX, y: baseY))

                var x = startX
                while x <= endX {
                    let primary = Double(x / wavelengthPrimary) * .pi * 2
                    let secondary = Double(x / wavelengthSecondary) * .pi * 2
                    let yOffset = sin(primary + rowPhaseA) * amplitude
                        + sin(secondary + rowPhaseB) * (amplitude * 0.45)
                    grainPath.addLine(to: CGPoint(x: x, y: baseY + CGFloat(yOffset)))
                    x += waveStep
                }

                context.stroke(
                    grainPath,
                    with: .color(Color.black.opacity(shade)),
                    lineWidth: max(thickness, 0.8)
                )

                context.stroke(
                    grainPath,
                    with: .color(Color(red: 0.46, green: 0.27, blue: 0.15).opacity(warmShade)),
                    lineWidth: max(thickness * 1.35, 0.9)
                )

                let highlightPath = grainPath.applying(CGAffineTransform(translationX: 0, y: -0.65))
                context.stroke(
                    highlightPath,
                    with: .color(Color.white.opacity(highlightShade)),
                    lineWidth: max(thickness * 0.54, 0.5)
                )
            }
        }
        .allowsHitTesting(false)
    }
}
