import SwiftUI

struct SilverTableBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.74, blue: 0.78),
                    Color(red: 0.58, green: 0.61, blue: 0.66),
                    Color(red: 0.68, green: 0.71, blue: 0.76)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.65)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.24),
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .opacity(0.75)
        }
    }
}
