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

                TransportControlsView(playback: playback)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: width, height: height)
    }
}
