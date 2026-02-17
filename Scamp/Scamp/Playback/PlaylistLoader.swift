import AVFoundation
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
            .map { url in
                PlaybackTrack(url: url, duration: durationSeconds(for: url))
            }
            .sorted {
                $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending
            }
    }

    func loadFirstArtworkURL(from folderURL: URL) throws -> URL? {
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
                    return contentType.conforms(to: .image)
                }

                return false
            }
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
            .first
    }

    private func durationSeconds(for url: URL) -> TimeInterval {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            // Fall back to equal-width segments if metadata duration is unavailable.
            return 1
        }

        let duration = player.duration
        guard duration.isFinite, duration > 0 else {
            return 1
        }

        return duration
    }
}
