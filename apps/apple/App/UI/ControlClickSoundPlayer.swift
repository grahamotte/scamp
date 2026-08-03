import AVFoundation
import Foundation

@MainActor
final class ControlClickSoundPlayer {
    static let shared = ControlClickSoundPlayer()

    private var player: AVAudioPlayer?

    private init() {
        let soundURL =
            Bundle.main.url(
                forResource: "cassette-player-button",
                withExtension: "mp3",
                subdirectory: "Sounds"
            ) ??
            Bundle.main.url(
                forResource: "cassette-player-button",
                withExtension: "mp3"
            )

        guard let soundURL else { return }
        player = try? AVAudioPlayer(contentsOf: soundURL)
        player?.prepareToPlay()
    }

    func play() {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }
}
