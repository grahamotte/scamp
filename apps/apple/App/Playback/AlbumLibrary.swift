import Combine
import Foundation
import UniformTypeIdentifiers

struct LibraryAlbum: Identifiable, Hashable, Sendable {
    let artist: String
    let title: String
    let folderURL: URL
    let artworkURL: URL?
    let filesystemAddedDate: Date

    init(
        artist: String,
        title: String,
        folderURL: URL,
        artworkURL: URL?,
        filesystemAddedDate: Date = .distantPast
    ) {
        self.artist = artist
        self.title = title
        self.folderURL = folderURL
        self.artworkURL = artworkURL
        self.filesystemAddedDate = filesystemAddedDate
    }

    var id: String {
        folderURL.standardizedFileURL.path
    }

    var shelfEasterEgg: AlbumShelfEasterEgg? {
        AlbumShelfEasterEgg.forArtist(artist)
    }
}

enum AlbumShelfEasterEgg: Equatable, Sendable {
    case doubleXTattooSketch
    case sunglassesSketch

    private static let artists: [String: Self] = [
        "capital cities": .sunglassesSketch,
        "machine gun kelly": .doubleXTattooSketch,
        "mgk": .doubleXTattooSketch,
    ]

    static func forArtist(_ artist: String) -> Self? {
        artists[artist.lowercased(with: Locale(identifier: "en_US_POSIX"))]
    }
}

enum AlbumLibrarySort: String, CaseIterable, Identifiable, Sendable {
    case artistThenAlbum
    case album
    case mostPlayed
    case recentlyAdded

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .artistThenAlbum:
            "Artist, Then Album"
        case .album:
            "Album"
        case .mostPlayed:
            "Most Played"
        case .recentlyAdded:
            "Recently Added"
        }
    }
}

struct AlbumLibraryScanner: Sendable {
    func loadAlbums(from musicFolderURL: URL) async throws -> [LibraryAlbum] {
        try await Task.detached(priority: .userInitiated) {
            try loadAlbumsSynchronously(from: musicFolderURL)
        }.value
    }

    private func loadAlbumsSynchronously(from musicFolderURL: URL) throws -> [LibraryAlbum] {
        let artistURLs = try directoryURLs(in: musicFolderURL)
        var albums: [LibraryAlbum] = []

        for artistURL in artistURLs {
            for albumURL in try directoryURLs(in: artistURL) {
                let mediaURLs = try mediaURLs(in: albumURL)
                guard mediaURLs.contains(where: isAudioFile) else { continue }

                albums.append(
                    LibraryAlbum(
                        artist: artistURL.lastPathComponent,
                        title: albumURL.lastPathComponent,
                        folderURL: albumURL,
                        artworkURL: mediaURLs.filter(isImageFile).sorted(by: compareArtwork).first,
                        filesystemAddedDate: filesystemAddedDate(
                            for: albumURL,
                            audioURLs: mediaURLs.filter(isAudioFile)
                        )
                    )
                )
            }
        }

        return albums.sorted { left, right in
            let artistComparison = left.artist.localizedCaseInsensitiveCompare(right.artist)
            if artistComparison != .orderedSame {
                return artistComparison == .orderedAscending
            }
            return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
        }
    }

    private func directoryURLs(in folderURL: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        return try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: keys).isDirectory) == true
        }
        .sorted(by: compareFilenames)
    }

    private func mediaURLs(in folderURL: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentTypeKey]
        return try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: keys).isRegularFile) == true
        }
    }

    private func isAudioFile(_ url: URL) -> Bool {
        contentType(for: url)?.conforms(to: .audio) == true
    }

    private func isImageFile(_ url: URL) -> Bool {
        contentType(for: url)?.conforms(to: .image) == true
    }

    private func contentType(for url: URL) -> UTType? {
        try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
    }

    private func filesystemAddedDate(for albumURL: URL, audioURLs: [URL]) -> Date {
        if let modificationDate = try? albumURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate {
            return modificationDate
        }

        let firstAudioURL = audioURLs.sorted(by: compareFilenames).first
        return firstAudioURL.flatMap {
            try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } ?? .distantPast
    }

    private func compareFilenames(_ left: URL, _ right: URL) -> Bool {
        left.lastPathComponent.localizedCaseInsensitiveCompare(right.lastPathComponent) == .orderedAscending
    }

    private func compareArtwork(_ left: URL, _ right: URL) -> Bool {
        let preferredNames = ["cover", "folder", "front", "album"]
        let leftName = left.deletingPathExtension().lastPathComponent.lowercased()
        let rightName = right.deletingPathExtension().lastPathComponent.lowercased()
        let leftRank = preferredNames.firstIndex(of: leftName) ?? preferredNames.count
        let rightRank = preferredNames.firstIndex(of: rightName) ?? preferredNames.count

        if leftRank != rightRank {
            return leftRank < rightRank
        }
        return compareFilenames(left, right)
    }
}

@MainActor
final class AlbumLibraryController: ObservableObject {
    private static let bookmarkDefaultsKey = "albumLibrary.rootBookmark.v1"
    private static let albumLoadCountsDefaultsKey = "albumLibrary.albumLoadCounts.v1"
    private static let albumAddedDatesDefaultsKey = "albumLibrary.albumAddedDates.v1"
    private static let sortOrderDefaultsKey = "albumLibrary.sortOrder.v1"

    @Published private(set) var albums: [LibraryAlbum] = []
    @Published private(set) var musicFolderURL: URL?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var sortOrder = AlbumLibrarySort.artistThenAlbum

    private let defaults: UserDefaults
    private let scanner: AlbumLibraryScanner
    private let currentDate: () -> Date
    private var albumLoadCounts: [String: Int]
    private var albumAddedDates: [String: Date]
    private var hasAlbumAddedDateHistory: Bool
    private var securityScopedFolderURL: URL?
    private var hasAttemptedRestore = false

    init(
        defaults: UserDefaults = .standard,
        scanner: AlbumLibraryScanner = AlbumLibraryScanner(),
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.scanner = scanner
        self.currentDate = currentDate
        sortOrder = defaults.string(forKey: Self.sortOrderDefaultsKey)
            .flatMap(AlbumLibrarySort.init(rawValue:)) ?? .artistThenAlbum
        albumLoadCounts = defaults.data(forKey: Self.albumLoadCountsDefaultsKey)
            .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
        if
            let data = defaults.data(forKey: Self.albumAddedDatesDefaultsKey),
            let persistedAlbumAddedDates = try? JSONDecoder().decode([String: Date].self, from: data)
        {
            albumAddedDates = persistedAlbumAddedDates
            hasAlbumAddedDateHistory = true
        } else {
            albumAddedDates = [:]
            hasAlbumAddedDateHistory = false
        }
    }

    deinit {
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
    }

    var musicFolderDisplayName: String? {
        musicFolderURL?.lastPathComponent
    }

    func restoreLibraryIfNeeded() async {
        guard !hasAttemptedRestore else { return }
        hasAttemptedRestore = true

        guard let bookmarkData = defaults.data(forKey: Self.bookmarkDefaultsKey) else { return }

        var isStale = false
        guard
            let folderURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        else {
            defaults.removeObject(forKey: Self.bookmarkDefaultsKey)
            return
        }

        await loadLibrary(at: folderURL, persistsBookmark: isStale)
    }

    func refreshLibrary() async {
        if hasAttemptedRestore {
            await reload()
        } else {
            await restoreLibraryIfNeeded()
        }
    }

    func setMusicFolder(_ folderURL: URL) async {
        hasAttemptedRestore = true
        await loadLibrary(at: folderURL, persistsBookmark: true)
    }

    func reload() async {
        guard let musicFolderURL else { return }
        await loadLibrary(at: musicFolderURL, persistsBookmark: false)
    }

    func setSortOrder(_ sortOrder: AlbumLibrarySort) {
        self.sortOrder = sortOrder
        defaults.set(sortOrder.rawValue, forKey: Self.sortOrderDefaultsKey)
        albums.sort(by: compareAlbums)
    }

    func recordAlbumLoad(_ album: LibraryAlbum) {
        albumLoadCounts[album.id, default: 0] += 1
        persistAlbumLoadCounts()

        if sortOrder == .mostPlayed {
            albums.sort(by: compareAlbums)
        }
    }

    func clearLibraryAndStats() {
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        securityScopedFolderURL = nil
        albums = []
        musicFolderURL = nil
        isLoading = false
        errorMessage = nil
        albumLoadCounts = [:]
        albumAddedDates = [:]
        hasAlbumAddedDateHistory = false
        hasAttemptedRestore = true
        defaults.removeObject(forKey: Self.bookmarkDefaultsKey)
        defaults.removeObject(forKey: Self.albumLoadCountsDefaultsKey)
        defaults.removeObject(forKey: Self.albumAddedDatesDefaultsKey)
    }

    func loadLibrary(at folderURL: URL, persistsBookmark: Bool) async {
        hasAttemptedRestore = true
        beginSecurityScopedAccess(for: folderURL)
        musicFolderURL = folderURL
        isLoading = true
        errorMessage = nil

        if persistsBookmark {
            persistBookmark(for: folderURL)
        }

        do {
            albums = try await scanner.loadAlbums(from: folderURL)
            trackAlbumAddedDates()
            albums.sort(by: compareAlbums)
        } catch {
            albums = []
            errorMessage = "Scamp couldn’t read this music folder."
        }

        isLoading = false
    }

    private func compareAlbums(_ left: LibraryAlbum, _ right: LibraryAlbum) -> Bool {
        let firstComparison: ComparisonResult
        let secondComparison: ComparisonResult

        switch sortOrder {
        case .artistThenAlbum:
            firstComparison = left.artist.localizedCaseInsensitiveCompare(right.artist)
            secondComparison = left.title.localizedCaseInsensitiveCompare(right.title)
        case .album:
            firstComparison = left.title.localizedCaseInsensitiveCompare(right.title)
            secondComparison = left.artist.localizedCaseInsensitiveCompare(right.artist)
        case .mostPlayed:
            let leftCount = albumLoadCounts[left.id, default: 0]
            let rightCount = albumLoadCounts[right.id, default: 0]

            if leftCount != rightCount {
                return leftCount > rightCount
            }

            firstComparison = left.title.localizedCaseInsensitiveCompare(right.title)
            secondComparison = left.artist.localizedCaseInsensitiveCompare(right.artist)
        case .recentlyAdded:
            let leftDate = albumAddedDates[left.id] ?? left.filesystemAddedDate
            let rightDate = albumAddedDates[right.id] ?? right.filesystemAddedDate

            if leftDate != rightDate {
                return leftDate > rightDate
            }

            firstComparison = left.title.localizedCaseInsensitiveCompare(right.title)
            secondComparison = left.artist.localizedCaseInsensitiveCompare(right.artist)
        }

        if firstComparison != .orderedSame {
            return firstComparison == .orderedAscending
        }
        return secondComparison == .orderedAscending
    }

    private func persistAlbumLoadCounts() {
        guard let data = try? JSONEncoder().encode(albumLoadCounts) else { return }
        defaults.set(data, forKey: Self.albumLoadCountsDefaultsKey)
    }

    private func trackAlbumAddedDates() {
        let discoveryDate = currentDate()

        for album in albums where albumAddedDates[album.id] == nil {
            albumAddedDates[album.id] = hasAlbumAddedDateHistory
                ? discoveryDate
                : album.filesystemAddedDate
        }

        hasAlbumAddedDateHistory = true
        persistAlbumAddedDates()
    }

    private func persistAlbumAddedDates() {
        guard let data = try? JSONEncoder().encode(albumAddedDates) else { return }
        defaults.set(data, forKey: Self.albumAddedDatesDefaultsKey)
    }

    private func beginSecurityScopedAccess(for folderURL: URL) {
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        securityScopedFolderURL = nil

        if folderURL.startAccessingSecurityScopedResource() {
            securityScopedFolderURL = folderURL
        }
    }

    private func persistBookmark(for folderURL: URL) {
        guard
            let bookmarkData = try? folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        else {
            errorMessage = "Scamp couldn’t remember this music folder."
            return
        }

        defaults.set(bookmarkData, forKey: Self.bookmarkDefaultsKey)
    }
}
