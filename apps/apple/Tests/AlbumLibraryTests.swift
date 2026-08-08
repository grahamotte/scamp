import Foundation
import XCTest
@testable import App

final class AlbumLibraryTests: XCTestCase {
    func testDiscoversAlbumsInArtistAlbumFolders() async throws {
        let root = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        try createFile(at: root.appendingPathComponent("Beta/B-Sides/02.mp3"))
        try createFile(at: root.appendingPathComponent("Beta/B-Sides/front.png"))
        try createFile(at: root.appendingPathComponent("alpha/Zebra/track.mp3"))
        try createFile(at: root.appendingPathComponent("alpha/First/track.m4a"))
        try createFile(at: root.appendingPathComponent("alpha/First/back.jpg"))
        try createFile(at: root.appendingPathComponent("alpha/First/cover.jpg"))
        try createFile(at: root.appendingPathComponent("alpha/Notes/readme.txt"))
        try createFile(at: root.appendingPathComponent("Loose Song.mp3"))

        let albums = try await AlbumLibraryScanner().loadAlbums(from: root)

        XCTAssertEqual(albums.map(\.artist), ["alpha", "alpha", "Beta"])
        XCTAssertEqual(albums.map(\.title), ["First", "Zebra", "B-Sides"])
        XCTAssertEqual(albums.map { $0.artworkURL?.lastPathComponent }, ["cover.jpg", nil, "front.png"])
        XCTAssertEqual(Set(albums.map(\.id)).count, 3)
    }

    @MainActor
    func testControllerLoadsAndReloadsLibrary() async throws {
        let root = temporaryFolder()
        let defaultsName = "AlbumLibraryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }

        try createFile(at: root.appendingPathComponent("Artist/First/track.mp3"))
        let library = AlbumLibraryController(defaults: defaults)

        XCTAssertNil(library.musicFolderURL)
        XCTAssertNil(library.musicFolderDisplayName)
        XCTAssertEqual(library.albums, [])
        XCTAssertFalse(library.isLoading)
        XCTAssertEqual(library.sortOrder, .artistThenAlbum)

        await library.loadLibrary(at: root, persistsBookmark: false)

        XCTAssertEqual(library.musicFolderURL, root)
        XCTAssertEqual(library.musicFolderDisplayName, root.lastPathComponent)
        XCTAssertEqual(library.albums.map(\.title), ["First"])
        XCTAssertNil(library.errorMessage)

        try createFile(at: root.appendingPathComponent("Artist/Second/track.mp3"))
        await library.refreshLibrary()

        XCTAssertEqual(library.albums.map(\.title), ["First", "Second"])
    }

    @MainActor
    func testControllerSortsAlbumsBySelectedOrder() async throws {
        let root = temporaryFolder()
        let defaultsName = "AlbumLibraryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }

        try createFile(at: root.appendingPathComponent("Beta/Alpha/track.mp3"))
        try createFile(at: root.appendingPathComponent("Alpha/Zebra/track.mp3"))
        try createFile(at: root.appendingPathComponent("Alpha/Bravo/track.mp3"))
        let library = AlbumLibraryController(defaults: defaults)

        await library.loadLibrary(at: root, persistsBookmark: false)

        XCTAssertEqual(library.albums.map(\.artist), ["Alpha", "Alpha", "Beta"])
        XCTAssertEqual(library.albums.map(\.title), ["Bravo", "Zebra", "Alpha"])

        library.setSortOrder(.album)

        XCTAssertEqual(library.sortOrder, .album)
        XCTAssertEqual(library.albums.map(\.artist), ["Beta", "Alpha", "Alpha"])
        XCTAssertEqual(library.albums.map(\.title), ["Alpha", "Bravo", "Zebra"])
    }

    @MainActor
    func testControllerSortsMostPlayedAlbumsAndPersistsLoadCounts() async throws {
        let root = temporaryFolder()
        let defaultsName = "AlbumLibraryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }

        try createFile(at: root.appendingPathComponent("Beta/Alpha/track.mp3"))
        try createFile(at: root.appendingPathComponent("Alpha/Zebra/track.mp3"))
        try createFile(at: root.appendingPathComponent("Alpha/Bravo/track.mp3"))
        let library = AlbumLibraryController(defaults: defaults)

        await library.loadLibrary(at: root, persistsBookmark: false)
        library.setSortOrder(.mostPlayed)

        XCTAssertEqual(library.albums.map(\.title), ["Alpha", "Bravo", "Zebra"])

        let alpha = try XCTUnwrap(library.albums.first { $0.title == "Alpha" })
        let bravo = try XCTUnwrap(library.albums.first { $0.title == "Bravo" })
        let zebra = try XCTUnwrap(library.albums.first { $0.title == "Zebra" })
        library.recordAlbumLoad(zebra)
        library.recordAlbumLoad(alpha)
        library.recordAlbumLoad(zebra)
        library.recordAlbumLoad(bravo)

        XCTAssertEqual(library.albums.map(\.title), ["Zebra", "Alpha", "Bravo"])

        let restoredLibrary = AlbumLibraryController(defaults: defaults)
        await restoredLibrary.loadLibrary(at: root, persistsBookmark: false)
        restoredLibrary.setSortOrder(.mostPlayed)

        XCTAssertEqual(restoredLibrary.albums.map(\.title), ["Zebra", "Alpha", "Bravo"])
    }

    @MainActor
    func testControllerClearsLibraryBookmarkAndLoadCounts() async throws {
        let root = temporaryFolder()
        let defaultsName = "AlbumLibraryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }

        try createFile(at: root.appendingPathComponent("Artist/Alpha/track.mp3"))
        try createFile(at: root.appendingPathComponent("Artist/Bravo/track.mp3"))
        let library = AlbumLibraryController(defaults: defaults)

        await library.loadLibrary(at: root, persistsBookmark: false)
        let bravo = try XCTUnwrap(library.albums.first { $0.title == "Bravo" })
        library.recordAlbumLoad(bravo)
        defaults.set(Data([0]), forKey: "albumLibrary.rootBookmark.v1")

        library.clearLibraryAndStats()

        XCTAssertEqual(library.albums, [])
        XCTAssertNil(library.musicFolderURL)
        XCTAssertNil(library.musicFolderDisplayName)
        XCTAssertFalse(library.isLoading)
        XCTAssertNil(library.errorMessage)
        XCTAssertNil(defaults.data(forKey: "albumLibrary.rootBookmark.v1"))
        XCTAssertNil(defaults.data(forKey: "albumLibrary.albumLoadCounts.v1"))

        let restoredLibrary = AlbumLibraryController(defaults: defaults)
        await restoredLibrary.loadLibrary(at: root, persistsBookmark: false)
        restoredLibrary.setSortOrder(.mostPlayed)

        XCTAssertEqual(restoredLibrary.albums.map(\.title), ["Alpha", "Bravo"])
    }

    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func createFile(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: url)
    }
}
