import SwiftUI

struct TransportControlsView: View {
    @ObservedObject var playback: PlaybackController
    private let buttonDiameter: CGFloat = 40
    private let iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 0) {
            controlButton(icon: "folder.fill") {
                playback.loadFolder()
            }

            controlButton(icon: "backward.fill", isDisabled: !playback.canPlayPrevious) {
                playback.playPrevious()
            }

            controlButton(icon: playback.isPlaying ? "pause.fill" : "play.fill", isDisabled: !playback.hasPlaylist) {
                playback.togglePlayPause()
            }

            controlButton(icon: "forward.fill", isDisabled: !playback.canPlayNext) {
                playback.playNext()
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func controlButton(icon: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isDisabled ? Color(white: 0.55) : Color(white: 0.2))
                .frame(width: buttonDiameter, height: buttonDiameter)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isDisabled
                                    ? [Color(white: 0.73), Color(white: 0.58), Color(white: 0.67)]
                                    : [Color(white: 0.89), Color(white: 0.66), Color(white: 0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), Color.black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .padding(buttonDiameter * 0.12)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .frame(maxWidth: .infinity)
    }
}
