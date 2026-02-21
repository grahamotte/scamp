import SwiftUI

struct FrostedGlassTableBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.94, blue: 0.98),
                    Color(red: 0.79, green: 0.84, blue: 0.91),
                    Color(red: 0.88, green: 0.92, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.08)

            Rectangle()
                .fill(Color.white.opacity(0.015))

            LinearGradient(
                colors: [
                    Color(red: 0.76, green: 0.84, blue: 0.97).opacity(0.06),
                    Color(red: 0.88, green: 0.93, blue: 0.99).opacity(0.02),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.45)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .opacity(0.35)
        }
    }
}
