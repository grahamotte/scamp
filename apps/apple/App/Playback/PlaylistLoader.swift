import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct PlaylistLoader {
    func loadTracks(from folderURL: URL) async throws -> [PlaybackTrack] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentTypeKey]
        let fallbackAlbumTitle = folderURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        var tracks: [PlaybackTrack] = []

        for url in urls {
            guard
                let values = try? url.resourceValues(forKeys: keys),
                values.isRegularFile == true,
                let contentType = values.contentType,
                contentType.conforms(to: .audio)
            else {
                continue
            }

            tracks.append(
                PlaybackTrack(
                    url: url,
                    duration: durationSeconds(for: url),
                    albumTitle: await albumTitle(for: url) ?? fallbackAlbumTitle
                )
            )
        }

        return tracks.sorted {
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
            return 1
        }

        let duration = player.duration
        guard duration.isFinite, duration > 0 else {
            return 1
        }

        return duration
    }

    private func albumTitle(for url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else {
            return nil
        }

        let albumItems = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierAlbumName
        )

        guard
            let albumItem = albumItems.first,
            let albumTitle = try? await albumItem.load(.stringValue)
        else {
            return nil
        }

        return albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
