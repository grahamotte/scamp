import SwiftUI

struct WoodGrainBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.14, blue: 0.08),
                    Color(red: 0.18, green: 0.10, blue: 0.06),
                    Color(red: 0.28, green: 0.16, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WoodGrainOverlay()
                .blendMode(.overlay)
                .opacity(0.62)
        }
    }
}

private struct WoodGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let strideValue: CGFloat = 8
            let rows = Int(size.height / strideValue) + 1

            for row in 0..<rows {
                let y = CGFloat(row) * strideValue
                let wave = sin(Double(row) * 0.28) + (sin(Double(row) * 0.11) * 0.6)
                let thickness = 3 + (cos(Double(row) * 0.25) * 1.2)
                let offset = CGFloat(wave) * 4
                let rect = CGRect(x: -20, y: y + offset, width: size.width + 40, height: max(thickness, 1.5))
                let shade = 0.08 + (abs(sin(Double(row) * 0.41)) * 0.08)
                context.fill(Path(rect), with: .color(Color.black.opacity(shade)))
            }
        }
        .allowsHitTesting(false)
    }
}
