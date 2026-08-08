import XCTest
@testable import App

@MainActor
final class PlaybackControllerTests: XCTestCase {
    func testEmptyState() {
        let playback = PlaybackController()

        XCTAssertFalse(playback.hasPlaylist)
        XCTAssertFalse(playback.canPlayPrevious)
        XCTAssertFalse(playback.canPlayNext)
        XCTAssertNil(playback.currentTrackDisplayName)
        XCTAssertEqual(playback.trackDurations, [])
        XCTAssertEqual(playback.recordRotationDegrees(), 0)
        XCTAssertNil(playback.currentAlbumFolderURL)

        playback.play(atPlaylistProgress: 0.5)
        playback.seek(toPlaylistProgress: 0.5)
        playback.togglePlayPause()
        playback.playNext()
        playback.playPrevious()

        XCTAssertFalse(playback.isPlaying)
        XCTAssertEqual(playback.playlistProgress, 0)
    }

    func testLoadAlbumSelectsAlbumImmediately() {
        let playback = PlaybackController()
        let albumFolderURL = URL(fileURLWithPath: "/tmp/album", isDirectory: true)

        playback.loadAlbum(from: albumFolderURL)

        XCTAssertEqual(playback.currentAlbumFolderURL, albumFolderURL)
    }
}
