import Foundation

struct PlaybackTrack: Identifiable, Equatable {
    let url: URL
    let duration: TimeInterval
    let albumTitle: String?

    var id: URL { url }
    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var sortName: String { url.lastPathComponent }

    init(url: URL, duration: TimeInterval = 0, albumTitle: String? = nil) {
        self.url = url
        self.duration = max(duration, 0)
        self.albumTitle = albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
