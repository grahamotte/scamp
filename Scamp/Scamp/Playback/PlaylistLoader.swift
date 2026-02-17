import Foundation
import UniformTypeIdentifiers

struct PlaylistLoader {
    func loadTracks(from folderURL: URL) throws -> [PlaybackTrack] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentTypeKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { url in
                guard
                    let values = try? url.resourceValues(forKeys: keys),
                    values.isRegularFile == true
                else {
                    return false
                }

                if let contentType = values.contentType {
                    return contentType.conforms(to: .audio)
                }

                return false
            }
            .map(PlaybackTrack.init)
            .sorted {
                $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending
            }
    }
}
