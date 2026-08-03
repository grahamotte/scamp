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

        playback.play(atPlaylistProgress: 0.5)
        playback.seek(toPlaylistProgress: 0.5)
        playback.togglePlayPause()
        playback.playNext()
        playback.playPrevious()

        XCTAssertFalse(playback.isPlaying)
        XCTAssertEqual(playback.playlistProgress, 0)
    }
}
