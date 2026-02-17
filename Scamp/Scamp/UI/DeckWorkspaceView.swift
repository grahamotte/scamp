import SwiftUI

struct DeckWorkspaceView: View {
    @ObservedObject var playback: PlaybackController

    private var bottomBarTitle: String {
        if playback.isPlaying, let currentTrackDisplayName = playback.currentTrackDisplayName {
            return currentTrackDisplayName
        }
        return ScampLayout.statusFallbackTitle
    }

    var body: some View {
        ZStack {
            WoodGrainBackground()
                .ignoresSafeArea()

            GeometryReader { geometry in
                let chromeInset = geometry.safeAreaInsets.top
                let squareSize = max(0, geometry.size.height - chromeInset)
                let controlsWidth = max(0, geometry.size.width - chromeInset - squareSize)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: chromeInset)

                        RecordAreaPlaceholderView(size: squareSize, playback: playback)

                        ControlsAreaView(
                            width: controlsWidth,
                            height: squareSize,
                            playback: playback
                        )
                    }

                    BottomStatusBarView(
                        title: bottomBarTitle,
                        height: chromeInset
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
