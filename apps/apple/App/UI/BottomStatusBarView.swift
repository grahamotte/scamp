import SwiftUI

struct BottomStatusBarView: View {
    let title: String
    let height: CGFloat

    var body: some View {
        HStack {
            Spacer()

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .tracking(1.0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}
