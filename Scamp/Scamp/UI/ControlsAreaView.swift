import SwiftUI

struct ControlsAreaView: View {
    let width: CGFloat
    let height: CGFloat

    @ObservedObject var playback: PlaybackController

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                Spacer()

                Text("Arm / Controls Area")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                TransportControlsView(playback: playback)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: width, height: height)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}
