import Foundation

struct PlaybackTrack: Identifiable, Equatable {
    let url: URL
    let duration: TimeInterval

    var id: URL { url }
    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var sortName: String { url.lastPathComponent }

    init(url: URL, duration: TimeInterval = 0) {
        self.url = url
        self.duration = max(duration, 0)
    }
}
