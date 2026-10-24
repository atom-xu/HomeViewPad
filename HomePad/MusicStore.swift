import Foundation
import SwiftUI
import MusicKit
import Combine
import AVFAudio

/// The successful queue's origin, independent of the album currently browsed.
/// Session-only; cleared with the other private playback state.
enum MusicPlaybackSource: Equatable {
    case album(MusicItemID), playlist(MusicItemID), library, search(String)
}

struct MusicNowPlaying {
    var title: String
    var artist: String
    var artwork: Artwork?
    var playing: Bool
    var id: MusicItemID? = nil
    var duration: TimeInterval? = nil
    var position: TimeInterval = 0
    var queue: [MusicQueueEntry] = []
}

/// A readback of the application's real MusicKit queue, not the album currently
/// being browsed. Entry IDs remain distinct even when a song appears twice.
struct MusicQueueEntry: Identifiable {
    var id: String
    var songID: MusicItemID?
    var title: String
    var artist: String
    var artwork: Artwork?
    var duration: TimeInterval?
    var isCurrent: Bool
}

struct HomePadMusicSubscription {
    let canPlayCatalog: Bool
    let cloudLibraryEnabled: Bool
}

/// Library requests expose offset/limit rather than a total count. Continue
/// until an empty page, including when the service returns a smaller page.
enum MusicLibraryPagination {
    @MainActor static func loadAll<Item>(pageSize: Int = 100, fetch: (Int, Int) async throws -> [Item]) async throws -> [Item] {
        precondition(pageSize > 0)
        var result: [Item] = []
        var offset = 0
        while true {
            try Task.checkCancellation()
            let page = try await fetch(offset, pageSize)
            try Task.checkCancellation()
            guard !page.isEmpty else { return result }
            result.append(contentsOf: page)
            offset += page.count
        }
    }
}

private enum MusicCollectionError: Error, Equatable { case empty, missingQueue, authorizationChanged }

@MainActor protocol HomePadMusicClient: AnyObject {
    var authorization: MusicAuthorization.Status { get }
    var isValidationFixture: Bool { get }
    func requestAuthorization() async -> MusicAuthorization.Status
    func subscription() async throws -> HomePadMusicSubscription
    func library() async throws -> [Song]
    func albums() async throws -> [Album]
    func tracks(in album: Album) async throws -> [Song]
    func playlists() async throws -> [Playlist]
    func tracks(in playlist: Playlist) async throws -> [Song]
    func search(_ term: String) async throws -> [Song]
    func play(_ songs: [Song], startingAt song: Song) async throws
    func play(_ songs: [Song], startingAtIndex index: Int) async throws
    func resume() async throws
    func seek(to position: TimeInterval)
    func skipNext() async throws
    func skipPrevious() async throws
    func playQueueEntry(id: String) async throws
    func shuffleQueue() async throws
    func pause()
    func stop()
    func observePlayback(_ update: @escaping (MusicNowPlaying?) -> Void)
    func stopObservingPlayback()
}

extension HomePadMusicClient {
    var isValidationFixture: Bool { false }
}

/// MusicKit manages developer/user tokens. No private keys or account tokens are
/// stored by HomePad. The player is lazy and is never created for demo content.
@MainActor final class NativeHomePadMusicClient: HomePadMusicClient {
    private var ownedPlayer: ApplicationMusicPlayer?
    private var observations: Set<AnyCancellable> = []
    private var playbackUpdate: ((MusicNowPlaying?) -> Void)?
    var authorization: MusicAuthorization.Status { MusicAuthorization.currentStatus }

    func requestAuthorization() async -> MusicAuthorization.Status { await MusicAuthorization.request() }
    func subscription() async throws -> HomePadMusicSubscription {
        let value = try await MusicSubscription.current
        return HomePadMusicSubscription(canPlayCatalog: value.canPlayCatalogContent, cloudLibraryEnabled: value.hasCloudLibraryEnabled)
    }
    func library() async throws -> [Song] {
        try await MusicLibraryPagination.loadAll { offset, limit in
            var request = MusicLibraryRequest<Song>()
            request.limit = limit; request.offset = offset
            request.sort(by: \.title, ascending: true)
            return Array(try await request.response().items)
        }
    }
    func albums() async throws -> [Album] {
        try await MusicLibraryPagination.loadAll { offset, limit in
            var request = MusicLibraryRequest<Album>()
            request.limit = limit; request.offset = offset
            request.sort(by: \.title, ascending: true)
            return Array(try await request.response().items)
        }
    }
    func tracks(in album: Album) async throws -> [Song] {
        let loaded = try await album.with(.tracks, preferredSource: .library)
        return try await playableSongs(in: loaded.tracks)
    }
    func playlists() async throws -> [Playlist] {
        try await MusicLibraryPagination.loadAll { offset, limit in
            var request = MusicLibraryRequest<Playlist>()
            request.limit = limit; request.offset = offset
            request.sort(by: \.name, ascending: true)
            return Array(try await request.response().items)
        }
    }
    func tracks(in playlist: Playlist) async throws -> [Song] {
        let loaded = try await playlist.with(.tracks, preferredSource: .library)
        return try await playableSongs(in: loaded.tracks)
    }
    private func playableSongs(in collection: MusicItemCollection<Track>?) async throws -> [Song] {
        guard let tracks = collection else { return [] }
        var allTracks = Array(tracks)
        var batch = tracks
        // MusicKit relationships may be paginated. Loading another batch is
        // still browsing; no queue or playback is assigned here.
        while batch.hasNextBatch {
            try Task.checkCancellation()
            guard let next = try await batch.nextBatch() else { break }
            allTracks.append(contentsOf: next)
            batch = next
        }
        return allTracks.compactMap { track in
            guard case .song(let song) = track, song.playParameters != nil else { return nil }
            return song
        }
    }
    func search(_ term: String) async throws -> [Song] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 25
        return Array(try await request.response().songs)
    }
    private var player: ApplicationMusicPlayer {
        if let ownedPlayer { return ownedPlayer }
        let value = ApplicationMusicPlayer.shared
        ownedPlayer = value
        return value
    }
    func play(_ songs: [Song], startingAt song: Song) async throws {
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { throw MusicCollectionError.empty }
        try await play(songs, startingAtIndex: index)
    }
    func play(_ songs: [Song], startingAtIndex index: Int) async throws {
        guard songs.indices.contains(index) else { throw MusicCollectionError.empty }
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        // The requested array is the complete, already ordered/shuffled queue.
        // Do not inherit repeat-one or an additional shuffle from player state.
        player.state.shuffleMode = .off
        player.state.repeatMode = MusicKit.MusicPlayer.RepeatMode.none
        let entries = songs.map { MusicKit.MusicPlayer.Queue.Entry($0) }
        player.queue = ApplicationMusicPlayer.Queue(entries, startingAt: entries[index])
        try await player.play()
        publishPlayback()
    }
    func resume() async throws { try await player.play() }
    func seek(to position: TimeInterval) {
        guard let ownedPlayer, position.isFinite else { return }
        ownedPlayer.playbackTime = position
        publishPlayback()
    }
    func skipNext() async throws { try await player.skipToNextEntry(); publishPlayback() }
    func skipPrevious() async throws { try await player.skipToPreviousEntry(); publishPlayback() }
    func playQueueEntry(id: String) async throws {
        guard let entry = ownedPlayer?.queue.entries.first(where: { $0.id == id }) else { return }
        player.queue.currentEntry = entry
        try await player.play()
        publishPlayback()
    }
    func shuffleQueue() async throws {
        guard let player = ownedPlayer else { throw MusicCollectionError.missingQueue }
        let entries = Array(player.queue.entries).shuffled()
        guard entries.count > 1, let first = entries.first else { throw MusicCollectionError.missingQueue }
        player.state.shuffleMode = .off
        player.state.repeatMode = MusicKit.MusicPlayer.RepeatMode.none
        player.queue = ApplicationMusicPlayer.Queue(entries, startingAt: first)
        try await player.play()
        publishPlayback()
    }
    func pause() { ownedPlayer?.pause() }
    func stop() {
        ownedPlayer?.stop()
        ownedPlayer?.queue = ApplicationMusicPlayer.Queue(for: [Song]())
    }
    func observePlayback(_ update: @escaping (MusicNowPlaying?) -> Void) {
        stopObservingPlayback()
        playbackUpdate = update
        let value = player
        value.state.objectWillChange.merge(with: value.queue.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.publishPlayback() }
            .store(in: &observations)
        // Read the actual player clock. This never advances a synthetic timer;
        // MusicStore removes both subscriptions whenever access/foreground ends.
        Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.publishPlayback() }
            .store(in: &observations)
        publishPlayback()
    }
    private func publishPlayback() {
        guard let update = playbackUpdate else { return }
        guard authorization == .authorized, let value = ownedPlayer, let entry = value.queue.currentEntry else {
            update(nil); return
        }
        let queue = value.queue.entries.map { candidate in
            MusicQueueEntry(id: candidate.id, songID: candidate.item?.id ?? candidate.transientItem?.id,
                            title: candidate.title, artist: candidate.subtitle ?? "", artwork: candidate.artwork,
                            duration: duration(of: candidate), isCurrent: candidate.id == entry.id)
        }
        let duration = duration(of: entry)
        let time = value.playbackTime
        let position = time.isFinite ? max(0, min(time, duration ?? time)) : 0
        update(MusicNowPlaying(title: entry.title, artist: entry.subtitle ?? "", artwork: entry.artwork,
                               playing: value.state.playbackStatus == .playing,
                               id: entry.item?.id ?? entry.transientItem?.id,
                               duration: duration, position: position, queue: queue))
    }
    private func duration(of entry: MusicKit.MusicPlayer.Queue.Entry) -> TimeInterval? {
        let raw: TimeInterval?
        switch entry.item {
        case .song(let song): raw = song.duration
        case .musicVideo(let video): raw = video.duration
        default: raw = (entry.transientItem as? Song)?.duration
        }
        guard let raw, raw.isFinite, raw > 0 else { return nil }
        return raw
    }
    func stopObservingPlayback() { playbackUpdate = nil; observations.removeAll() }
}

@MainActor final class MusicStore: ObservableObject {
    enum State: Equatable { case disconnected, connecting, ready, denied, restricted, unavailable }
    @Published private(set) var state: State = .disconnected
    @Published private(set) var library: [Song] = []
    @Published private(set) var albums: [Album] = []
    @Published private(set) var albumListMessage: String?
    @Published private(set) var selectedAlbum: Album?
    @Published private(set) var albumTracks: [Song] = []
    @Published private(set) var albumLoading = false
    @Published private(set) var albumMessage: String?
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var playlistListMessage: String?
    @Published private(set) var selectedPlaylist: Playlist?
    @Published private(set) var playlistTracks: [Song] = []
    @Published private(set) var playlistLoading = false
    @Published private(set) var playlistMessage: String?
    @Published private var confirmedPlaybackSource: MusicPlaybackSource?
    private var playbackSourceSongIDs: [String] = []
    var playbackSource: MusicPlaybackSource? {
        // A failed native start can already have replaced the queue. Never
        // describe that new readback as the previous successful album/playlist.
        guard !playbackSourceSongIDs.isEmpty, queue.count == playbackSourceSongIDs.count,
              queue.compactMap { $0.songID?.rawValue }.sorted() == playbackSourceSongIDs else { return nil }
        return confirmedPlaybackSource
    }
    private func rememberPlaybackSource(_ source: MusicPlaybackSource?, songIDs: [String]) {
        // Bind to this successful request, even if a simultaneous library
        // refresh temporarily detached playback observation.
        playbackSourceSongIDs = songIDs.sorted()
        confirmedPlaybackSource = source
    }
    @Published private(set) var queueIsShuffled = false
    @Published private(set) var results: [Song] = []
    @Published private(set) var subscription: HomePadMusicSubscription?
    @Published private(set) var nowPlaying: MusicNowPlaying?
    @Published private(set) var loading = false
    @Published private(set) var playingRequest = false
    @Published private(set) var message: String?
    @Published private(set) var detail: String?
    @Published private(set) var connected: Bool
    private let client: HomePadMusicClient
    private let defaults: UserDefaults
    private var active = true
    private var demo = false
    private var generation = UUID()
    private var searchGeneration = UUID()
    private var albumGeneration = UUID()
    private var playlistGeneration = UUID()
    // Playback has its own intent generation. Data refreshes do not replace a
    // playback intent, while Pause (including a switch to a local file) does.
    private var playbackGeneration = UUID()
    private var wantsPlayback = false
    private var task: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var albumTask: Task<Void, Never>?
    private var playlistTask: Task<Void, Never>?
    private let shuffleSongs: ([Song]) -> [Song]

    init(client: HomePadMusicClient? = nil, defaults: UserDefaults = .standard, shuffleSongs: (([Song]) -> [Song])? = nil) {
        let resolvedClient = client ?? NativeHomePadMusicClient()
        self.client = resolvedClient
        self.defaults = defaults
        self.shuffleSongs = shuffleSongs ?? { songs in
            resolvedClient.isValidationFixture ? Array(songs.reversed()) : songs.shuffled()
        }
        connected = defaults.bool(forKey: "music.connected")
    }
    var statusTitle: String {
        switch state {
        case .disconnected: "Not connected".tr
        case .connecting: "Connecting…".tr
        case .ready: "Apple Music connected".tr
        case .denied: "Music access is off".tr
        case .restricted: "Music access is restricted".tr
        case .unavailable: "Apple Music unavailable".tr
        }
    }
    var isValidationFixture: Bool { client.isValidationFixture }
    var queue: [MusicQueueEntry] { nowPlaying?.queue ?? [] }
    var canShuffleQueue: Bool { state == .ready && queue.count > 1 && !playingRequest }
    var canSeek: Bool { state == .ready && nowPlaying?.duration.map { $0.isFinite && $0 > 0 } == true && !playingRequest }
    var canSkipNext: Bool {
        guard state == .ready, !playingRequest, let index = queue.firstIndex(where: \.isCurrent) else { return false }
        return index + 1 < queue.count
    }
    var canSkipPrevious: Bool {
        guard state == .ready, !playingRequest, let index = queue.firstIndex(where: \.isCurrent) else { return false }
        return index > 0 || (canSeek && (nowPlaying?.position ?? 0) > 3)
    }

    /// Opening a page only reuses existing authorization. The Connect button is
    /// the sole caller allowed to request system permission.
    func open() {
        guard active, !demo, connected else { return }
        let authorization = client.authorization
        guard authorization == .authorized else {
            // A passive page open must not cancel an in-flight system prompt.
            if authorization == .notDetermined, state == .connecting { return }
            applyAuthorization(authorization)
            return
        }
        // Dashboard and MusicPage share this store. Re-entering the page reuses
        // its foreground data rather than flashing a connection screen and
        // clearing album selection. Explicit refresh and reactivation still load.
        guard state != .ready, state != .connecting else { return }
        refresh()
    }
    func connect() {
        guard active, !demo, state != .connecting else { return }
        connected = true
        defaults.set(true, forKey: "music.connected")
        startRefresh(requestPermission: true)
    }
    func refresh() { startRefresh(requestPermission: false) }
    private func startRefresh(requestPermission: Bool) {
        guard active, !demo, connected else { return }
        invalidateRequests()
        let token = generation
        state = .connecting; loading = true; message = nil; detail = nil; albumListMessage = nil; playlistListMessage = nil
        task = Task { [weak self] in
            guard let self else { return }
            let authorization = requestPermission ? await client.requestAuthorization() : client.authorization
            guard valid(token) else {
                // The system prompt can briefly inactivate the scene. If it
                // finishes after reactivation, reuse consent without prompting.
                if requestPermission, active, !demo, connected, authorization == .authorized,
                   client.authorization == .authorized, state != .connecting { refresh() }
                return
            }
            guard authorization == .authorized else { applyAuthorization(authorization); return }
            do {
                let availability = try await client.subscription()
                guard valid(token), client.authorization == .authorized else { authorizationChanged(token); return }
                subscription = availability
                // A library request is distinct from catalog playback. Purchased
                // and synced library songs can remain usable without membership.
                let songs = try await client.library()
                guard valid(token), client.authorization == .authorized else { authorizationChanged(token); return }
                library = songs
                do {
                    let libraryAlbums = try await client.albums()
                    guard valid(token), client.authorization == .authorized else { authorizationChanged(token); return }
                    albums = libraryAlbums
                } catch {
                    guard valid(token) else { return }
                    guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
                    // The album endpoint is independent of already-loaded
                    // songs and catalog access. Keep those usable on failure.
                    albums = []
                    albumListMessage = "Unable to load albums. Your songs and search are still available."
                }
                do {
                    let libraryPlaylists = try await client.playlists()
                    guard valid(token), client.authorization == .authorized else { authorizationChanged(token); return }
                    playlists = libraryPlaylists
                } catch {
                    guard valid(token) else { return }
                    guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
                    playlists = []
                    playlistListMessage = "Unable to load playlists. Your songs and albums are still available."
                }
                state = .ready; loading = false
                client.observePlayback { [weak self] value in
                    guard let self, self.valid(token) else { return }
                    guard self.client.authorization == .authorized else { self.applyAuthorization(self.client.authorization); return }
                    if var value, value.playing && !self.wantsPlayback {
                        // MusicKit may publish a late start before play() returns.
                        // Enforce a newer pause even during that interval.
                        self.client.pause(); value.playing = false; self.nowPlaying = value
                    } else { self.nowPlaying = value }
                }
            } catch {
                guard valid(token) else { return }
                if client.authorization != .authorized { applyAuthorization(client.authorization); return }
                library = []; albums = []; playlists = []; results = []; nowPlaying = nil; loading = false; state = .unavailable
                pause(); client.stopObservingPlayback()
                message = "Apple Music is unavailable. Check your account and connection, then try again."
                detail = error.localizedDescription
            }
        }
    }
    func selectAlbum(_ album: Album) {
        closeAlbum()
        guard active, !demo, state == .ready else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        selectedAlbum = album; albumLoading = true
        let token = generation, albumToken = albumGeneration
        albumTask = Task { [weak self] in
            guard let self else { return }
            do {
                let songs = try await client.tracks(in: album)
                guard valid(token), albumToken == albumGeneration else { return }
                guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
                albumTracks = songs; albumLoading = false
                if songs.isEmpty { albumMessage = "This album has no available songs." }
            } catch {
                guard valid(token), albumToken == albumGeneration else { return }
                if client.authorization != .authorized { applyAuthorization(client.authorization); return }
                albumLoading = false; albumTracks = []
                albumMessage = "Unable to load this album. Try again."
            }
        }
    }
    func closeAlbum() {
        albumGeneration = UUID(); albumTask?.cancel(); albumTask = nil
        selectedAlbum = nil; albumTracks = []; albumLoading = false; albumMessage = nil
    }
    func selectPlaylist(_ playlist: Playlist) {
        closePlaylist()
        guard active, !demo, state == .ready else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        selectedPlaylist = playlist; playlistLoading = true
        let token = generation, playlistToken = playlistGeneration
        playlistTask = Task { [weak self] in
            guard let self else { return }
            do {
                let songs = try await client.tracks(in: playlist)
                guard valid(token), playlistToken == playlistGeneration else { return }
                guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
                playlistTracks = songs; playlistLoading = false
                if songs.isEmpty { playlistMessage = "This playlist has no available songs." }
            } catch {
                guard valid(token), playlistToken == playlistGeneration else { return }
                if client.authorization != .authorized { applyAuthorization(client.authorization); return }
                playlistLoading = false; playlistTracks = []
                playlistMessage = "Unable to load this playlist. Try again."
            }
        }
    }
    func closePlaylist() {
        playlistGeneration = UUID(); playlistTask?.cancel(); playlistTask = nil
        selectedPlaylist = nil; playlistTracks = []; playlistLoading = false; playlistMessage = nil
    }
    func search(_ rawTerm: String) {
        searchTask?.cancel(); searchGeneration = UUID(); results = []
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard active, !demo, state == .ready, client.authorization == .authorized, !term.isEmpty else { return }
        let token = generation, searchToken = searchGeneration
        loading = true; message = nil; detail = nil
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let songs = try await client.search(term)
                guard valid(token), searchToken == searchGeneration else { return }
                guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
                results = songs; loading = false
                if songs.isEmpty { message = "No songs found." }
            } catch {
                guard valid(token), searchToken == searchGeneration else { return }
                loading = false; results = []
                if client.authorization != .authorized { applyAuthorization(client.authorization); return }
                message = "Unable to search Apple Music. Try again."; detail = error.localizedDescription
            }
        }
    }
    func play(_ song: Song, from songs: [Song], catalog: Bool, startingIndex: Int? = nil, source: MusicPlaybackSource? = nil) {
        guard active, !demo, state == .ready, client.authorization == .authorized, !playingRequest else { return }
        guard songs.contains(where: { $0.id == song.id }) else { return }
        if let startingIndex {
            guard songs.indices.contains(startingIndex), songs[startingIndex].id == song.id else { return }
        }
        guard !catalog || subscription?.canPlayCatalog == true else {
            message = "An Apple Music subscription is required to play catalog songs."; return
        }
        beginPlayback(failureMessage: "Unable to play this song. Try another song or open Music.", onSuccess: { [weak self] in self?.queueIsShuffled = false; self?.rememberPlaybackSource(source, songIDs: songs.map { $0.id.rawValue }) }) { [client] in
            if let startingIndex { try await client.play(songs, startingAtIndex: startingIndex) }
            else { try await client.play(songs, startingAt: song) }
        }
    }
    func playCollection(_ songs: [Song], shuffle: Bool = false, catalog: Bool = false, source: MusicPlaybackSource? = nil) {
        beginCollectionPlayback(shuffle: shuffle, catalog: catalog, source: source) { songs }
    }
    func playLibrary(shuffle: Bool = false) { playCollection(library, shuffle: shuffle, source: .library) }
    func playAlbum(_ album: Album, shuffle: Bool = false) {
        if selectedAlbum?.id == album.id, !albumLoading {
            playCollection(albumTracks, shuffle: shuffle, source: .album(album.id))
        } else {
            beginCollectionPlayback(shuffle: shuffle, source: .album(album.id)) { [client] in try await client.tracks(in: album) }
        }
    }
    func playPlaylist(_ playlist: Playlist, shuffle: Bool = false) {
        if selectedPlaylist?.id == playlist.id, !playlistLoading {
            playCollection(playlistTracks, shuffle: shuffle, source: .playlist(playlist.id))
        } else {
            beginCollectionPlayback(shuffle: shuffle, source: .playlist(playlist.id)) { [client] in try await client.tracks(in: playlist) }
        }
    }
    private func beginCollectionPlayback(shuffle: Bool, catalog: Bool = false, source: MusicPlaybackSource? = nil, load: @escaping @MainActor () async throws -> [Song]) {
        guard active, !demo, connected, state == .ready, !playingRequest else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        guard !catalog || subscription?.canPlayCatalog == true else {
            message = "An Apple Music subscription is required to play catalog songs."; return
        }
        var requestSongIDs: [String] = []
        beginPlayback(failureMessage: "Unable to play this collection. Try again.", onSuccess: { [weak self] in
            self?.queueIsShuffled = shuffle
            self?.rememberPlaybackSource(source, songIDs: requestSongIDs)
        }) { [weak self, client] in
            let loaded = try await load()
            // A cancelled album/playlist fetch may still complete. Check before
            // assigning any player queue, not only after player.play returns.
            try Task.checkCancellation()
            guard let self, client.authorization == .authorized else { throw MusicCollectionError.authorizationChanged }
            let songs = loaded.filter { $0.playParameters != nil }
            guard !songs.isEmpty else { throw MusicCollectionError.empty }
            let ordered = shuffle ? self.shuffleSongs(songs) : songs
            guard let first = ordered.first else { throw MusicCollectionError.empty }
            requestSongIDs = ordered.map { $0.id.rawValue }
            try await client.play(ordered, startingAt: first)
        }
    }
    func togglePlayback() {
        guard active, !demo, state == .ready, nowPlaying != nil, !playingRequest else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        if nowPlaying?.playing == true { pause(); return }
        beginPlayback(failureMessage: "Unable to resume playback.") { [client] in try await client.resume() }
    }
    func seek(to position: TimeInterval) {
        guard active, !demo, connected, canSeek, position.isFinite,
              let duration = nowPlaying?.duration else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        client.seek(to: max(0, min(position, duration)))
    }
    func skipNext() {
        guard active, !demo, connected, canSkipNext else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        beginPlayback(failureMessage: "Unable to skip this song.", shouldPlay: nowPlaying?.playing == true) { [client] in
            try await client.skipNext()
        }
    }
    func skipPrevious() {
        guard active, !demo, connected, canSkipPrevious else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        if (nowPlaying?.position ?? 0) > 3, canSeek { seek(to: 0); return }
        beginPlayback(failureMessage: "Unable to skip this song.", shouldPlay: nowPlaying?.playing == true) { [client] in
            try await client.skipPrevious()
        }
    }
    func playQueueEntry(_ entry: MusicQueueEntry) {
        guard active, !demo, connected, state == .ready, !playingRequest,
              queue.contains(where: { $0.id == entry.id }) else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        beginPlayback(failureMessage: "Unable to play this song. Try another song or open Music.") { [client] in
            try await client.playQueueEntry(id: entry.id)
        }
    }
    func shuffleQueue() {
        guard active, !demo, connected, canShuffleQueue else { return }
        guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
        beginPlayback(failureMessage: "Unable to shuffle this queue. Try again.", onSuccess: { [weak self] in self?.queueIsShuffled = true }) { [client] in
            try await client.shuffleQueue()
        }
    }
    private func beginPlayback(failureMessage: String, shouldPlay: Bool = true, onSuccess: (() -> Void)? = nil, operation: @escaping @MainActor () async throws -> Void) {
        playbackTask?.cancel()
        playbackGeneration = UUID()
        let token = playbackGeneration
        wantsPlayback = shouldPlay; playingRequest = true; message = nil; detail = nil
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await operation()
                guard currentPlayback(token) else { enforceLatestPlaybackIntent(); return }
                guard client.authorization == .authorized else { applyAuthorization(client.authorization); return }
                playingRequest = false
                onSuccess?()
                // Moving through the queue while paused keeps it paused, even
                // if a MusicKit implementation starts the selected entry.
                if !shouldPlay { client.pause() }
            } catch {
                guard currentPlayback(token) else { enforceLatestPlaybackIntent(); return }
                if client.authorization != .authorized { applyAuthorization(client.authorization); return }
                wantsPlayback = false; playingRequest = false
                client.pause()
                message = (error as? MusicCollectionError) == .empty ? "This collection has no available songs." : failureMessage
                detail = error.localizedDescription
            }
        }
    }
    func pause() {
        playbackGeneration = UUID(); wantsPlayback = false
        playbackTask?.cancel(); playbackTask = nil; playingRequest = false
        client.pause()
        if var value = nowPlaying { value.playing = false; nowPlaying = value }
    }
    private func currentPlayback(_ token: UUID) -> Bool {
        token == playbackGeneration && active && !demo && connected && !Task.isCancelled
    }
    private func enforceLatestPlaybackIntent() {
        // An old operation may ignore task cancellation. A late completion must
        // reapply a pause, but must never pause a newer Play/Resume intent.
        if !wantsPlayback || !active || demo || !connected || client.authorization != .authorized { client.pause() }
    }
    /// A route picker is a temporary system presentation, not backgrounding.
    /// Background always clears private data, even while a picker is presented.
    func setScenePhase(_ phase: ScenePhase, routePickerPresented: Bool) {
        if phase == .active {
            if active { open() } else { setActive(true) }
        } else if phase == .background || !routePickerPresented {
            setActive(false)
        }
    }
    func setActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        if value { open() }
        else { clearTransient(); client.pause() }
    }
    func setDemo(_ value: Bool) {
        guard demo != value else { return }
        demo = value
        clearTransient(); client.stop()
        if !value { open() }
    }
    func cancelSearch() {
        searchTask?.cancel(); searchGeneration = UUID(); results = []; loading = state == .connecting
    }
    func disconnect() {
        connected = false; defaults.set(false, forKey: "music.connected")
        clearTransient(); client.stop()
    }
    private func valid(_ token: UUID) -> Bool { token == generation && active && !demo && connected && !Task.isCancelled }
    private func authorizationChanged(_ token: UUID) {
        guard valid(token) else { return }
        applyAuthorization(client.authorization)
    }
    private func applyAuthorization(_ value: MusicAuthorization.Status) {
        clearTransient(); client.stop()
        switch value {
        case .denied: state = .denied
        case .restricted: state = .restricted
        default: state = .disconnected
        }
    }
    private func invalidateRequests() {
        generation = UUID(); searchGeneration = UUID()
        task?.cancel(); searchTask?.cancel()
        task = nil; searchTask = nil
        closeAlbum()
        closePlaylist()
        client.stopObservingPlayback()
    }
    private func clearTransient() {
        // Detach observations and invalidate their generation before pausing.
        // A client may synchronously report that pause while access is revoked.
        invalidateRequests()
        pause()
        library = []; albums = []; albumListMessage = nil; playlists = []; playlistListMessage = nil
        queueIsShuffled = false; confirmedPlaybackSource = nil; playbackSourceSongIDs = []; results = []; subscription = nil; nowPlaying = nil
        loading = false; message = nil; detail = nil; state = .disconnected
    }
}
