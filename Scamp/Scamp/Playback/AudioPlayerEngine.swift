import AVFoundation
import Foundation

final class AudioPlayerEngine: NSObject {
    var onFinishPlaying: ((Bool) -> Void)?
    var onDecodeError: (() -> Void)?

    private static let minRate: Float = 0.5
    private static let maxRate: Float = 2.0
    private static let minVolume: Float = 0
    private static let maxVolume: Float = 1

    private var player: AVAudioPlayer?

    var hasLoadedTrack: Bool {
        player != nil
    }

    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    func play(url: URL, rate: Float = 1.0, volume: Float = 1.0) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.enableRate = true
        player.rate = clampedRate(rate)
        player.volume = clampedVolume(volume)
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    func resume(rate: Float? = nil, volume: Float? = nil) {
        if let rate {
            setPlaybackRate(rate)
        }
        if let volume {
            setPlaybackVolume(volume)
        }
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let maxTime = max(player.duration, 0)
        let clampedTime = min(max(time, 0), maxTime)
        player.currentTime = clampedTime
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func setPlaybackRate(_ rate: Float) {
        guard let player else { return }
        player.enableRate = true
        player.rate = clampedRate(rate)
    }

    func setPlaybackVolume(_ volume: Float) {
        guard let player else { return }
        player.volume = clampedVolume(volume)
    }

    private func clampedRate(_ rate: Float) -> Float {
        min(max(rate, Self.minRate), Self.maxRate)
    }

    private func clampedVolume(_ volume: Float) -> Float {
        min(max(volume, Self.minVolume), Self.maxVolume)
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
