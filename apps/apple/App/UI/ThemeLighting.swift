import SwiftUI

struct ThemeLighting {
    static let coordinateSpaceName = "theme-lighting"

    let source: CGPoint

    static func initialSource(in size: CGSize) -> CGPoint {
        clampedSource(CGPoint(x: 24, y: 24), in: size)
    }

    static func clampedSource(_ source: CGPoint, in size: CGSize) -> CGPoint {
        let inset: CGFloat = 22
        let minX = min(inset, max(0, size.width / 2))
        let maxX = max(minX, size.width - inset)
        let minY = min(inset, max(0, size.height / 2))
        let maxY = max(minY, size.height - inset)

        return CGPoint(
            x: min(max(source.x, minX), maxX),
            y: min(max(source.y, minY), maxY)
        )
    }

    func direction(for frame: CGRect) -> ThemeLightDirection {
        let dx = (source.x - frame.midX) / max(frame.width, 1)
        let dy = (source.y - frame.midY) / max(frame.height, 1)
        let length = max(0.001, sqrt((dx * dx) + (dy * dy)))

        return ThemeLightDirection(
            unitX: dx / length,
            unitY: dy / length
        )
    }
}

struct ThemeLightDirection {
    let unitX: CGFloat
    let unitY: CGFloat

    var start: UnitPoint {
        UnitPoint(x: 0.5 + (unitX * 0.36), y: 0.5 + (unitY * 0.36))
    }

    var end: UnitPoint {
        UnitPoint(x: 0.5 - (unitX * 0.36), y: 0.5 - (unitY * 0.36))
    }

    var radialCenter: UnitPoint {
        UnitPoint(
            x: min(max(0.5 + (unitX * 0.24), 0.12), 0.88),
            y: min(max(0.5 + (unitY * 0.24), 0.12), 0.88)
        )
    }

    func highlightOffset(_ scale: CGFloat) -> CGSize {
        CGSize(width: unitX * scale, height: unitY * scale)
    }

    func shadowOffset(_ scale: CGFloat) -> CGSize {
        CGSize(width: -unitX * scale, height: -unitY * scale)
    }

    func rotated(by angle: Angle) -> ThemeLightDirection {
        let radians = angle.radians
        let cosine = cos(radians)
        let sine = sin(radians)

        return ThemeLightDirection(
            unitX: (unitX * cosine) - (unitY * sine),
            unitY: (unitX * sine) + (unitY * cosine)
        )
    }
}

struct ThemeLightReader<Content: View>: View {
    @Environment(\.themeLighting) private var lighting

    let content: (ThemeLightDirection) -> Content

    init(@ViewBuilder content: @escaping (ThemeLightDirection) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            content(
                lighting.direction(
                    for: proxy.frame(in: .named(ThemeLighting.coordinateSpaceName))
                )
            )
        }
    }
}

struct ThemeLightSourceHandle: View {
    @Binding var source: CGPoint
    let windowSize: CGSize

    var body: some View {
        Image(systemName: "sun.max.fill")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.96, blue: 0.55),
                        Color(red: 1.0, green: 0.70, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .white.opacity(0.8), radius: 5)
            .shadow(color: .black.opacity(0.28), radius: 3, x: 0, y: 1.5)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .position(source)
            .gesture(
                DragGesture(coordinateSpace: .named(ThemeLighting.coordinateSpaceName))
                    .onChanged { value in
                        source = ThemeLighting.clampedSource(value.location, in: windowSize)
                    }
            )
            .accessibilityLabel("Theme light source")
    }
}

private struct ThemeLightingKey: EnvironmentKey {
    static let defaultValue = ThemeLighting(source: CGPoint(x: 24, y: 24))
}

extension EnvironmentValues {
    var themeLighting: ThemeLighting {
        get { self[ThemeLightingKey.self] }
        set { self[ThemeLightingKey.self] = newValue }
    }
}
