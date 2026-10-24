import XCTest
import EventKit
import MusicKit
import SwiftUI
import AVKit
@testable import HomePad

final class RealMediaStoreTests: XCTestCase {
    func testUnknownSourcePlayerBackReachesAlbumCardsWithoutQueueCycle() {
        var navigation = MusicNavigationState()
        navigation.show(.queue)
        navigation.back()
        XCTAssertEqual(navigation.screen, .player)
        navigation.returnToAlbumBrowser(nil, currentSongID: nil)
        XCTAssertEqual(navigation.path, [.albums], "Player back must always offer selectable album cards, including an unknown or empty native source")
        XCTAssertEqual(navigation.screen, .albums)
    }

    func testPlayerReturnUsesPlayingAlbumFocusWithoutOpeningDetailsOrQueue() {
        let sources: [MusicPlaybackSource?] = [.album(MusicItemID("playing-a")),
                                              .playlist(MusicItemID("playing-list")),
                                              .library, .search("old query"), nil]
        for source in sources {
            var navigation = MusicNavigationState()
            navigation.albumID = MusicItemID("browsed-b")
            navigation.show(.albums); navigation.show(.tracks); navigation.show(.player)
            navigation.returnToAlbumBrowser(source, currentSongID: MusicItemID("current-song"))
            XCTAssertEqual(navigation.path, [.albums], "Every source returns to selectable album cards")
            XCTAssertEqual(navigation.screen, .albums)
            XCTAssertEqual(navigation.albumID, source == .album(MusicItemID("playing-a")) ? MusicItemID("playing-a") : MusicItemID("browsed-b"))
            XCTAssertEqual(navigation.songID, MusicItemID("current-song"))
            for _ in 0..<2 {
                navigation.show(.player); navigation.show(.queue); navigation.back()
                XCTAssertEqual(navigation.screen, .player)
                navigation.returnToAlbumBrowser(source, currentSongID: MusicItemID("current-song"))
                XCTAssertEqual(navigation.path, [.albums], "Queue -> player -> back must have a permanent album-browser exit")
            }
            navigation.reset()
            XCTAssertNil(navigation.albumID); XCTAssertNil(navigation.songID)
            XCTAssertEqual(navigation.screen, .player)
        }
    }

    @MainActor func testConfirmedPlaybackSourceSurvivesBrowsingSkipsShuffleAndAirPlayButNotBackground() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let songs = try (0..<3).map { try syntheticSong(id: "source-\($0)") }
        let first = try syntheticAlbum(id: "a", title: "Playing album")
        let other = try syntheticAlbum(id: "b", title: "Only browsed")
        let client = TestMusicClient(); client.libraryResults = songs; client.albumResults = [first, other]
        client.trackResults[first.id] = songs; client.trackResults[other.id] = []
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.playAlbum(first); await drainTasks()
        XCTAssertEqual(music.playbackSource, .album(first.id))
        music.selectAlbum(other); await drainTasks()
        XCTAssertEqual(music.selectedAlbum?.id, other.id)
        XCTAssertEqual(music.playbackSource, .album(first.id))
        music.skipNext(); await drainTasks(); XCTAssertEqual(music.playbackSource, .album(first.id))
        music.shuffleQueue(); await drainTasks(); XCTAssertEqual(music.playbackSource, .album(first.id))
        music.setScenePhase(.inactive, routePickerPresented: true)
        XCTAssertEqual(music.playbackSource, .album(first.id))
        music.setScenePhase(.background, routePickerPresented: true)
        XCTAssertNil(music.playbackSource)
    }

    @MainActor func testSuccessfulCollectionSourceSurvivesPlaybackFinishingDuringDetachedRefresh() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticSong(id: "a"), other = try syntheticSong(id: "b")
        let client = TestMusicClient(); client.libraryResults = [first, other]
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.playCollection([first], source: .album(MusicItemID("a-album"))); await drainTasks()
        XCTAssertEqual(music.playbackSource, .album(MusicItemID("a-album")))
        client.delayPlayback = true
        music.playCollection([other], source: .playlist(MusicItemID("b-list"))); await drainTasks()
        let pending = try XCTUnwrap(client.pendingPlaybackIDs.first)
        client.delayLibrary = true
        music.refresh(); await drainTasks()
        XCTAssertNil(client.update, "Refresh deliberately detaches native playback observation")
        client.finishPlayback(pending); await drainTasks()
        XCTAssertFalse(music.playingRequest)
        client.libraryContinuation?.resume(returning: [first, other]); client.libraryContinuation = nil
        await drainTasks()
        XCTAssertEqual(music.state, .ready)
        client.publishCurrentPlayback()
        XCTAssertEqual(music.nowPlaying?.id, other.id)
        XCTAssertEqual(music.playbackSource, .playlist(MusicItemID("b-list")),
                       "The successful request must not fingerprint stale A readback during refresh")
    }

    @MainActor func testFailedOrLateReplacementCannotMislabelActualQueueWithOldPlaybackSource() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticSong(id: "a"), other = try syntheticSong(id: "b")
        let client = TestMusicClient(); client.libraryResults = [first, other]
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.play(first, from: [first], catalog: false, source: .album(MusicItemID("album-a"))); await drainTasks()
        XCTAssertEqual(music.playbackSource, .album(MusicItemID("album-a")))
        client.delayPlayback = true
        music.play(other, from: [other], catalog: false, source: .playlist(MusicItemID("list-b"))); await drainTasks()
        let failed = try XCTUnwrap(client.pendingPlaybackIDs.first)
        client.finishPlayback(failed, error: NSError(domain: "test", code: 1)); await drainTasks()
        XCTAssertNil(music.playbackSource, "The new native queue must not be labeled as album A after start failed")
        music.play(other, from: [other], catalog: false, source: .playlist(MusicItemID("list-b"))); await drainTasks()
        let late = try XCTUnwrap(client.pendingPlaybackIDs.first)
        music.pause()
        client.finishPlayback(late); await drainTasks()
        XCTAssertNil(music.playbackSource, "A cancelled completion cannot confirm a new source")
        client.delayPlayback = false
        music.play(other, from: [other], catalog: false, source: .library); await drainTasks()
        XCTAssertEqual(music.playbackSource, .library)
        client.authorization = .denied; client.update?(music.nowPlaying)
        XCTAssertNil(music.playbackSource)
    }

    @MainActor func testLibraryPaginationLoadsBeyondFirstHundredAndHandlesShortServicePages() async throws {
        let source = Array(0..<237)
        var offsets: [Int] = []
        let loaded = try await MusicLibraryPagination.loadAll { offset, limit in
            offsets.append(offset)
            return Array(source.dropFirst(offset).prefix(min(limit, 40)))
        }
        XCTAssertEqual(loaded, source)
        XCTAssertEqual(offsets, [0, 40, 80, 120, 160, 200, 237])
    }

    @MainActor func testLibraryPaginationDiscardsCancelledNonCooperativePageBeforeFetchingAnother() async throws {
        var continuation: CheckedContinuation<[Int], Never>?
        var offsets: [Int] = []
        let request = Task { @MainActor in
            try await MusicLibraryPagination.loadAll { offset, _ in
                offsets.append(offset)
                return await withCheckedContinuation { continuation = $0 }
            }
        }
        await drainTasks()
        request.cancel()
        continuation?.resume(returning: [1, 2, 3]); continuation = nil
        do { _ = try await request.value; XCTFail("A cancelled page must not complete a library load") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(offsets, [0])
    }

    @MainActor func testExistingSongSelectionAlreadyEnqueuesWholeSourceInOrder() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let songs = try (0..<3).map { try syntheticSong(id: "source-\($0)") }
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.play(songs[1], from: songs, catalog: false); await drainTasks()
        XCTAssertEqual(music.queue.compactMap(\.songID), songs.map(\.id), "The original song action was not a one-song queue")
        XCTAssertEqual(music.queue.first(where: \.isCurrent)?.songID, songs[1].id)
        XCTAssertEqual(client.playCalls, 1)
    }

    @MainActor func testWholeLibraryPlaybackAndShufflePreserveEverySongAndPauseKeepsOrder() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let songs = try (0..<4).map { try syntheticSong(id: "library-\($0)") }
        let client = TestMusicClient(); client.libraryResults = songs
        let music = MusicStore(client: client, defaults: defaults, shuffleSongs: { Array($0.reversed()) })
        music.connect(); await drainTasks()
        music.playLibrary(); await drainTasks()
        XCTAssertEqual(music.queue.compactMap(\.songID), songs.map(\.id))
        XCTAssertEqual(music.nowPlaying?.id, songs[0].id)
        XCTAssertFalse(music.queueIsShuffled)
        music.playLibrary(shuffle: true); await drainTasks()
        XCTAssertEqual(music.queue.compactMap(\.songID), songs.reversed().map(\.id))
        XCTAssertEqual(music.nowPlaying?.id, songs.last?.id)
        XCTAssertTrue(music.queueIsShuffled)
        music.pause(); music.togglePlayback(); await drainTasks()
        XCTAssertTrue(music.queueIsShuffled)
        XCTAssertEqual(music.queue.count, songs.count)
        music.play(songs[1], from: songs, catalog: false); await drainTasks()
        XCTAssertFalse(music.queueIsShuffled)
        XCTAssertEqual(music.queue.compactMap(\.songID), songs.map(\.id))
    }

    @MainActor func testPlaylistBrowsingDoesNotPlayAndWholePlaylistKeepsRepeatedSongs() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let playlist = try syntheticPlaylist(id: "playlist", title: "Fixture playlist")
        let first = try syntheticSong(id: "first"), second = try syntheticSong(id: "second")
        let songs = [first, second, first]
        let client = TestMusicClient(); client.playlistResults = [playlist]; client.playlistTrackResults[playlist.id] = songs
        let music = MusicStore(client: client, defaults: defaults, shuffleSongs: { Array($0.reversed()) })
        music.connect(); await drainTasks()
        XCTAssertEqual(music.playlists.map(\.id), [playlist.id])
        music.selectPlaylist(playlist); await drainTasks()
        XCTAssertEqual(music.playlistTracks.map(\.id), songs.map(\.id))
        XCTAssertEqual(client.playCalls, 0)
        music.playPlaylist(playlist); await drainTasks()
        XCTAssertEqual(music.queue.compactMap(\.songID), [first.id, second.id, first.id])
        XCTAssertEqual(Set(music.queue.map(\.id)).count, 3, "Repeated songs need distinct queue entries")
        music.play(first, from: songs, catalog: false, startingIndex: 2); await drainTasks()
        XCTAssertEqual(music.queue.first(where: \.isCurrent)?.id, "entry-2", "Choosing a repeated song must use that occurrence")
        music.playPlaylist(playlist, shuffle: true); await drainTasks()
        XCTAssertTrue(music.queueIsShuffled)
        XCTAssertEqual(music.queue.count, 3)
        XCTAssertEqual(music.queue.filter { $0.songID == first.id }.count, 2)
    }

    @MainActor func testWholeAlbumLoadsAllTracksWithoutChangingBrowsingAndCanShuffleLoadedAlbum() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let album = try syntheticAlbum(id: "whole-album", title: "Whole album")
        let songs = try (0..<5).map { try syntheticSong(id: "album-track-\($0)") }
        let client = TestMusicClient(); client.trackResults[album.id] = songs
        let music = MusicStore(client: client, defaults: defaults, shuffleSongs: { Array($0.reversed()) })
        music.connect(); await drainTasks()
        music.playAlbum(album); await drainTasks()
        XCTAssertNil(music.selectedAlbum, "Whole-album playback must not replace the user's browsing selection")
        XCTAssertEqual(music.queue.compactMap(\.songID), songs.map(\.id))
        XCTAssertEqual(music.nowPlaying?.id, songs[0].id)
        music.selectAlbum(album); await drainTasks()
        music.playAlbum(album, shuffle: true); await drainTasks()
        XCTAssertEqual(music.queue.compactMap(\.songID), songs.reversed().map(\.id))
        XCTAssertTrue(music.queueIsShuffled)
        XCTAssertEqual(music.selectedAlbum?.id, album.id)
    }

    @MainActor func testPlaylistFetchIsCancelledBeforeAssigningPlaybackQueueAndCannotReplaceNewerPlay() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let playlist = try syntheticPlaylist(id: "slow-playlist", title: "Slow fixture")
        let old = try syntheticSong(id: "old"), latest = try syntheticSong(id: "latest")
        let client = TestMusicClient(); client.delayPlaylistTracks = true
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.playPlaylist(playlist, shuffle: true); await drainTasks()
        XCTAssertTrue(music.playingRequest)
        music.pause()
        music.play(latest, from: [latest], catalog: false); await drainTasks()
        client.playlistTrackContinuations.removeValue(forKey: playlist.id)?.resume(returning: [old])
        await drainTasks()
        XCTAssertEqual(client.playCalls, 1, "A cancelled fetch must not even assign its old queue")
        XCTAssertEqual(music.nowPlaying?.id, latest.id)
        XCTAssertTrue(client.actuallyPlaying)
        XCTAssertFalse(music.queueIsShuffled)
        XCTAssertNil(music.message)
    }

    @MainActor func testPlaylistLateBrowseCannotRestoreAfterSelectionChangeOrPrivacyBoundary() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticPlaylist(id: "playlist-first", title: "First")
        let last = try syntheticPlaylist(id: "playlist-last", title: "Last")
        let songs = [try syntheticSong()]
        let client = TestMusicClient(); client.delayPlaylistTracks = true; client.playlistResults = [first, last]
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.selectPlaylist(first); await drainTasks()
        music.selectPlaylist(last); await drainTasks()
        client.playlistTrackContinuations.removeValue(forKey: first.id)?.resume(returning: songs)
        await drainTasks()
        XCTAssertEqual(music.selectedPlaylist?.id, last.id)
        XCTAssertTrue(music.playlistLoading)
        XCTAssertTrue(music.playlistTracks.isEmpty)
        music.setActive(false)
        client.playlistTrackContinuations.removeValue(forKey: last.id)?.resume(returning: songs)
        await drainTasks()
        XCTAssertNil(music.selectedPlaylist)
        XCTAssertTrue(music.playlists.isEmpty)
        XCTAssertTrue(music.playlistTracks.isEmpty)
        XCTAssertFalse(music.playlistLoading)
    }

    @MainActor func testPlaylistListFailureKeepsOtherMediaUsableAndRefreshRecovers() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let song = try syntheticSong()
        let playlist = try syntheticPlaylist(id: "recovered", title: "Recovered")
        let client = TestMusicClient(); client.libraryResults = [song]; client.playlistError = URLError(.notConnectedToInternet)
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        XCTAssertEqual(music.state, .ready)
        XCTAssertNotNil(music.playlistListMessage)
        music.playLibrary(); await drainTasks()
        XCTAssertTrue(client.actuallyPlaying)
        client.playlistError = nil; client.playlistResults = [playlist]
        music.refresh(); await drainTasks()
        XCTAssertNil(music.playlistListMessage)
        XCTAssertEqual(music.playlists.map(\.id), [playlist.id])
    }

    @MainActor func testShuffleCurrentQueueRebuildsAllEntriesAtZeroAndLateStartCannotEscapePause() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let songs = try (0..<3).map { try syntheticSong(id: "queued-\($0)") }
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.play(songs[1], from: songs, catalog: false); await drainTasks()
        music.seek(to: 30)
        XCTAssertTrue(music.canShuffleQueue)
        music.shuffleQueue(); await drainTasks()
        XCTAssertEqual(client.shuffleCalls, 1)
        XCTAssertEqual(music.queue.compactMap(\.songID), songs.reversed().map(\.id))
        XCTAssertEqual(music.nowPlaying?.position, 0)
        XCTAssertTrue(music.queueIsShuffled)
        client.delayPlayback = true
        music.shuffleQueue(); await drainTasks()
        let pending = try XCTUnwrap(client.pendingPlaybackIDs.first)
        music.pause(); client.finishPlayback(pending); await drainTasks()
        XCTAssertFalse(client.actuallyPlaying)
        XCTAssertFalse(music.playingRequest)
        music.disconnect()
        XCTAssertFalse(music.queueIsShuffled)
        XCTAssertFalse(music.canShuffleQueue)
    }

    @MainActor func testEmptyCollectionAndRevokedPlaylistFetchCannotInventOrStartMusic() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let playlist = try syntheticPlaylist(id: "private", title: "Private")
        let client = TestMusicClient(); client.delayPlaylistTracks = true
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.playCollection([]); await drainTasks()
        XCTAssertEqual(client.playCalls, 0)
        XCTAssertEqual(music.message, "This collection has no available songs.")
        music.playPlaylist(playlist); await drainTasks()
        client.authorization = .denied
        client.playlistTrackContinuations.removeValue(forKey: playlist.id)?.resume(returning: [try syntheticSong()])
        await drainTasks()
        XCTAssertEqual(client.playCalls, 0)
        XCTAssertEqual(music.state, .denied)
        XCTAssertTrue(music.queue.isEmpty)
        XCTAssertTrue(music.playlists.isEmpty)
        XCTAssertNil(music.nowPlaying)
    }

    @MainActor func testAirPlayInactivePreservesLibraryAndPlaybackButBackgroundAlwaysClears() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient()
        let song = try syntheticSong()
        let album = try syntheticAlbum(id: "airplay-album", title: "AirPlay fixture album")
        client.libraryResults = [song]; client.albumResults = [album]; client.trackResults[album.id] = [song]
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.selectAlbum(album); await drainTasks()
        music.play(song, from: [song], catalog: false); await drainTasks()
        let libraryRequests = client.libraryRequests
        let pauseCalls = client.pauseCalls
        music.setScenePhase(.inactive, routePickerPresented: true)
        XCTAssertEqual(music.state, .ready)
        XCTAssertEqual(music.selectedAlbum?.id, album.id)
        XCTAssertEqual(music.albumTracks.map(\.id), [song.id])
        XCTAssertTrue(client.actuallyPlaying)
        XCTAssertEqual(client.pauseCalls, pauseCalls)
        music.setScenePhase(.active, routePickerPresented: false); await drainTasks()
        XCTAssertEqual(client.libraryRequests, libraryRequests, "Closing AirPlay must not reconnect the library")
        XCTAssertEqual(music.nowPlaying?.id, song.id)
        music.setScenePhase(.background, routePickerPresented: true)
        XCTAssertTrue(music.library.isEmpty)
        XCTAssertTrue(music.albums.isEmpty)
        XCTAssertNil(music.nowPlaying)
        XCTAssertNil(music.selectedAlbum)
        XCTAssertFalse(client.actuallyPlaying, "A route picker cannot bypass the actual background boundary")
        music.setScenePhase(.active, routePickerPresented: false); await drainTasks()
        XCTAssertEqual(client.libraryRequests, libraryRequests + 1)
        music.setScenePhase(.inactive, routePickerPresented: false)
        XCTAssertNil(music.nowPlaying, "Ordinary inactivity still applies the privacy cleanup")
        XCTAssertTrue(music.library.isEmpty)
    }

    @MainActor func testReturningFromAirPlayRechecksRevokedAuthorizationWithoutPrompting() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient()
        client.libraryResults = [try syntheticSong()]
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        let prompts = client.permissionRequests
        music.setScenePhase(.inactive, routePickerPresented: true)
        client.authorization = .denied
        music.setScenePhase(.active, routePickerPresented: false); await drainTasks()
        XCTAssertEqual(music.state, .denied)
        XCTAssertTrue(music.library.isEmpty)
        XCTAssertTrue(music.albums.isEmpty)
        XCTAssertNil(music.nowPlaying)
        XCTAssertEqual(client.permissionRequests, prompts)
    }

    @MainActor func testAirPlaySystemDelegateTracksPresentationUntilActualDismissal() {
        var events: [Bool] = []
        let delegate = AirPlayPicker.Coordinator { events.append($0) }
        let picker = AVRoutePickerView()
        delegate.routePickerViewWillBeginPresentingRoutes(picker)
        delegate.routePickerViewWillBeginPresentingRoutes(picker)
        XCTAssertTrue(delegate.presented)
        XCTAssertEqual(events, [true])
        delegate.routePickerViewDidEndPresentingRoutes(picker)
        XCTAssertFalse(delegate.presented)
        XCTAssertEqual(events, [true, false])
    }

    @MainActor func testReopeningConnectedMusicPreservesBrowsingWithoutLoadingFlashButStillRechecksPermission() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let song = try syntheticSong()
        let album = try syntheticAlbum(id: "reopen-album", title: "Browsing album")
        let client = TestMusicClient()
        client.libraryResults = [song]; client.albumResults = [album]; client.trackResults[album.id] = [song]
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.selectAlbum(album); await drainTasks()
        music.open(); music.open()
        XCTAssertEqual(music.state, .ready, "A page switch must not replace ready content with a connection card")
        XCTAssertFalse(music.loading)
        XCTAssertEqual(music.selectedAlbum?.id, album.id)
        XCTAssertEqual(music.albumTracks.map(\.id), [song.id])
        await drainTasks()
        XCTAssertEqual(client.libraryRequests, 1)
        XCTAssertEqual(client.albumRequests, 1)
        music.refresh(); await drainTasks()
        XCTAssertEqual(client.libraryRequests, 2, "Explicit refresh still reloads the library")
        client.authorization = .denied
        music.open(); await drainTasks()
        XCTAssertEqual(music.state, .denied)
        XCTAssertTrue(music.library.isEmpty)
        XCTAssertTrue(music.albums.isEmpty)
        XCTAssertNil(music.selectedAlbum)
        XCTAssertEqual(client.permissionRequests, 1, "Passive reopening must never prompt")
    }

    @MainActor func testOpeningMusicDoesNotRequestPermissionOrReadUnconnectedLibrary() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.open(); music.refresh(); music.search("private search")
        await drainTasks()
        XCTAssertEqual(client.permissionRequests, 0)
        XCTAssertEqual(client.subscriptionRequests, 0)
        XCTAssertEqual(client.libraryRequests, 0)
        XCTAssertEqual(client.albumRequests, 0)
        XCTAssertEqual(client.playlistRequests, 0)
        XCTAssertEqual(client.searchRequests, 0)
        XCTAssertEqual(music.state, .disconnected)
        XCTAssertTrue(music.library.isEmpty)
    }

    @MainActor func testMusicDemoNeverRequestsAuthorizationSubscriptionLibraryOrPlayer() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.setDemo(true); music.connect(); music.open(); music.search("song"); music.togglePlayback()
        music.playLibrary(shuffle: true); music.playCollection([], shuffle: true); music.shuffleQueue()
        await drainTasks()
        XCTAssertFalse(music.connected)
        XCTAssertEqual(client.permissionRequests, 0)
        XCTAssertEqual(client.subscriptionRequests, 0)
        XCTAssertEqual(client.libraryRequests, 0)
        XCTAssertEqual(client.albumRequests, 0)
        XCTAssertEqual(client.playlistRequests, 0)
        XCTAssertEqual(client.playbackObservations, 0)
    }

    @MainActor func testDeniedMusicIsRecoverableWithoutLoadingPrivateContent() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.authorization = .denied
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        XCTAssertEqual(music.state, .denied)
        XCTAssertEqual(client.permissionRequests, 1)
        XCTAssertEqual(client.subscriptionRequests, 0)
        XCTAssertTrue(music.library.isEmpty)
        client.authorization = .authorized
        music.setActive(false); music.setActive(true); await drainTasks()
        XCTAssertEqual(music.state, .ready)
        XCTAssertEqual(client.permissionRequests, 1, "Returning from Settings may reuse permission but must not request it again")
        XCTAssertEqual(client.libraryRequests, 1)
    }

    @MainActor func testLateMusicAuthorizationCannotReconnectAfterCancelOrBackground() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.delayAuthorization = true
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        XCTAssertEqual(music.state, .connecting)
        XCTAssertNotNil(client.authorizationContinuation)
        music.disconnect(); music.setActive(false)
        client.authorizationContinuation?.resume(returning: .authorized); client.authorizationContinuation = nil
        await drainTasks()
        XCTAssertEqual(music.state, .disconnected)
        XCTAssertFalse(music.connected)
        XCTAssertEqual(client.subscriptionRequests, 0)
        XCTAssertEqual(client.libraryRequests, 0)
    }

    @MainActor func testMusicAuthorizationPromptInactivityRecoversAfterLateConsentWithoutAnotherPrompt() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.delayAuthorization = true; client.authorization = .notDetermined
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.setActive(false); music.setActive(true); await drainTasks()
        client.authorization = .authorized
        client.authorizationContinuation?.resume(returning: .authorized); client.authorizationContinuation = nil
        await drainTasks()
        XCTAssertEqual(music.state, .ready)
        XCTAssertEqual(client.permissionRequests, 1)
        XCTAssertEqual(client.libraryRequests, 1)
    }

    @MainActor func testLateLibraryResponseAndPlaybackObservationCannotRestoreDisconnectedMusic() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.delayLibrary = true
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        XCTAssertEqual(client.libraryRequests, 1)
        music.disconnect()
        client.libraryContinuation?.resume(returning: []); client.libraryContinuation = nil
        await drainTasks()
        XCTAssertEqual(music.state, .disconnected)
        XCTAssertNil(music.subscription)
        XCTAssertNil(music.nowPlaying)
        XCTAssertEqual(client.playbackObservations, 0)
        XCTAssertFalse(music.loading)
    }

    @MainActor func testMusicBackgroundAndRevocationClearLibrarySubscriptionAndCurrentTrack() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        client.update?(MusicNowPlaying(title: "Private track", artist: "Private artist", artwork: nil, playing: true))
        XCTAssertEqual(music.nowPlaying?.title, "Private track")
        let staleUpdate = client.update
        music.setActive(false)
        staleUpdate?(MusicNowPlaying(title: "Late track", artist: "", artwork: nil, playing: true))
        XCTAssertNil(music.nowPlaying)
        XCTAssertNil(music.subscription)
        XCTAssertTrue(music.library.isEmpty)
        XCTAssertGreaterThan(client.pauseCalls, 0)
        client.authorization = .denied
        music.setActive(true); await drainTasks()
        XCTAssertEqual(music.state, .denied)
        XCTAssertNil(music.nowPlaying)
        XCTAssertEqual(client.permissionRequests, 1)
    }

    @MainActor func testMusicUnavailableUsesActualErrorAndNeverInventsTracks() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.subscriptionError = URLError(.notConnectedToInternet)
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        XCTAssertEqual(music.state, .unavailable)
        XCTAssertNotNil(music.message)
        XCTAssertNotNil(music.detail)
        XCTAssertTrue(music.library.isEmpty)
        XCTAssertTrue(music.results.isEmpty)
        XCTAssertEqual(client.libraryRequests, 0)
        XCTAssertEqual(client.playbackObservations, 0)
    }

    @MainActor func testMusicRevocationDuringSearchClearsPrivatePlaybackAndLoadingState() async {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        client.update?(MusicNowPlaying(title: "Private track", artist: "Private artist", artwork: nil, playing: true))
        client.delaySearch = true; music.search("Private query"); await drainTasks()
        XCTAssertTrue(music.loading)
        client.authorization = .denied
        client.searchContinuation?.resume(returning: []); client.searchContinuation = nil
        await drainTasks()
        XCTAssertEqual(music.state, .denied)
        XCTAssertNil(music.nowPlaying)
        XCTAssertNil(music.subscription)
        XCTAssertFalse(music.loading)
        XCTAssertTrue(music.results.isEmpty)
    }

    @MainActor func testLatePlayCannotRestartAfterSwitchingToLocalAudio() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.delayPlayback = true
        let music = MusicStore(client: client, defaults: defaults)
        let song = try syntheticSong()
        music.connect(); await drainTasks()
        music.play(song, from: [song], catalog: false); await drainTasks()
        let pending = try XCTUnwrap(client.pendingPlaybackIDs.first)
        XCTAssertTrue(music.playingRequest)

        // MusicPage performs this synchronously before AudioStore.load/toggle.
        music.pause()
        XCTAssertFalse(music.playingRequest)
        XCTAssertFalse(client.actuallyPlaying)
        client.finishPlayback(pending); await drainTasks()

        XCTAssertFalse(client.actuallyPlaying, "A non-cooperative MusicKit completion cannot start a second audio source")
        XCTAssertFalse(music.playingRequest)
        XCTAssertFalse(music.nowPlaying?.playing ?? false)
        XCTAssertNil(music.message)
    }

    @MainActor func testLateResumeStaysPausedAfterPauseDisconnectDemoOrBackground() async throws {
        defer { isolatedDefaults().removePersistentDomain(forName: defaultsSuite) }
        let song = try syntheticSong()
        for boundary in PlaybackBoundary.allCases {
            let client = TestMusicClient()
            let music = MusicStore(client: client, defaults: isolatedDefaults())
            music.connect(); await drainTasks()
            music.play(song, from: [song], catalog: false); await drainTasks()
            music.pause(); client.delayPlayback = true
            music.togglePlayback(); await drainTasks()
            let old = try XCTUnwrap(client.pendingPlaybackIDs.first)
            switch boundary {
            case .pause: music.pause()
            case .disconnect: music.disconnect()
            case .demo: music.setDemo(true)
            case .background: music.setActive(false)
            }
            XCTAssertFalse(music.playingRequest, boundary.rawValue)
            client.finishPlayback(old); await drainTasks()
            XCTAssertFalse(client.actuallyPlaying, boundary.rawValue)
            XCTAssertFalse(music.playingRequest, boundary.rawValue)
            XCTAssertNil(music.message, boundary.rawValue)
            if boundary != .pause { XCTAssertNil(music.nowPlaying, boundary.rawValue) }
        }
    }

    @MainActor func testOldResumeCannotPauseNewerPlayAfterAnyPlaybackBoundary() async throws {
        defer { isolatedDefaults().removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticSong(id: "synthetic-first", title: "First synthetic tone")
        let latest = try syntheticSong(id: "synthetic-latest", title: "Latest synthetic tone")
        for boundary in PlaybackBoundary.allCases {
            let client = TestMusicClient()
            let music = MusicStore(client: client, defaults: isolatedDefaults())
            music.connect(); await drainTasks()
            music.play(first, from: [first], catalog: false); await drainTasks()
            music.pause(); client.delayPlayback = true
            music.togglePlayback(); await drainTasks()
            let old = try XCTUnwrap(client.pendingPlaybackIDs.first)
            await crossBoundaryAndReconnect(boundary, music: music)
            music.play(latest, from: [latest], catalog: false); await drainTasks()
            let newer = try XCTUnwrap(client.pendingPlaybackIDs.first(where: { $0 != old }))
            client.finishPlayback(newer); await drainTasks()
            XCTAssertTrue(client.actuallyPlaying, boundary.rawValue)
            XCTAssertEqual(music.nowPlaying?.title, latest.title, boundary.rawValue)
            let pausesBeforeOldCompletion = client.pauseCalls

            client.finishPlayback(old); await drainTasks()

            XCTAssertTrue(client.actuallyPlaying, "Old resume must not pause newer Play: \(boundary.rawValue)")
            XCTAssertEqual(client.pauseCalls, pausesBeforeOldCompletion, boundary.rawValue)
            XCTAssertEqual(music.nowPlaying?.title, latest.title, boundary.rawValue)
            XCTAssertFalse(music.playingRequest, boundary.rawValue)
            XCTAssertNil(music.message, boundary.rawValue)
        }
    }

    @MainActor func testOldPlaybackFailureCannotClearNewerBusyStateOrPublishItsError() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.delayPlayback = true
        let music = MusicStore(client: client, defaults: defaults)
        let song = try syntheticSong()
        music.connect(); await drainTasks()
        music.play(song, from: [song], catalog: false); await drainTasks()
        let old = try XCTUnwrap(client.pendingPlaybackIDs.first)
        music.pause()
        music.play(song, from: [song], catalog: false); await drainTasks()
        let newer = try XCTUnwrap(client.pendingPlaybackIDs.first(where: { $0 != old }))
        let pausesBeforeOldCompletion = client.pauseCalls

        client.finishPlayback(old, error: URLError(.cancelled)); await drainTasks()

        XCTAssertTrue(music.playingRequest)
        XCTAssertEqual(client.pauseCalls, pausesBeforeOldCompletion)
        XCTAssertNil(music.message)
        XCTAssertNil(music.detail)
        client.finishPlayback(newer); await drainTasks()
        XCTAssertFalse(music.playingRequest)
        XCTAssertTrue(client.actuallyPlaying)
    }

    @MainActor func testRefreshingLibraryDoesNotReplacePendingPlaybackIntent() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient(); client.delayPlayback = true
        let music = MusicStore(client: client, defaults: defaults)
        let song = try syntheticSong()
        music.connect(); await drainTasks()
        music.play(song, from: [song], catalog: false); await drainTasks()
        let pending = try XCTUnwrap(client.pendingPlaybackIDs.first)
        let pauses = client.pauseCalls
        music.refresh(); await drainTasks()
        XCTAssertTrue(music.playingRequest)
        client.finishPlayback(pending); await drainTasks()
        XCTAssertTrue(client.actuallyPlaying)
        XCTAssertFalse(music.playingRequest)
        XCTAssertEqual(client.pauseCalls, pauses)
    }

    @MainActor func testAlbumBrowsingUsesRealClientResultsWithoutChangingQueueOrPlayback() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticAlbum(id: "first-album", title: "First album")
        let second = try syntheticAlbum(id: "second-album", title: "Second album")
        let original = try syntheticSong(id: "original")
        let browsed = try syntheticSong(id: "browsed")
        let client = TestMusicClient(); client.albumResults = [first, second]
        client.trackResults[second.id] = [browsed]
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.play(original, from: [original], catalog: false); await drainTasks()
        let queueBefore = music.queue.map(\.songID)
        music.selectAlbum(second); await drainTasks()
        XCTAssertEqual(music.albums.map(\.id), [first.id, second.id])
        XCTAssertEqual(music.selectedAlbum?.id, second.id)
        XCTAssertEqual(music.albumTracks.map(\.id), [browsed.id])
        XCTAssertEqual(music.nowPlaying?.id, original.id)
        XCTAssertEqual(music.queue.map(\.songID), queueBefore)
        XCTAssertEqual(client.playCalls, 1)
        XCTAssertTrue(client.actuallyPlaying)
    }

    @MainActor func testAlbumListFailureKeepsLibrarySearchAndPlaybackUsableAndRefreshRecovers() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let song = try syntheticSong()
        let album = try syntheticAlbum(id: "recovered-album", title: "Recovered album")
        let client = TestMusicClient(); client.libraryResults = [song]
        client.albumError = URLError(.notConnectedToInternet)
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        XCTAssertEqual(music.state, .ready)
        XCTAssertEqual(music.library.map(\.id), [song.id])
        XCTAssertNotNil(music.subscription)
        XCTAssertTrue(music.albums.isEmpty)
        XCTAssertNotNil(music.albumListMessage)
        XCTAssertNil(music.message)
        music.search("Available search"); await drainTasks()
        XCTAssertEqual(client.searchRequests, 1)
        music.play(song, from: music.library, catalog: false); await drainTasks()
        XCTAssertTrue(client.actuallyPlaying)
        XCTAssertEqual(music.nowPlaying?.id, song.id)

        client.albumError = nil; client.albumResults = [album]
        music.refresh(); await drainTasks()
        XCTAssertEqual(music.state, .ready)
        XCTAssertEqual(music.albums.map(\.id), [album.id])
        XCTAssertNil(music.albumListMessage)
        client.albumError = URLError(.notConnectedToInternet)
        music.refresh(); await drainTasks()
        XCTAssertNotNil(music.albumListMessage)
        music.disconnect()
        XCTAssertNil(music.albumListMessage)
    }

    @MainActor func testLateAlbumCannotReplaceNewSelectionOrRestoreAfterBackground() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticAlbum(id: "first-album", title: "First album")
        let second = try syntheticAlbum(id: "second-album", title: "Second album")
        let firstSong = try syntheticSong(id: "first-song")
        let secondSong = try syntheticSong(id: "second-song")
        let client = TestMusicClient(); client.delayTracks = true
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.selectAlbum(first); await drainTasks()
        music.selectAlbum(second); await drainTasks()
        client.trackContinuations.removeValue(forKey: first.id)?.resume(returning: [firstSong])
        await drainTasks()
        XCTAssertEqual(music.selectedAlbum?.id, second.id)
        XCTAssertTrue(music.albumLoading)
        XCTAssertTrue(music.albumTracks.isEmpty)
        music.setActive(false)
        client.trackContinuations.removeValue(forKey: second.id)?.resume(returning: [secondSong])
        await drainTasks()
        XCTAssertNil(music.selectedAlbum)
        XCTAssertTrue(music.albums.isEmpty)
        XCTAssertTrue(music.albumTracks.isEmpty)
        XCTAssertFalse(music.albumLoading)
        XCTAssertNil(music.albumMessage)
    }

    @MainActor func testAlbumRevocationClearsAllPrivateCollectionsAndStopsObservation() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let album = try syntheticAlbum(id: "private-album", title: "Private album")
        let client = TestMusicClient(); client.albumResults = [album]; client.delayTracks = true
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.selectAlbum(album); await drainTasks()
        client.authorization = .denied
        client.trackContinuations.removeValue(forKey: album.id)?.resume(returning: [try syntheticSong()])
        await drainTasks()
        XCTAssertEqual(music.state, .denied)
        XCTAssertTrue(music.albums.isEmpty)
        XCTAssertTrue(music.albumTracks.isEmpty)
        XCTAssertNil(music.selectedAlbum)
        XCTAssertNil(client.update)
        XCTAssertTrue(music.queue.isEmpty)
    }

    @MainActor func testClosingAlbumRejectsLateSongsWithoutInterruptingCurrentQueue() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let album = try syntheticAlbum(id: "closed-album", title: "Closed album")
        let song = try syntheticSong()
        let client = TestMusicClient(); client.delayTracks = true
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.play(song, from: [song], catalog: false); await drainTasks()
        music.selectAlbum(album); await drainTasks()
        music.closeAlbum()
        client.trackContinuations.removeValue(forKey: album.id)?.resume(returning: [song])
        await drainTasks()
        XCTAssertNil(music.selectedAlbum)
        XCTAssertTrue(music.albumTracks.isEmpty)
        XCTAssertFalse(music.albumLoading)
        XCTAssertEqual(music.nowPlaying?.id, song.id)
        XCTAssertTrue(client.actuallyPlaying)
    }

    @MainActor func testSeekUsesClampedClientReadbackAndRejectsUnknownDurationAndInvalidNumbers() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        let song = try syntheticSong()
        music.connect(); await drainTasks()
        music.play(song, from: [song], catalog: false); await drainTasks()
        XCTAssertTrue(music.canSeek)
        music.seek(to: -20)
        music.seek(to: 900)
        music.seek(to: .infinity)
        music.seek(to: .nan)
        XCTAssertEqual(client.seekPositions, [0, song.duration!])
        XCTAssertEqual(music.nowPlaying?.position, song.duration)
        client.update?(MusicNowPlaying(title: "Unknown duration", artist: "", artwork: nil, playing: false))
        XCTAssertFalse(music.canSeek)
        music.seek(to: 5)
        XCTAssertEqual(client.seekPositions.count, 2)
        music.disconnect(); music.seek(to: 2)
        XCTAssertEqual(client.seekPositions.count, 2)
    }

    @MainActor func testQueueSkipBoundariesPreservePauseAndPreviousRestartsActualCurrentSong() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticSong(id: "first")
        let last = try syntheticSong(id: "last")
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.play(first, from: [first, last], catalog: false); await drainTasks()
        XCTAssertFalse(music.canSkipPrevious)
        music.skipPrevious(); await drainTasks()
        XCTAssertEqual(client.previousCalls, 0)
        XCTAssertTrue(music.canSkipNext)
        music.pause(); music.skipNext(); await drainTasks()
        XCTAssertEqual(music.nowPlaying?.id, last.id)
        XCTAssertFalse(music.nowPlaying?.playing ?? true)
        XCTAssertFalse(client.actuallyPlaying)
        XCTAssertFalse(music.canSkipNext)
        music.skipNext(); await drainTasks()
        XCTAssertEqual(client.nextCalls, 1)
        music.seek(to: 20)
        music.skipPrevious(); await drainTasks()
        XCTAssertEqual(music.nowPlaying?.id, last.id)
        XCTAssertEqual(music.nowPlaying?.position, 0)
        XCTAssertEqual(client.previousCalls, 0)
        music.skipPrevious(); await drainTasks()
        XCTAssertEqual(music.nowPlaying?.id, first.id)
        XCTAssertEqual(client.previousCalls, 1)
        XCTAssertFalse(client.actuallyPlaying)
    }

    @MainActor func testQueueSelectionUsesExistingQueueAndLateSkipCannotResumeAfterBackground() async throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let first = try syntheticSong(id: "first")
        let last = try syntheticSong(id: "last")
        let client = TestMusicClient()
        let music = MusicStore(client: client, defaults: defaults)
        music.connect(); await drainTasks()
        music.play(first, from: [first, last], catalog: false); await drainTasks()
        let lastEntry = try XCTUnwrap(music.queue.last)
        music.playQueueEntry(lastEntry); await drainTasks()
        XCTAssertEqual(music.nowPlaying?.id, last.id)
        XCTAssertEqual(music.queue.map(\.songID), [first.id, last.id])
        XCTAssertEqual(client.playCalls, 1, "Choosing an existing queue entry must not replace the queue")
        client.delayPlayback = true
        music.skipPrevious(); await drainTasks()
        let pending = try XCTUnwrap(client.pendingPlaybackIDs.first)
        music.setActive(false)
        client.finishPlayback(pending); await drainTasks()
        XCTAssertFalse(client.actuallyPlaying)
        XCTAssertNil(music.nowPlaying)
        XCTAssertTrue(music.queue.isEmpty)
    }

    @MainActor func testCalendarOnlyConnectPromptsAndReadsSevenDayWindow() async {
        let client = TestAgendaClient()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        client.result = [AgendaEvent(id: "real-event", title: "Appointment", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), allDay: false, calendar: "Personal")]
        let agenda = AgendaStore(client: client, now: { now })
        agenda.refresh(); agenda.setEnabled(true)
        XCTAssertEqual(client.permissionRequests, 0)
        XCTAssertEqual(client.reads, 0)
        XCTAssertTrue(agenda.events.isEmpty)
        agenda.connect(); await drainTasks()
        XCTAssertEqual(client.permissionRequests, 1)
        XCTAssertEqual(agenda.state, .ready)
        XCTAssertEqual(agenda.events.map(\.id), ["real-event"])
        XCTAssertEqual(client.start, now)
        XCTAssertEqual(client.end, Calendar.current.date(byAdding: .day, value: 7, to: now))
    }

    @MainActor func testCalendarDenialAndWriteOnlyCannotExposeEventsButCanRecoverInSettings() async {
        let client = TestAgendaClient(); client.authorization = .writeOnly; client.granted = false
        let agenda = AgendaStore(client: client)
        agenda.setEnabled(true); agenda.connect(); await drainTasks()
        XCTAssertEqual(agenda.state, .denied)
        XCTAssertEqual(client.reads, 0)
        client.authorization = .fullAccess
        agenda.setActive(false); agenda.setActive(true)
        XCTAssertEqual(agenda.state, .ready)
        XCTAssertEqual(client.permissionRequests, 1)
        XCTAssertEqual(client.reads, 1)
    }

    @MainActor func testCalendarBackgroundRevocationAndStaleChangesCannotRestoreEventTitles() async {
        let client = TestAgendaClient(); client.authorization = .fullAccess
        client.result = [AgendaEvent(id: "private", title: "Private title", start: .now, end: .now.addingTimeInterval(600), allDay: false, calendar: "Private calendar")]
        let agenda = AgendaStore(client: client)
        agenda.setEnabled(true)
        XCTAssertEqual(agenda.events.count, 1)
        let staleChange = client.change
        agenda.setActive(false); staleChange?()
        XCTAssertTrue(agenda.events.isEmpty)
        client.authorization = .denied
        agenda.setActive(true)
        XCTAssertEqual(agenda.state, .denied)
        XCTAssertTrue(agenda.events.isEmpty)
        XCTAssertEqual(client.permissionRequests, 0)
    }

    @MainActor func testLateCalendarPermissionCannotRestoreHiddenContentAndDemoNeverRequestsIt() async {
        let client = TestAgendaClient(); client.delayAuthorization = true
        let agenda = AgendaStore(client: client)
        agenda.connect(); await drainTasks()
        XCTAssertNotNil(client.continuation)
        agenda.disconnect()
        client.authorization = .fullAccess
        client.continuation?.resume(returning: true); client.continuation = nil
        await drainTasks()
        XCTAssertEqual(client.reads, 0)
        XCTAssertTrue(agenda.events.isEmpty)
        XCTAssertEqual(agenda.state, .disconnected)
        agenda.setDemo(true); agenda.setEnabled(true); agenda.connect(); agenda.refresh()
        await drainTasks()
        XCTAssertEqual(client.permissionRequests, 1)
        XCTAssertEqual(client.reads, 0)
    }

    @MainActor func testCalendarPromptInactivityRecoversAfterLateConsentWithoutAnotherPrompt() async {
        let client = TestAgendaClient(); client.delayAuthorization = true
        let agenda = AgendaStore(client: client)
        agenda.connect(); await drainTasks()
        agenda.setActive(false); agenda.setActive(true)
        client.authorization = .fullAccess
        client.continuation?.resume(returning: true); client.continuation = nil
        await drainTasks()
        XCTAssertEqual(agenda.state, .ready)
        XCTAssertEqual(client.permissionRequests, 1)
        XCTAssertEqual(client.reads, 1)
    }

    private var defaultsSuite: String { "HomePad.RealMediaStoreTests" }
    private func isolatedDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        return defaults
    }
    @MainActor private func drainTasks() async { for _ in 0..<30 { await Task.yield() } }
    private enum PlaybackBoundary: String, CaseIterable { case pause, disconnect, demo, background }
    @MainActor private func crossBoundaryAndReconnect(_ boundary: PlaybackBoundary, music: MusicStore) async {
        switch boundary {
        case .pause: music.pause()
        case .disconnect: music.disconnect(); music.connect()
        case .demo: music.setDemo(true); music.setDemo(false)
        case .background: music.setActive(false); music.setActive(true)
        }
        await drainTasks()
        XCTAssertEqual(music.state, .ready, boundary.rawValue)
    }
    private func syntheticSong(id: String = "synthetic-tone", title: String = "Synthetic tone") throws -> Song {
        // Decode only an in-memory MusicKit model. No request or real account
        // is involved, and the fake client never sends this song to a player.
        let object: [String: Any] = [
            "id": id, "type": "songs",
            "attributes": ["name": title, "artistName": "HomePad test fixture", "albumName": "Synthetic validation",
                           "genreNames": [String](), "durationInMillis": 180000,
                           "playParams": ["id": id, "kind": "song"]]
        ]
        return try JSONDecoder().decode(Song.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func syntheticAlbum(id: String, title: String) throws -> Album {
        let object: [String: Any] = [
            "id": id, "type": "albums",
            "attributes": ["name": title, "artistName": "HomePad test fixture", "genreNames": [String](),
                           "trackCount": 1, "isCompilation": false, "isComplete": true, "isSingle": false]
        ]
        return try JSONDecoder().decode(Album.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func syntheticPlaylist(id: String, title: String) throws -> Playlist {
        let object: [String: Any] = ["id": id, "type": "playlists", "attributes": ["name": title, "curatorName": "HomePad test fixture", "isChart": false]]
        return try JSONDecoder().decode(Playlist.self, from: JSONSerialization.data(withJSONObject: object))
    }
}

@MainActor private final class TestMusicClient: HomePadMusicClient {
    var authorization: MusicAuthorization.Status = .authorized
    var permissionRequests = 0
    var subscriptionRequests = 0
    var libraryRequests = 0
    var libraryResults: [Song] = []
    var albumRequests = 0
    var albumResults: [Album] = []
    var albumError: Error?
    var playlistRequests = 0
    var playlistResults: [Playlist] = []
    var playlistError: Error?
    var playlistTrackResults: [MusicItemID: [Song]] = [:]
    var delayPlaylistTracks = false
    var playlistTrackContinuations: [MusicItemID: CheckedContinuation<[Song], Never>] = [:]
    var trackResults: [MusicItemID: [Song]] = [:]
    var delayTracks = false
    var trackContinuations: [MusicItemID: CheckedContinuation<[Song], Never>] = [:]
    var searchRequests = 0
    var playbackObservations = 0
    var pauseCalls = 0
    var playCalls = 0
    var nextCalls = 0
    var previousCalls = 0
    var shuffleCalls = 0
    var seekPositions: [TimeInterval] = []
    var actuallyPlaying = false
    var delayPlayback = false
    var pendingPlaybackIDs: [Int] { pendingPlayback.keys.sorted() }
    private var nextPlaybackID = 0
    private var pendingPlayback: [Int: CheckedContinuation<Void, Error>] = [:]
    private var currentTrack: MusicNowPlaying?
    private var queuedSongs: [Song] = []
    private var queueIndex = 0
    var subscriptionError: Error?
    var delayAuthorization = false
    var delayLibrary = false
    var delaySearch = false
    var authorizationContinuation: CheckedContinuation<MusicAuthorization.Status, Never>?
    var libraryContinuation: CheckedContinuation<[Song], Never>?
    var searchContinuation: CheckedContinuation<[Song], Never>?
    var update: ((MusicNowPlaying?) -> Void)?
    func requestAuthorization() async -> MusicAuthorization.Status {
        permissionRequests += 1
        if delayAuthorization { return await withCheckedContinuation { authorizationContinuation = $0 } }
        return authorization
    }
    func subscription() async throws -> HomePadMusicSubscription {
        subscriptionRequests += 1
        if let subscriptionError { throw subscriptionError }
        return HomePadMusicSubscription(canPlayCatalog: false, cloudLibraryEnabled: false)
    }
    func library() async throws -> [Song] {
        libraryRequests += 1
        if delayLibrary { return await withCheckedContinuation { libraryContinuation = $0 } }
        return libraryResults
    }
    func albums() async throws -> [Album] {
        albumRequests += 1
        if let albumError { throw albumError }
        return albumResults
    }
    func tracks(in album: Album) async throws -> [Song] {
        if delayTracks { return await withCheckedContinuation { trackContinuations[album.id] = $0 } }
        return trackResults[album.id] ?? []
    }
    func playlists() async throws -> [Playlist] {
        playlistRequests += 1
        if let playlistError { throw playlistError }
        return playlistResults
    }
    func tracks(in playlist: Playlist) async throws -> [Song] {
        if delayPlaylistTracks { return await withCheckedContinuation { playlistTrackContinuations[playlist.id] = $0 } }
        return playlistTrackResults[playlist.id] ?? []
    }
    func search(_ term: String) async throws -> [Song] {
        searchRequests += 1
        if delaySearch { return await withCheckedContinuation { searchContinuation = $0 } }
        return []
    }
    func play(_ songs: [Song], startingAt song: Song) async throws {
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
        try await play(songs, startingAtIndex: index)
    }
    func play(_ songs: [Song], startingAtIndex index: Int) async throws {
        guard songs.indices.contains(index) else { return }
        // Native MusicKit assigns the new queue before awaiting player.play().
        playCalls += 1; queuedSongs = songs
        queueIndex = index
        updateCurrentTrack()
        try await completePlaybackIgnoringCancellation()
    }
    func resume() async throws { try await completePlaybackIgnoringCancellation() }
    func seek(to position: TimeInterval) {
        seekPositions.append(position); currentTrack?.position = position; update?(currentTrack)
    }
    func skipNext() async throws {
        nextCalls += 1; queueIndex = min(queueIndex + 1, queuedSongs.count - 1); updateCurrentTrack()
        try await completePlaybackIgnoringCancellation()
    }
    func skipPrevious() async throws {
        previousCalls += 1; queueIndex = max(queueIndex - 1, 0); updateCurrentTrack()
        try await completePlaybackIgnoringCancellation()
    }
    func playQueueEntry(id: String) async throws {
        guard let index = currentTrack?.queue.firstIndex(where: { $0.id == id }) else { return }
        queueIndex = index; updateCurrentTrack()
        try await completePlaybackIgnoringCancellation()
    }
    func shuffleQueue() async throws {
        shuffleCalls += 1; queuedSongs.reverse(); queueIndex = 0; updateCurrentTrack()
        try await completePlaybackIgnoringCancellation()
    }
    private func updateCurrentTrack() {
        guard queuedSongs.indices.contains(queueIndex) else { currentTrack = nil; return }
        let song = queuedSongs[queueIndex]
        let entries = queuedSongs.enumerated().map { index, song in
            MusicQueueEntry(id: "entry-\(index)", songID: song.id, title: song.title, artist: song.artistName,
                            artwork: nil, duration: song.duration, isCurrent: index == queueIndex)
        }
        currentTrack = MusicNowPlaying(title: song.title, artist: song.artistName, artwork: nil, playing: actuallyPlaying,
                                      id: song.id, duration: song.duration, position: 0, queue: entries)
    }
    private func completePlaybackIgnoringCancellation() async throws {
        if delayPlayback {
            let id = nextPlaybackID; nextPlaybackID += 1
            try await withCheckedThrowingContinuation { pendingPlayback[id] = $0 }
        }
        actuallyPlaying = true
        currentTrack?.playing = true
        update?(currentTrack)
    }
    func finishPlayback(_ id: Int, error: Error? = nil) {
        guard let continuation = pendingPlayback.removeValue(forKey: id) else { return }
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }
    func publishCurrentPlayback() { update?(currentTrack) }
    func pause() { pauseCalls += 1; actuallyPlaying = false; currentTrack?.playing = false; update?(currentTrack) }
    func stop() { actuallyPlaying = false; currentTrack = nil; queuedSongs = []; update?(nil) }
    func observePlayback(_ update: @escaping (MusicNowPlaying?) -> Void) { playbackObservations += 1; self.update = update }
    func stopObservingPlayback() { update = nil }
}

@MainActor private final class TestAgendaClient: HomePadAgendaClient {
    var authorization: EKAuthorizationStatus = .notDetermined
    var granted = true
    var permissionRequests = 0
    var reads = 0
    var start: Date?
    var end: Date?
    var result: [AgendaEvent] = []
    var change: (() -> Void)?
    var delayAuthorization = false
    var continuation: CheckedContinuation<Bool, Error>?
    func requestAuthorization() async throws -> Bool {
        permissionRequests += 1
        if delayAuthorization { return try await withCheckedThrowingContinuation { continuation = $0 } }
        if granted { authorization = .fullAccess }
        return granted
    }
    func events(from start: Date, to end: Date) -> [AgendaEvent] { reads += 1; self.start = start; self.end = end; return result }
    func observeChanges(_ update: @escaping () -> Void) { change = update }
    func stopObservingChanges() { change = nil }
}
