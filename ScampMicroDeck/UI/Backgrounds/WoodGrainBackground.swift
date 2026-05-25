import SwiftUI

struct WoodTableTheme: TableThemeDefinition {
    static let displayName = "Wood"
    static let usesWindowTranslucency = false
    static var background: AnyView { AnyView(WoodGrainBackground()) }
}

struct WoodGrainBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.50, green: 0.32, blue: 0.18),
                    Color(red: 0.31, green: 0.18, blue: 0.10),
                    Color(red: 0.58, green: 0.38, blue: 0.21)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WoodTableTexture()
                .blendMode(.softLight)
                .opacity(0.85)

            ThemeLightReader { light in
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.clear,
                            Color.black.opacity(0.12)
                        ],
                        startPoint: light.start,
                        endPoint: light.end
                    )
                    .blendMode(.softLight)

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color.white.opacity(0.02),
                            Color.clear,
                            Color.clear
                        ],
                        center: light.radialCenter,
                        startRadius: 60,
                        endRadius: 320
                    )
                    .blendMode(.screen)
                }
            }

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.22)
                ],
                center: .center,
                startRadius: 180,
                endRadius: 640
            )
                .blendMode(.multiply)
        }
    }
}

private struct WoodTableTexture: View {
    var body: some View {
        Canvas { context, size in
            let plankHeight = max(78, size.height / 5.5)
            let plankCount = Int(size.height / plankHeight) + 2
            let grainStride: CGFloat = 5
            let startX: CGFloat = -24
            let endX = size.width + 24
            let waveStep: CGFloat = 18

            for plank in 0..<plankCount {
                let y = CGFloat(plank) * plankHeight
                let tint = plank.isMultiple(of: 2) ? Color.white.opacity(0.035) : Color.black.opacity(0.04)
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: plankHeight)), with: .color(tint))

                var seam = Path()
                seam.move(to: CGPoint(x: 0, y: y))
                seam.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(seam, with: .color(Color.black.opacity(0.11)), lineWidth: 2)
                context.stroke(seam.applying(CGAffineTransform(translationX: 0, y: 1)), with: .color(Color.white.opacity(0.045)), lineWidth: 1)
            }

            let rows = Int(size.height / grainStride) + 1
            for row in 0..<rows {
                let baseY = CGFloat(row) * grainStride
                let plank = Int(baseY / plankHeight)
                let phase = Double(plank) * 1.2 + Double(row) * 0.16
                let amplitude = 2.4 + abs(sin(Double(row) * 0.19)) * 3.8
                let wavelengthA = max(size.width * (0.26 + CGFloat(plank % 3) * 0.08), 150)
                let wavelengthB = max(size.width * 0.62, 260)
                let lineWidth = 0.6 + abs(cos(Double(row) * 0.23)) * 1.2

                var grain = Path()
                grain.move(to: CGPoint(x: startX, y: baseY))
                var x = startX
                while x <= endX {
                    let primary = sin((Double(x / wavelengthA) * .pi * 2) + phase)
                    let secondary = sin((Double(x / wavelengthB) * .pi * 2) - phase * 0.45)
                    grain.addLine(to: CGPoint(x: x, y: baseY + CGFloat(primary + secondary * 0.7) * amplitude))
                    x += waveStep
                }

                context.stroke(grain, with: .color(Color.black.opacity(0.08 + abs(sin(Double(row) * 0.41)) * 0.09)), lineWidth: lineWidth)
                context.stroke(grain.applying(CGAffineTransform(translationX: 0, y: -0.7)), with: .color(Color.white.opacity(0.015 + abs(cos(Double(row) * 0.33)) * 0.03)), lineWidth: 0.6)
            }
        }
        .allowsHitTesting(false)
    }
}
