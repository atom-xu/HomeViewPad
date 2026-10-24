import Foundation
import MusicKit
import Combine

/// Synthetic UI-test data is opt-in in Debug builds only. Normal application
/// launches always construct the native MusicKit client, including on devices.
@MainActor func musicValidationClientIfRequested() -> HomePadMusicClient? {
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    guard arguments.contains("--uitesting"), arguments.contains("--music-fixture") else { return nil }
    return try? MusicValidationClient()
    #else
    return nil
    #endif
}

#if DEBUG
@MainActor private final class MusicValidationClient: HomePadMusicClient {
    let isValidationFixture = true
    var authorization: MusicAuthorization.Status { .authorized }
    private let collection: [Album]
    private let returnsEmptyAlbums: Bool
    private let songsByAlbum: [String: [Song]]
    private let playlistCollection: [Playlist]
    private let songsByPlaylist: [String: [Song]]
    private var currentSongs: [Song]
    private var currentIndex = 0
    private var position: TimeInterval = 178
    private var playing = false
    private var update: ((MusicNowPlaying?) -> Void)?
    private var performanceTicks: AnyCancellable?

    init() throws {
        let arguments = ProcessInfo.processInfo.arguments
        returnsEmptyAlbums = arguments.contains("--music-empty-albums")
        var albums: [Album] = []
        var tracks: [String: [Song]] = [:]
        for index in 0..<3 {
            let identifier = "validation-album-\(index)"
            let name = "Validation album \(index + 1)"
            let attributes: [String: Any] = ["name": name, "artistName": "HomePad test fixture", "genreNames": [String](), "trackCount": 3, "isComplete": true, "isSingle": false, "isCompilation": false]
            let object: [String: Any] = ["id": identifier, "type": "albums", "attributes": attributes]
            albums.append(try JSONDecoder().decode(Album.self, from: JSONSerialization.data(withJSONObject: object)))
            tracks[identifier] = try (0..<3).map { number in
                let songID = "validation-song-\(index)-\(number)"
                let duration = [268, 225, 241][number]
                let attributes: [String: Any] = ["name": "Synthetic song \(index + 1).\(number + 1)", "artistName": "HomePad test fixture", "albumName": name, "genreNames": [String](), "durationInMillis": duration * 1000, "trackNumber": number + 1, "playParams": ["id": songID, "kind": "song"]]
                let object: [String: Any] = ["id": songID, "type": "songs", "attributes": attributes]
                return try JSONDecoder().decode(Song.self, from: JSONSerialization.data(withJSONObject: object))
            }
        }
        collection = albums; songsByAlbum = tracks
        if arguments.contains("--music-empty-queue") {
            currentSongs = []
        } else if arguments.contains("--music-restored-unknown") {
            // A restored queue item that cannot match the synthetic library by
            // ID or album metadata. Empty queue takes precedence if both flags
            // are supplied; neither branch constructs a native player.
            let id = "validation-restored-unknown"
            let attributes: [String: Any] = ["name": "Restored test song", "artistName": "HomePad test fixture", "genreNames": [String](), "durationInMillis": 268_000, "playParams": ["id": id, "kind": "song"]]
            let object: [String: Any] = ["id": id, "type": "songs", "attributes": attributes]
            currentSongs = [try JSONDecoder().decode(Song.self, from: JSONSerialization.data(withJSONObject: object))]
        } else {
            currentSongs = tracks[albums[0].id.rawValue] ?? []
        }
        var playlists: [Playlist] = []
        var playlistTracks: [String: [Song]] = [:]
        for index in 0..<2 {
            let id = "validation-playlist-\(index)"
            let attributes: [String: Any] = ["name": "Validation playlist \(index + 1)", "curatorName": "HomePad test fixture", "isChart": false]
            let object: [String: Any] = ["id": id, "type": "playlists", "attributes": attributes]
            playlists.append(try JSONDecoder().decode(Playlist.self, from: JSONSerialization.data(withJSONObject: object)))
            let entries = (tracks[albums[index].id.rawValue] ?? []) + (tracks[albums[index + 1].id.rawValue] ?? [])
            playlistTracks[id] = index == 1 ? entries + Array(entries.prefix(1)) : entries
        }
        playlistCollection = playlists; songsByPlaylist = playlistTracks
    }
    func requestAuthorization() async -> MusicAuthorization.Status { .authorized }
    func subscription() async throws -> HomePadMusicSubscription { HomePadMusicSubscription(canPlayCatalog: true, cloudLibraryEnabled: true) }
    func library() async throws -> [Song] { collection.flatMap { songsByAlbum[$0.id.rawValue] ?? [] } }
    func albums() async throws -> [Album] { returnsEmptyAlbums ? [] : collection }
    func tracks(in album: Album) async throws -> [Song] { songsByAlbum[album.id.rawValue] ?? [] }
    func playlists() async throws -> [Playlist] { playlistCollection }
    func tracks(in playlist: Playlist) async throws -> [Song] { songsByPlaylist[playlist.id.rawValue] ?? [] }
    func search(_ term: String) async throws -> [Song] { try await library().filter { $0.title.localizedCaseInsensitiveContains(term) } }
    func play(_ songs: [Song], startingAt song: Song) async throws {
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
        try await play(songs, startingAtIndex: index)
    }
    func play(_ songs: [Song], startingAtIndex index: Int) async throws {
        if ProcessInfo.processInfo.arguments.contains("--music-playback-failure") {
            try await Task.sleep(for: .seconds(2))
            throw NSError(domain: "HomePad.MusicValidation", code: 1)
        }
        guard songs.indices.contains(index) else { return }
        currentSongs = songs; currentIndex = index; position = 0; playing = true; publish()
    }
    func resume() async throws { playing = true; publish() }
    func seek(to position: TimeInterval) { self.position = position; publish() }
    func skipNext() async throws { currentIndex = min(currentIndex + 1, currentSongs.count - 1); position = 0; publish() }
    func skipPrevious() async throws { currentIndex = max(0, currentIndex - 1); position = 0; publish() }
    func playQueueEntry(id: String) async throws {
        guard let index = currentSongs.indices.first(where: { entryID($0) == id }) else { return }
        currentIndex = index; position = 0; playing = true; publish()
    }
    func shuffleQueue() async throws {
        currentSongs.reverse(); currentIndex = 0; position = 0; playing = true; publish()
    }
    func pause() { playing = false; publish() }
    func stop() { playing = false; update?(nil) }
    func observePlayback(_ update: @escaping (MusicNowPlaying?) -> Void) {
        self.update = update
        if ProcessInfo.processInfo.arguments.contains("--performance-audit") {
            performanceTicks = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                guard let self else { return }
                if self.playing { self.position += 0.5 }
                self.publish()
            }
        }
        publish()
    }
    func stopObservingPlayback() { update = nil; performanceTicks = nil }
    private func entryID(_ index: Int) -> String { "validation-entry-\(currentSongs[index].id.rawValue)-\(index)" }
    private func publish() {
        guard currentSongs.indices.contains(currentIndex) else { update?(nil); return }
        let current = currentSongs[currentIndex]
        let queue = currentSongs.indices.map { index in
            let song = currentSongs[index]
            return MusicQueueEntry(id: entryID(index), songID: song.id, title: song.title, artist: song.artistName, artwork: nil, duration: song.duration, isCurrent: index == currentIndex)
        }
        update?(MusicNowPlaying(title: current.title, artist: current.artistName, artwork: nil, playing: playing, id: current.id, duration: current.duration, position: position, queue: queue))
    }
}
#endif
