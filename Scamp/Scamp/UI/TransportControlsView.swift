import SwiftUI

struct TransportControlsView: View {
    @ObservedObject var playback: PlaybackController

    var body: some View {
        HStack(spacing: 12) {
            Button {
                playback.loadFolder()
            } label: {
                Image(systemName: "folder")
            }

            Button {
                playback.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
            }
            .disabled(!playback.canPlayPrevious)

            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
            }
            .disabled(!playback.hasPlaylist)

            Button {
                playback.playNext()
            } label: {
                Image(systemName: "forward.fill")
            }
            .disabled(!playback.canPlayNext)
        }
    }
}
