import Foundation

struct PlaybackTrack: Identifiable, Equatable {
    let url: URL

    var id: URL { url }
    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var sortName: String { url.lastPathComponent }
}
