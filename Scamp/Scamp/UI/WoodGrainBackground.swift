import SwiftUI

struct WoodGrainBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.33, green: 0.22, blue: 0.12),
                    Color(red: 0.27, green: 0.17, blue: 0.10),
                    Color(red: 0.37, green: 0.24, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WoodGrainOverlay()
                .blendMode(.overlay)
                .opacity(0.52)
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
                let shade = 0.06 + (abs(sin(Double(row) * 0.41)) * 0.06)
                context.fill(Path(rect), with: .color(Color.black.opacity(shade)))
            }
        }
        .allowsHitTesting(false)
    }
}
