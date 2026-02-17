import SwiftUI

struct RecordAreaPlaceholderView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Color.clear

            Text("Record Area")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: size, height: size)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}
