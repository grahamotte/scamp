import SwiftUI

struct WalnutTableTheme: TableThemeDefinition {
    static let displayName = "Walnut"
    static let usesWindowTranslucency = false
    static var background: AnyView { AnyView(WalnutTableBackground()) }
}

struct WalnutTableBackground: View {
    var body: some View {
        ThemeLightReader { light in
            ZStack {
                Rectangle()
                    .fill(Color(red: 0.20, green: 0.07, blue: 0.024))
                    .visualEffect { content, proxy in
                        content.colorEffect(
                            ShaderLibrary.walnut(
                                .float2(proxy.size),
                                .float2(light.unitX, light.unitY)
                            )
                        )
                    }

                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.02), location: 0),
                        .init(color: Color(red: 1.0, green: 0.72, blue: 0.40).opacity(0.009), location: 0.26),
                        .init(color: Color.clear, location: 0.56),
                        .init(color: Color.black.opacity(0.02), location: 1),
                    ],
                    startPoint: light.start,
                    endPoint: light.end
                )
                .blendMode(.softLight)

                RadialGradient(
                    stops: [
                        .init(color: Color(red: 1.0, green: 0.84, blue: 0.62).opacity(0.015), location: 0),
                        .init(color: Color.white.opacity(0.004), location: 0.24),
                        .init(color: Color.clear, location: 0.62),
                        .init(color: Color.clear, location: 1),
                    ],
                    center: light.radialCenter,
                    startRadius: 18,
                    endRadius: 460
                )
                .blendMode(.screen)

                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.025), location: 0),
                        .init(color: Color.white.opacity(0.005), location: 0.07),
                        .init(color: Color.clear, location: 0.19),
                        .init(color: Color.clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)

                RadialGradient(
                    stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.clear, location: 0.48),
                        .init(color: Color.black.opacity(0.015), location: 0.78),
                        .init(color: Color.black.opacity(0.035), location: 1),
                    ],
                    center: .center,
                    startRadius: 160,
                    endRadius: 790
                )
                .blendMode(.multiply)
            }
        }
    }
}
