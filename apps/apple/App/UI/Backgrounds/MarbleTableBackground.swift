import SwiftUI

struct MarbleTableTheme: TableThemeDefinition {
    static let displayName = "Marble"
    static let usesWindowTranslucency = false
    static var background: AnyView { AnyView(MarbleTableBackground()) }
}

struct MarbleTableBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.93, blue: 0.91),
                    Color(red: 0.83, green: 0.82, blue: 0.81),
                    Color(red: 0.90, green: 0.89, blue: 0.87)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.76, green: 0.79, blue: 0.84).opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.18, y: 0.12),
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    Color(red: 0.87, green: 0.83, blue: 0.76).opacity(0.30),
                    Color.clear
                ],
                center: UnitPoint(x: 0.85, y: 0.82),
                startRadius: 60,
                endRadius: 460
            )

            MarbleVeinTexture()
                .opacity(0.9)

            ThemeLightReader { light in
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear,
                            Color.black.opacity(0.10)
                        ],
                        startPoint: light.start,
                        endPoint: light.end
                    )
                    .blendMode(.softLight)

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.03),
                            Color.clear,
                            Color.clear
                        ],
                        center: light.radialCenter,
                        startRadius: 40,
                        endRadius: 300
                    )
                    .blendMode(.screen)
                }
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.clear,
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.16)
                ],
                center: .center,
                startRadius: 180,
                endRadius: 640
            )
            .blendMode(.multiply)
        }
    }
}

private struct MarbleVeinTexture: View {
    var body: some View {
        Canvas { context, size in
            let veinCount = 8

            for vein in 0..<veinCount {
                let phase = Double(vein) * 2.1
                let veinPath = Self.veinPath(vein: vein, phase: phase, in: size)
                let opacity = 0.10 + abs(sin(phase * 1.3)) * 0.14
                let lineWidth = 0.8 + abs(cos(phase)) * 1.6
                context.stroke(
                    veinPath,
                    with: .color(Color(red: 0.32, green: 0.33, blue: 0.36).opacity(opacity)),
                    lineWidth: lineWidth
                )
                context.stroke(
                    veinPath.applying(CGAffineTransform(translationX: 0, y: 1)),
                    with: .color(Color.white.opacity(0.35)),
                    lineWidth: 0.7
                )
            }

            let crackCount = 10
            for crack in 0..<crackCount {
                let phase = Double(crack) * 1.7 + 0.9
                let crackPath = Self.crackPath(phase: phase, in: size)
                context.stroke(
                    crackPath,
                    with: .color(Color(red: 0.42, green: 0.43, blue: 0.46).opacity(0.08 + abs(sin(phase)) * 0.08)),
                    lineWidth: 0.5 + abs(cos(phase)) * 0.5
                )
            }
        }
        .allowsHitTesting(false)
    }

    private static func veinPath(vein: Int, phase: Double, in size: CGSize) -> Path {
        let step: CGFloat = 14
        let endX = size.width + 24
        let progress = CGFloat(vein) / 8
        let baseY = size.height * (0.08 + progress * 0.84)
        let amplitude = size.height * (0.05 + abs(sin(phase)) * 0.10)
        let drift = size.height * 0.22 * (vein.isMultiple(of: 2) ? 1 : -1)

        var path = Path()
        var x: CGFloat = -24
        var isFirstPoint = true
        while x <= endX {
            let t = Double(x / max(size.width, 1))
            let primary = sin(t * .pi * 2 * (1.1 + Double(vein % 3) * 0.5) + phase) * 0.55
            let secondary = sin(t * .pi * 2 * 3.4 + phase * 1.7) * 0.30
            let tertiary = sin(t * .pi * 2 * 7.9 + phase * 2.3) * 0.15
            let y = baseY + (drift * CGFloat(t)) + (CGFloat(primary + secondary + tertiary) * amplitude)
            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: y))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        return path
    }

    private static func crackPath(phase: Double, in size: CGSize) -> Path {
        let originX = size.width * CGFloat(abs(sin(phase * 2.3)))
        let originY = size.height * CGFloat(abs(cos(phase * 1.1)))
        let length = size.width * (0.10 + abs(sin(phase)) * 0.14)
        let slope = CGFloat(sin(phase * 3.1)) * 0.6

        var path = Path()
        var x: CGFloat = 0
        var isFirstPoint = true
        while x <= length {
            let wobble = sin(Double(x) * 0.11 + phase) * 2.2 + sin(Double(x) * 0.031 + phase * 2.0) * 4.0
            let point = CGPoint(x: originX + x, y: originY + (x * slope) + CGFloat(wobble))
            if isFirstPoint {
                path.move(to: point)
                isFirstPoint = false
            } else {
                path.addLine(to: point)
            }
            x += 8
        }

        return path
    }
}
