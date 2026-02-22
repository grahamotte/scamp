import SwiftUI

struct ControlsAreaView: View {
    let width: CGFloat
    let height: CGFloat
    let edgeInset: CGFloat

    @ObservedObject var playback: PlaybackController

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                Spacer()

                TransportControlsView(playback: playback, buttonSpacing: 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, edgeInset)
            }
        }
        .frame(width: width, height: height)
    }
}
