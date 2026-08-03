import SwiftUI

struct TransportControlsView: View {
    @ObservedObject var playback: PlaybackController
    let controlsTheme: ControlsTheme
    let buttonSpacing: CGFloat

    var body: some View {
        let transportButtons = controlsTheme.palette.transportButtons

        return HStack(spacing: buttonSpacing) {
            transportButtons.makeEjectButton {
                ControlClickSoundPlayer.shared.play()
                playback.ejectAndLoadFolder()
            }

            transportButtons.makePreviousButton {
                ControlClickSoundPlayer.shared.play()
                playback.playPrevious()
            }

            transportButtons.makePlayPauseButton {
                ControlClickSoundPlayer.shared.play()
                playback.togglePlayPause()
            }

            transportButtons.makeNextButton {
                ControlClickSoundPlayer.shared.play()
                playback.playNext()
            }
        }
    }
}
