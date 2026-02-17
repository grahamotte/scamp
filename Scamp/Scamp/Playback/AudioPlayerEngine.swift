import AVFoundation
import Foundation

final class AudioPlayerEngine: NSObject {
    var onFinishPlaying: ((Bool) -> Void)?
    var onDecodeError: (() -> Void)?

    private var player: AVAudioPlayer?

    var hasLoadedTrack: Bool {
        player != nil
    }

    func play(url: URL) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    func resume() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

extension AudioPlayerEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.onFinishPlaying?(flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            self?.onDecodeError?()
        }
    }
}
