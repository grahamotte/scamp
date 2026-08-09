import SwiftUI

struct WhiteMarbleTableTheme: TableThemeDefinition {
    static let displayName = "White Marble"
    static let usesWindowTranslucency = false
    static var background: AnyView { AnyView(WhiteMarbleTableBackground()) }
}

struct WhiteMarbleTableBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.white)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.whiteMarble(
                            .float2(proxy.size)
                        )
                    )
                }

            ThemeLightReader { light in
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.13),
                            Color.clear,
                            Color.black.opacity(0.075),
                        ],
                        startPoint: light.start,
                        endPoint: light.end
                    )
                    .blendMode(.softLight)

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.035),
                            Color.clear,
                            Color.clear,
                        ],
                        center: light.radialCenter,
                        startRadius: 24,
                        endRadius: 390
                    )
                    .blendMode(.screen)
                }
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(0.20),
                    Color.clear,
                    Color.white.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.09),
                ],
                center: .center,
                startRadius: 220,
                endRadius: 760
            )
            .blendMode(.multiply)
        }
    }
}
