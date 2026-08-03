import SwiftUI

struct ControlsAreaView: View {
    let width: CGFloat
    let height: CGFloat
    let edgeInset: CGFloat
    let controlsTheme: ControlsTheme

    @ObservedObject var playback: PlaybackController

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TransportControlsView(
                playback: playback,
                controlsTheme: controlsTheme,
                buttonSpacing: 10
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, edgeInset)
        }
        .frame(width: width, height: height)
    }
}
