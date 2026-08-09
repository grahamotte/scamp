import SwiftUI

struct BlackMarbleTableTheme: TableThemeDefinition {
    static let displayName = "Black Marble"
    static let usesWindowTranslucency = false
    static var background: AnyView { AnyView(BlackMarbleTableBackground()) }
}

struct BlackMarbleTableBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.blackMarble(
                            .float2(proxy.size)
                        )
                    )
                }

            ThemeLightReader { light in
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.11),
                            Color.clear,
                            Color.black.opacity(0.18),
                        ],
                        startPoint: light.start,
                        endPoint: light.end
                    )
                    .blendMode(.softLight)

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.04),
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
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.white.opacity(0.015),
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.28),
                ],
                center: .center,
                startRadius: 220,
                endRadius: 760
            )
            .blendMode(.multiply)
        }
    }
}
