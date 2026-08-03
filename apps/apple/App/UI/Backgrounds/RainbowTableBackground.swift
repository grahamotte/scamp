import SwiftUI

struct RainbowTableTheme: TableThemeDefinition {
    static let displayName = "Rainbow"
    static let usesWindowTranslucency = false
    static var background: AnyView { AnyView(RainbowTableBackground()) }
}

struct RainbowTableBackground: View {
    private let spectrum: [Color] = [
        Color(red: 0.91, green: 0.02, blue: 0.04),
        Color(red: 1.00, green: 0.46, blue: 0.00),
        Color(red: 1.00, green: 0.84, blue: 0.00),
        Color(red: 0.00, green: 0.62, blue: 0.23),
        Color(red: 0.00, green: 0.42, blue: 0.88),
        Color(red: 0.48, green: 0.20, blue: 0.78)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.03, blue: 0.05),
                    Color(red: 0.02, green: 0.10, blue: 0.13),
                    Color(red: 0.12, green: 0.03, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RainbowTableInlays(colors: spectrum)
                .saturation(1.18)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.24),
                    Color.clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.20),
                    Color.clear,
                    Color.white.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.24)
                ],
                center: .center,
                startRadius: 140,
                endRadius: 720
            )
            .blendMode(.multiply)
        }
    }
}

private struct RainbowTableInlays: View {
    let colors: [Color]

    var body: some View {
        Canvas { context, size in
            let width = max(size.width, size.height) * 0.12
            let lean = size.height * 0.36
            let top = -size.height * 0.08
            let bottom = size.height * 1.08

            for index in -2..<(colors.count + 3) {
                let color = colors[(index + colors.count) % colors.count]
                let x = CGFloat(index) * width * 0.98 - width * 0.6
                var band = Path()
                band.move(to: CGPoint(x: x, y: top))
                band.addLine(to: CGPoint(x: x + width, y: top))
                band.addLine(to: CGPoint(x: x + width + lean, y: bottom))
                band.addLine(to: CGPoint(x: x + lean, y: bottom))
                band.closeSubpath()

                context.fill(band, with: .color(color.opacity(0.96)))
                context.stroke(band, with: .color(.white.opacity(0.18)), lineWidth: 1.2)
            }
        }
        .allowsHitTesting(false)
    }
}
