import SwiftUI

struct TransportControlsView: View {
    @ObservedObject var playback: PlaybackController
    private let buttonDiameter: CGFloat = 40
    private let iconSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 0) {
            TransportControlButton(icon: "eject.fill", buttonDiameter: buttonDiameter, iconSize: iconSize) {
                playback.loadFolder()
            }

            TransportControlButton(icon: "backward.fill", buttonDiameter: buttonDiameter, iconSize: iconSize) {
                playback.playPrevious()
            }

            TransportControlButton(icon: "playpause.fill", buttonDiameter: buttonDiameter, iconSize: iconSize) {
                playback.togglePlayPause()
            }

            TransportControlButton(icon: "forward.fill", buttonDiameter: buttonDiameter, iconSize: iconSize) {
                playback.playNext()
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

private struct TransportControlButton: View {
    let icon: String
    let buttonDiameter: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            ControlClickSoundPlayer.shared.play()
            action()
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(
            PhysicalTransportButtonStyle(
                buttonDiameter: buttonDiameter,
                iconSize: iconSize
            )
        )
        .frame(maxWidth: .infinity)
    }
}

private struct PhysicalTransportButtonStyle: ButtonStyle {
    let buttonDiameter: CGFloat
    let iconSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let centerOffset = configuration.isPressed ? buttonDiameter * 0.05 : 0
        let centerShadowRadius = configuration.isPressed ? buttonDiameter * 0.02 : buttonDiameter * 0.08
        let centerShadowY = configuration.isPressed ? buttonDiameter * 0.02 : buttonDiameter * 0.05

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.9), Color(white: 0.67), Color(white: 0.83)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.7), Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.2
                )

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .padding(buttonDiameter * 0.12)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.96), Color(white: 0.75), Color(white: 0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(buttonDiameter * 0.18)
                .offset(y: centerOffset)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: centerShadowRadius,
                    x: 0,
                    y: centerShadowY
                )

            configuration.label
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color(white: 0.29))
                .offset(y: centerOffset)
        }
        .frame(width: buttonDiameter, height: buttonDiameter)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
