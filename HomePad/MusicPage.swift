import SwiftUI
import MusicKit
import UniformTypeIdentifiers
import UIKit
import MediaPlayer
import ImageIO

/// Only controls that own a horizontal drag opt out of Dashboard paging.
struct MusicPageGestureFrameKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

private struct MusicPageGestureRegion: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.preference(key: MusicPageGestureFrameKey.self,
                                       value: [geometry.frame(in: .global).insetBy(dx: -12, dy: -12)])
            }.allowsHitTesting(false)
        }
    }
}

/// Session navigation belongs to Dashboard so changing pages does not discard
/// the user's browsing position. It is cleared with private music state.
struct MusicNavigationState {
    enum Screen: Hashable { case player, albums, songs, tracks, playlists, playlistTracks, queue }
    private(set) var path: [Screen] = []
    private(set) var forward = true
    var albumID: MusicItemID?
    var playlistID: MusicItemID?
    var songID: MusicItemID?
    var screen: Screen { path.last ?? .player }
    var parent: Screen { path.dropLast().last ?? .player }

    mutating func show(_ destination: Screen) {
        guard destination != screen else { return }
        forward = destination != .player
        if destination == .player { path = [] }
        else if destination == .albums || destination == .songs || destination == .playlists { path = [destination] }
        else { path.append(destination) }
    }
    mutating func back() { forward = false; if !path.isEmpty { path.removeLast() } }
    mutating func returnToAlbumBrowser(_ source: MusicPlaybackSource?, currentSongID: MusicItemID?) {
        forward = false
        if case .album(let id) = source { albumID = id }
        if let currentSongID { songID = currentSongID }
        // Playback source may be unknown after reopening a native queue.
        // Back always exposes album cards; only the explicit queue button
        // enters the queue, so queue -> player -> back cannot cycle.
        path = [.albums]
    }
    mutating func reset() { self = Self() }
}

/// A single, real MusicKit player with Cover Flow browsing. Browsing an album
/// does not replace the queue; only an explicit song selection does so.
struct MusicPage: View {
    @ObservedObject var store: MusicStore
    @ObservedObject var audio: AudioStore
    let demo: Bool
    @Binding var navigation: MusicNavigationState
    var showPageNavigation: () -> Void
    var changePage: (Bool) -> Void
    var presentationChanged: (Bool) -> Void = { _ in }
    var airPlayPresentationChanged: (Bool) -> Void = { _ in }
    @State private var albumDrag: CGFloat = 0
    @State private var pendingSongIndex: Int?
    @State private var pendingSongID: MusicItemID?
    @State private var pendingQueueID: String?
    @State private var pendingCollection = false
    @State private var options = false
    @State private var output = false
    @State private var importAudio = false
    @State private var localGestureFrames: [CGRect] = []
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Screen = MusicNavigationState.Screen
    private var screen: Screen { navigation.screen }
    private var albumIndex: Int { store.albums.firstIndex(where: { $0.id == navigation.albumID }) ?? 0 }
    private var currentAlbum: Album? { store.albums.indices.contains(albumIndex) ? store.albums[albumIndex] : nil }
    private var songIndex: Int { store.library.firstIndex(where: { $0.id == navigation.songID }) ?? 0 }
    private var currentSong: Song? { store.library.indices.contains(songIndex) ? store.library[songIndex] : nil }
    private var isLibraryRoot: Bool { [.albums, .songs, .playlists].contains(screen) }
    private var selectionSource: MusicPlaybackSource? {
        switch screen {
        case .tracks: return navigation.albumID.map(MusicPlaybackSource.album)
        case .playlistTracks: return navigation.playlistID.map(MusicPlaybackSource.playlist)
        case .songs, .albums: return .library
        default: return nil
        }
    }
    private var ready: Bool { !demo && store.state == .ready }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MusicPageBackdrop(artwork: demo ? nil : store.nowPlaying?.artwork, trackID: store.nowPlaying?.id, fixture: store.isValidationFixture)
                VStack(spacing: 8) {
                    header.modifier(MusicPageGestureRegion())
                    if ready {
                        content(size: CGSize(width: geometry.size.width, height: max(200, geometry.size.height - 90)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        disconnectedContent
                    }
                    MusicValidationLabel()
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 24 : max(28, geometry.size.width * 0.05))
                .padding(.top, 20).padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        // Unlike the Dashboard's simultaneous gesture, this yields to the
        // carousel's high-priority drag, including during its 3D animation.
        .gesture(DragGesture(minimumDistance: 30, coordinateSpace: .global).onEnded { value in
            guard !localGestureFrames.contains(where: { $0.contains(value.startLocation) }) else { return }
            swipePage(value.translation)
        })
        .onPreferenceChange(MusicPageGestureFrameKey.self) { localGestureFrames = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("musicPage")
        .sheet(isPresented: $options) {
            NavigationStack {
                Form {
                    if store.isValidationFixture {
                        Section { MusicValidationLabel().accessibilityIdentifier("musicSettingsValidationData") }
                    }
                    Section { connectionDetails }
                    Section("Playback destination".tr) {
                        HStack {
                            Label("HomePod or AirPlay speaker".tr, systemImage: "homepod.fill")
                            Spacer()
                            AirPlayPicker(presentationChanged: airPlayPresentationChanged).frame(width: 44, height: 44)
                                .accessibilityIdentifier("musicSettingsAirPlay")
                        }
                    }
                    Section { fileDetails }
                }
                .scrollContentBackground(.visible)
                .background(Color(uiColor: .systemGroupedBackground))
                .accessibilityIdentifier("musicSettingsForm")
                .navigationTitle("Music settings".tr)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done".tr) { options = false } } }
            }
            .foregroundStyle(Color.primary)
            .tint(.accentColor)
            .preferredColorScheme(.dark)
            .presentationBackground(Color(uiColor: .systemGroupedBackground))
        }
        .fileImporter(isPresented: $importAudio, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url): store.pause(); audio.load(url)
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { audio.message = error.localizedDescription }
            }
        }
        .task { store.setDemo(demo); store.open(); restoreBrowsing() }
        .onDisappear { store.cancelSearch(); store.closeAlbum(); store.closePlaylist(); presentationChanged(false) }
        .onChange(of: options) { _, _ in reportPresentation() }
        .onChange(of: output) { _, _ in reportPresentation() }
        .onChange(of: importAudio) { _, _ in reportPresentation() }
        .onChange(of: demo) { _, value in store.setDemo(value); navigation.reset() }
        .onChange(of: store.state) { _, state in
            if state == .ready { restoreBrowsing(); if store.nowPlaying == nil { show(.albums) } }
            if state != .ready { store.closeAlbum(); store.closePlaylist(); pendingSongID = nil; pendingQueueID = nil; pendingCollection = false }
        }
        .onChange(of: store.albums.map(\.id)) { _, _ in restoreBrowsing() }
        .onChange(of: store.playlists.map(\.id)) { _, _ in restoreBrowsing() }
        .onChange(of: store.nowPlaying?.playing) { _, _ in finishSelection() }
        .onChange(of: store.queue.map(\.id)) { _, _ in finishSelection() }
        .onChange(of: store.playingRequest) { _, _ in finishSelection() }
        .onChange(of: store.nowPlaying?.id) { _, _ in finishSelection() }
        .onChange(of: store.nowPlaying?.queue.first(where: \.isCurrent)?.id) { _, _ in finishSelection() }
    }

    private var backTitle: String {
        if screen == .player { return "Browse albums".tr }
        switch navigation.parent {
        case .albums: return "Albums".tr
        case .songs: return "Songs".tr
        case .playlists: return "Playlists".tr
        case .tracks, .playlistTracks: return "Songs".tr
        case .queue: return "Playback queue".tr
        case .player: return "Now playing".tr
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if ready && !isLibraryRoot {
                MusicSymbolButton(symbol: "chevron.left", label: backTitle, size: 21, action: leadingAction)
                    .accessibilityIdentifier("musicLibrary")
            } else {
                Text("Music".tr).font(.title3.weight(.medium))
            }
            Spacer(minLength: 12)
            if demo { Text("DEMO".tr).font(.caption.bold()) }
            AirPlayPicker(lightControls: true, presentationChanged: airPlayPresentationChanged)
                .frame(width: 44, height: 44).modifier(GlassSurface(radius: 22))
                .accessibilityIdentifier("musicAirPlay")
            MusicSymbolButton(symbol: "speaker.wave.2", label: "Volume".tr, size: 20) { output = true }
                .modifier(GlassSurface(radius: 22))
                .accessibilityIdentifier("musicVolume")
                .popover(isPresented: $output, arrowEdge: .top) { volumePanel }
            MusicSymbolButton(symbol: "ellipsis", label: "Music settings".tr, size: 20) { options = true }
                .modifier(GlassSurface(radius: 22)).accessibilityIdentifier("musicOptions")
            Button(action: showPageNavigation) {
                Label("Pages".tr, systemImage: "square.grid.2x2")
                    .font(.system(size: 15, weight: .regular))
                    .padding(.horizontal, 14).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).modifier(GlassSurface(radius: 24))
            .accessibilityLabel("Switch page".tr)
            .accessibilityIdentifier("showNavigationButton")
        }
        .frame(minHeight: 44)
    }

    private var volumePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Text("Volume".tr).font(.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button("Done".tr) { output = false }
                    .font(.subheadline).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("musicVolumeDone")
            }
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill").font(.system(size: 16)).foregroundStyle(.secondary).accessibilityHidden(true)
                MusicVolumeControl().frame(height: 44)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("musicSystemVolumeControl")
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 16)).foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 340 : 280).padding(20)
        .foregroundStyle(Color.primary).preferredColorScheme(.dark)
        .presentationBackground(Color(uiColor: .secondarySystemGroupedBackground))
        .accessibilityElement(children: .contain).accessibilityIdentifier("musicVolumePanel")
    }

    @ViewBuilder private func content(size: CGSize) -> some View {
        VStack(spacing: 8) {
            ZStack {
              Group {
                switch screen {
                case .player: player(size: size)
                case .albums: albumBrowser(size: size)
                case .songs: songBrowser(size: size)
                case .tracks: albumDetail(size: size)
                case .playlists: playlistBrowser
                case .playlistTracks: playlistDetail(size: size)
                case .queue: queueView
                }
              }
              .id(screen)
              .transition(screenTransition)
            }.frame(maxWidth: 940, maxHeight: .infinity).clipped()
            if let message = store.message {
                Text(message.tr).font(.footnote).foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center).accessibilityIdentifier("musicMessage")
            }
            if screen != .player, store.nowPlaying != nil { miniPlayer }
        }
    }

    @ViewBuilder private func player(size: CGSize) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                VStack(spacing: 22) {
                    hero(side: 180)
                    songInformation
                    if let value = store.nowPlaying { MusicPlaybackProgress(store: store, value: value).modifier(MusicPageGestureRegion()) }
                    transport.modifier(MusicPageGestureRegion())
                    if store.nowPlaying == nil { emptyPlayerAction }
                }.padding(.vertical, 20)
            }
        } else {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                hero(side: min(500, size.width * 0.46, max(180, size.height - 260)))
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    songInformation
                    if let value = store.nowPlaying { MusicPlaybackProgress(store: store, value: value).modifier(MusicPageGestureRegion()) }
                    else { emptyPlayerAction }
                    transport.modifier(MusicPageGestureRegion())
                }.frame(maxWidth: 830)
            }
        }
    }

    private func hero(side: CGFloat) -> some View {
        Button { returnToAlbumBrowser() } label: {
            ZStack {
                MusicArtwork(artwork: store.nowPlaying?.artwork, side: side, radius: 17)
                    .id(store.nowPlaying?.id).transition(.opacity)
            }
                .frame(width: side, height: side)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.nowPlaying?.id)
                .shadow(color: .black.opacity(0.25), radius: 28, y: 15)
                .contentShape(RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        // A page drag must cancel the artwork's tap-to-browse action.
        .highPriorityGesture(DragGesture(minimumDistance: 30).onEnded { swipePage($0.translation) })
        .accessibilityLabel("Browse albums".tr)
        .accessibilityIdentifier("musicHeroArtwork")
    }

    private var songInformation: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.nowPlaying?.title ?? "Choose your music".tr)
                    .font(dynamicTypeSize.isAccessibilitySize ? .title2.weight(.medium) : .system(size: 28, weight: .medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .accessibilityIdentifier("musicNowPlayingTitle")
                if let artist = store.nowPlaying?.artist, !artist.isEmpty {
                    Text(artist).font(dynamicTypeSize.isAccessibilitySize ? .body : .system(size: 16))
                        .foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Browse albums".tr) { show(.albums) }
                Button("Music settings".tr) { options = true }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 21, weight: .regular))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("More music options".tr)
            .modifier(MusicPageGestureRegion())
        }
    }

    private var emptyPlayerAction: some View {
        Button("Browse albums".tr) { show(.albums) }
            .buttonStyle(.bordered).frame(minHeight: 44)
    }

    private var transport: some View {
        HStack {
            MusicSymbolButton(symbol: "shuffle", label: "Shuffle queue".tr, size: 20) { startCollection { store.shuffleQueue() } }
                .disabled(!store.canShuffleQueue).accessibilityIdentifier("musicShuffleQueue")
            Spacer(minLength: 10)
            MusicSymbolButton(symbol: "backward.fill", label: "Previous song".tr, size: 30) { audio.stop(); store.skipPrevious() }
                .disabled(!store.canSkipPrevious || store.playingRequest).accessibilityIdentifier("musicPrevious")
            Spacer(minLength: 10)
            MusicSymbolButton(symbol: store.nowPlaying?.playing == true ? "pause.fill" : "play.fill",
                              label: (store.nowPlaying?.playing == true ? "Pause" : "Play").tr, size: 36, target: 62, busy: store.playingRequest) {
                audio.stop(); store.togglePlayback()
            }
            .disabled(store.nowPlaying == nil || store.playingRequest).accessibilityIdentifier("musicPlayback")
            Spacer(minLength: 10)
            MusicSymbolButton(symbol: "forward.fill", label: "Next song".tr, size: 30) { audio.stop(); store.skipNext() }
                .disabled(!store.canSkipNext || store.playingRequest).accessibilityIdentifier("musicNext")
            Spacer(minLength: 10)
            MusicSymbolButton(symbol: "list.bullet", label: "Playback queue".tr, size: 20) { show(.queue) }
                .accessibilityIdentifier("musicQueue")
        }
    }

    private var libraryModes: some View {
        HStack(spacing: 4) {
            libraryTab(.albums, title: "Albums", identifier: "musicAlbumsTab")
            libraryTab(.songs, title: "Songs", identifier: "musicSongsTab")
            libraryTab(.playlists, title: "Playlists", identifier: "musicPlaylistsTab")
        }
        .padding(4).background(.white.opacity(0.07), in: Capsule())
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
        .modifier(MusicPageGestureRegion())
    }

    private func libraryTab(_ destination: Screen, title: String, identifier: String) -> some View {
        Button { show(destination) } label: {
            Text(title.tr).font(.subheadline.weight(screen == destination ? .semibold : .regular))
                .foregroundStyle(.white.opacity(screen == destination ? 1 : 0.6))
                .padding(.horizontal, 22).frame(minWidth: 76, minHeight: 40)
                .background(screen == destination ? .white.opacity(0.18) : .clear, in: Capsule())
        }.buttonStyle(.plain)
            .accessibilityAddTraits(screen == destination ? .isSelected : [])
            .accessibilityIdentifier(identifier)
    }

    private func albumBrowser(size: CGSize) -> some View {
        VStack(spacing: 10) { libraryModes; albumBrowserContent(size: size) }
    }

    @ViewBuilder private func albumBrowserContent(size: CGSize) -> some View {
        if store.albums.isEmpty {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "square.stack").font(.system(size: 54, weight: .light)).foregroundStyle(.secondary)
                Text((store.albumListMessage == nil ? "Your library has no available albums." : "Unable to load albums. Your songs are still available.").tr).font(.title3).multilineTextAlignment(.center)
                Text("Add albums in Music, then refresh your library.".tr).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Refresh library".tr) { store.refresh() }.buttonStyle(.bordered)
                }
                if !store.library.isEmpty { librarySongList }
                Spacer()
            }
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.albums) { album in
                        Button { openAlbum(album) } label: {
                            HStack(spacing: 16) {
                                MusicArtwork(artwork: album.artwork, side: 72, radius: 12)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(album.title).font(.headline)
                                    Text(album.artistName).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("musicAlbum-\(album.id.rawValue)")
                    }
                }
            }
        } else {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                coverFlow(width: min(size.width * 0.9, 940), height: min(380, size.height * 0.58))
                HStack(spacing: 24) {
                    MusicSymbolButton(symbol: "chevron.left", label: "Previous album".tr, size: 20) { browse(-1) }
                        .disabled(albumIndex == 0).accessibilityIdentifier("musicPreviousAlbum")
                    VStack(spacing: 5) {
                        Text(currentAlbum?.title ?? "").font(.system(size: 22, weight: .medium)).lineLimit(2)
                        Text(currentAlbum?.artistName ?? "").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }.frame(maxWidth: 460)
                    MusicSymbolButton(symbol: "chevron.right", label: "Next album".tr, size: 20) { browse(1) }
                        .disabled(albumIndex >= store.albums.count - 1).accessibilityIdentifier("musicNextAlbum")
                }
                Button { if let album = currentAlbum { startCollection { store.playAlbum(album) } } } label: {
                    Image(systemName: "play.fill").font(.system(size: 23, weight: .regular))
                        .frame(width: 58, height: 58).background(.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain).disabled(store.playingRequest)
                .accessibilityLabel("Play album".tr).accessibilityIdentifier("musicPlayFocusedAlbum")
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("musicCoverFlow")
        }
    }

    private struct Cover: Identifiable {
        let id: String
        let title: String
        let artist: String
        let artwork: Artwork?
    }

    private func coverFlow(width: CGFloat, height: CGFloat) -> some View {
        coverFlow(items: store.albums.map { Cover(id: $0.id.rawValue, title: $0.title, artist: $0.artistName, artwork: $0.artwork) },
                  index: albumIndex, width: width, height: height, album: true,
                  select: moveToAlbum, open: { index in openAlbum(store.albums[index]) })
    }

    private func coverFlow(items: [Cover], index: Int, width: CGFloat, height: CGFloat, album: Bool,
                           select: @escaping (Int) -> Void, open: @escaping (Int) -> Void) -> some View {
        // Reserve space for the full shadow so the surface never cuts it at
        // the top or bottom. Both axes fade into the same page backdrop.
        let side = max(0, min(height - 64, width * 0.37))
        let step = side * 0.68
        return ZStack {
            // Keep a fully transparent extra neighbour alive through the move;
            // removing the outermost view must not make a visible cover pop out.
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                let distance = offset - index
                let position = CGFloat(distance) + albumDrag / max(1, step)
                if abs(distance) <= 3 {
                    Button {
                        if distance == 0 { open(offset) }
                        else { select(offset) }
                    } label: {
                        MusicArtwork(artwork: item.artwork, side: side, radius: 13)
                            .shadow(color: .black.opacity(0.3), radius: 24, y: 16)
                    }
                    .buttonStyle(.plain)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(-min(1, max(-1, position))) * 48), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .scaleEffect(1 - min(abs(position), 1.75) * 0.16)
                    .offset(x: position * step)
                    .opacity(max(0, 1 - pow(abs(position) / 2.7, 1.5)))
                    .zIndex(Double(4 - abs(position)))
                    .accessibilityHidden(abs(position) >= 2.7)
                    .accessibilityLabel(album ? L10n.format(distance == 0 ? "Open %@ album" : "Browse %@ album", item.title) : L10n.format(distance == 0 ? "Play %@ song" : "Browse %@ song", item.title))
                    .accessibilityIdentifier((album ? "musicAlbum-" : "musicSongCover-") + item.id)
                }
            }
        }
        .frame(width: max(0, width), height: max(0, height))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(album ? "musicAlbumCoverFlowSurface" : "musicSongCoverFlowSurface")
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.17),
                                   .init(color: .black, location: 0.83), .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.23),
                                   .init(color: .black, location: 0.77), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .contentShape(Rectangle())
        .modifier(MusicPageGestureRegion())
        .highPriorityGesture(DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.25 else { return }
                let delta = value.translation.width
                let atEdge = (index == 0 && delta > 0) || (index == items.count - 1 && delta < 0)
                albumDrag = min(step, max(-step, delta)) * (atEdge ? 0.22 : 1)
            }
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.25
                let delta = value.translation.width
                let advance = horizontal && (abs(delta) > max(36, step * 0.25) || abs(value.predictedEndTranslation.width) > step * 0.65)
                select(advance ? min(max(0, index + (delta < 0 ? 1 : -1)), max(0, items.count - 1)) : index)
            })
        .accessibilityAction(named: Text((album ? "Next album" : "Next song").tr)) { select(min(items.count - 1, index + 1)) }
        .accessibilityAction(named: Text((album ? "Previous album" : "Previous song").tr)) { select(max(0, index - 1)) }
    }

    private func songBrowser(size: CGSize) -> some View {
        VStack(spacing: 16) {
            libraryModes
            if store.library.isEmpty {
                Spacer(); Text("Your library has no available songs.".tr).foregroundStyle(.secondary); Spacer()
            } else if dynamicTypeSize.isAccessibilitySize {
                librarySongList.frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
                coverFlow(items: store.library.map { Cover(id: $0.id.rawValue, title: $0.title, artist: $0.artistName, artwork: $0.artwork) },
                          index: songIndex, width: min(size.width * 0.9, 940), height: min(380, size.height * 0.58), album: false,
                          select: moveToSong, open: playLibrarySong)
                HStack(spacing: 24) {
                    MusicSymbolButton(symbol: "chevron.left", label: "Previous song".tr, size: 20) { moveToSong(max(0, songIndex - 1)) }
                        .disabled(songIndex == 0).accessibilityIdentifier("musicPreviousSongCover")
                    VStack(spacing: 5) {
                        Text(currentSong?.title ?? "").font(.system(size: 22, weight: .medium)).lineLimit(2)
                        Text(currentSong?.artistName ?? "").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }.frame(maxWidth: 460)
                    MusicSymbolButton(symbol: "chevron.right", label: "Next song".tr, size: 20) { moveToSong(min(store.library.count - 1, songIndex + 1)) }
                        .disabled(songIndex >= store.library.count - 1).accessibilityIdentifier("musicNextSongCover")
                }
                MusicSymbolButton(symbol: "play.fill", label: "Play song".tr, size: 23, target: 58) { playLibrarySong(songIndex) }
                    .modifier(GlassSurface(radius: 29)).disabled(store.playingRequest)
                    .accessibilityIdentifier("musicPlayFocusedSong")
                Spacer(minLength: 0)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("musicSongCoverFlow")
    }

    private func moveToSong(_ index: Int) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.36, bounce: 0.12)) {
            if store.library.indices.contains(index) { navigation.songID = store.library[index].id }
            albumDrag = 0
        }
    }
    private func playLibrarySong(_ index: Int) {
        guard store.library.indices.contains(index) else { return }
        pendingSongID = store.library[index].id; pendingSongIndex = index; pendingQueueID = nil
        audio.stop(); store.play(store.library[index], from: store.library, catalog: false, startingIndex: index, source: .library)
        finishSelection()
    }

    @ViewBuilder private func albumDetail(size: CGSize) -> some View {
        if let album = store.selectedAlbum {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { VStack(spacing: 20) { albumOverview(album, side: 160); albumSongs } }
            } else {
                HStack(spacing: 36) {
                    albumOverview(album, side: min(300, size.width * 0.28, size.height * 0.55))
                        .frame(maxWidth: .infinity)
                    ScrollView { albumSongs }.frame(maxWidth: .infinity)
                }.padding(.vertical, 24)
            }
        } else { ProgressView() }
    }

    private func albumOverview(_ album: Album, side: CGFloat) -> some View {
        VStack(spacing: 14) {
            MusicArtwork(artwork: album.artwork, side: side)
            Text(album.title).font(.title2.weight(.medium)).multilineTextAlignment(.center)
            Text(album.artistName).foregroundStyle(.secondary).multilineTextAlignment(.center)
            collectionActions(songs: store.albumTracks, loading: store.albumLoading, prefix: "musicAlbum")
        }
    }

    private var albumSongs: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.albumLoading { ProgressView("Loading songs…".tr).padding(24) }
            else if store.albumTracks.isEmpty {
                Text((store.albumMessage ?? "This album has no available songs.").tr).foregroundStyle(.secondary).padding(.vertical, 24)
            }
            ForEach(Array(store.albumTracks.enumerated()), id: \.offset) { index, song in
                songRow(song, songs: store.albumTracks, catalog: false, number: index + 1, startingIndex: index)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("musicAlbumTracks")
    }

    private var playlistBrowser: some View {
        VStack(spacing: 12) {
            libraryModes
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text("Playlists".tr).font(.title2.weight(.medium)).padding(.vertical, 12)
                    if store.playlists.isEmpty {
                        Text((store.playlistListMessage ?? "Your library has no available playlists.").tr)
                            .foregroundStyle(.secondary).padding(.vertical, 24)
                        Button("Refresh library".tr) { store.refresh() }.buttonStyle(.bordered)
                    }
                    ForEach(store.playlists) { playlist in
                        Button { openPlaylist(playlist) } label: {
                            HStack(spacing: 16) {
                                MusicArtwork(artwork: playlist.artwork, side: 64, radius: 11)
                                Text(playlist.name).font(.headline).lineLimit(3)
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 76).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("musicPlaylist-\(playlist.id.rawValue)")
                            .modifier(MusicPageGestureRegion())
                    }
                }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("musicPlaylists")
        }
    }

    @ViewBuilder private func playlistDetail(size: CGSize) -> some View {
        if let playlist = store.selectedPlaylist {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { VStack(spacing: 20) { playlistOverview(playlist, side: 160); playlistSongs } }
            } else {
                HStack(spacing: 36) {
                    playlistOverview(playlist, side: min(300, size.width * 0.28, size.height * 0.5)).frame(maxWidth: .infinity)
                    ScrollView { playlistSongs }.frame(maxWidth: .infinity)
                }
            }
        } else { ProgressView("Loading songs…".tr) }
    }

    private func playlistOverview(_ playlist: Playlist, side: CGFloat) -> some View {
        VStack(spacing: 18) {
            MusicArtwork(artwork: playlist.artwork, side: side, radius: 18)
            Text(playlist.name).font(.title2.weight(.medium)).multilineTextAlignment(.center)
            collectionActions(songs: store.playlistTracks, loading: store.playlistLoading, prefix: "musicPlaylist")
        }
    }

    private var playlistSongs: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if store.playlistLoading { ProgressView("Loading songs…".tr).padding(24) }
            else if store.playlistTracks.isEmpty {
                Text((store.playlistMessage ?? "This playlist has no available songs.").tr).foregroundStyle(.secondary).padding(.vertical, 24)
            }
            ForEach(Array(store.playlistTracks.enumerated()), id: \.offset) { index, song in
                songRow(song, songs: store.playlistTracks, catalog: false, number: index + 1, startingIndex: index)
                    .accessibilityIdentifier("musicPlaylistSong-\(index)")
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("musicPlaylistTracks")
    }

    private func collectionActions(songs: [Song], loading: Bool, prefix: String) -> some View {
        HStack(spacing: 12) {
            Button { startCollection { store.playCollection(songs, source: selectionSource) } } label: {
                Label("Play all".tr, systemImage: "play.fill").frame(minHeight: 32)
            }.accessibilityIdentifier(prefix + "PlayAll")
        }.buttonStyle(.bordered).disabled(loading || songs.isEmpty || store.playingRequest)
            .modifier(MusicPageGestureRegion())
    }

    private var queueView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Playback queue".tr).font(.title2.weight(.medium))
                if store.queue.isEmpty { Text("The playback queue is empty.".tr).foregroundStyle(.secondary) }
                ForEach(store.queue) { entry in
                    Button {
                        pendingQueueID = entry.id; pendingSongID = nil
                        audio.stop(); store.playQueueEntry(entry); finishSelection()
                    } label: {
                        HStack(spacing: 14) {
                            MusicArtwork(artwork: entry.artwork, side: 48, radius: 9)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title).font(.headline).lineLimit(2)
                                Text(entry.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if pendingQueueID == entry.id { ProgressView().accessibilityIdentifier("musicSelectionPending") }
                            else if entry.isCurrent { Image(systemName: "waveform").foregroundStyle(.secondary) }
                        }.frame(minHeight: 64).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(store.playingRequest)
                        .accessibilityIdentifier("musicQueueEntry-\(entry.id)")
                        .modifier(MusicPageGestureRegion())
                    Divider().overlay(.white.opacity(0.1))
                }
            }.padding(.vertical, 24)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("musicQueueList")
    }

    private var librarySongList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.library) { song in songRow(song, songs: store.library, catalog: false) }
            }
        }.frame(maxHeight: 300)
    }

    private func songRow(_ song: Song, songs: [Song], catalog: Bool, number: Int? = nil, startingIndex: Int? = nil) -> some View {
        Button {
            pendingSongID = song.id; pendingSongIndex = startingIndex; pendingQueueID = nil; pendingCollection = false
            audio.stop(); store.play(song, from: songs, catalog: catalog, startingIndex: startingIndex, source: selectionSource); finishSelection()
        } label: {
            HStack(spacing: 14) {
                if let number { Text("\(number)").font(.subheadline).monospacedDigit().foregroundStyle(.secondary).frame(width: 22) }
                else { MusicArtwork(artwork: song.artwork, side: 48, radius: 9) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title).font(dynamicTypeSize.isAccessibilitySize ? .body : .system(size: 16, weight: .regular)).lineLimit(2)
                    if number == nil { Text(song.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 8)
                if pendingSongID == song.id && pendingSongIndex == startingIndex { ProgressView().accessibilityIdentifier("musicSelectionPending") }
                else if isCurrentOccurrence(song, songs: songs, index: startingIndex) { Image(systemName: store.nowPlaying?.playing == true ? "waveform" : "pause.fill").foregroundStyle(.secondary) }
                else if let duration = song.duration { Text(MusicTime.text(duration)).font(.caption).monospacedDigit().foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, minHeight: 64).contentShape(Rectangle())
            .overlay(alignment: .bottom) { Divider().overlay(.white.opacity(0.08)) }
        }
        .buttonStyle(.plain)
        .disabled(store.playingRequest || (catalog && store.subscription?.canPlayCatalog != true))
        .accessibilityIdentifier("musicSong-\(song.id.rawValue)")
        .modifier(MusicPageGestureRegion())
    }

    private func isCurrentOccurrence(_ song: Song, songs: [Song], index: Int?) -> Bool {
        guard store.nowPlaying?.id == song.id else { return false }
        if let index, songs.count == store.queue.count,
           zip(songs, store.queue).allSatisfy({ pair in pair.0.id == pair.1.songID }) {
            return store.queue.indices.contains(index) && store.queue[index].isCurrent
        }
        return songs.filter { $0.id == song.id }.count == 1
    }

    private var miniPlayer: some View {
        HStack(spacing: 12) {
            Button { show(.player) } label: {
                HStack(spacing: 12) {
                    MusicArtwork(artwork: store.nowPlaying?.artwork, side: 42, radius: 9)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.nowPlaying?.title ?? "").font(dynamicTypeSize.isAccessibilitySize ? .headline : .system(size: 14, weight: .medium)).lineLimit(1)
                        Text(store.nowPlaying?.artist ?? "").font(dynamicTypeSize.isAccessibilitySize ? .subheadline : .system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Now playing".tr)
                .accessibilityValue([store.nowPlaying?.title, store.nowPlaying?.artist].compactMap { $0 }.joined(separator: ", "))
                .accessibilityIdentifier("musicMiniPlayer")
            MusicSymbolButton(symbol: "shuffle", label: "Shuffle queue".tr, size: 19) { startCollection { store.shuffleQueue() } }
                .disabled(!store.canShuffleQueue).accessibilityIdentifier(screen == .queue ? "musicQueueShuffle" : "musicMiniShuffle")
            MusicSymbolButton(symbol: "backward.fill", label: "Previous song".tr, size: 21) { audio.stop(); store.skipPrevious() }
                .disabled(!store.canSkipPrevious || store.playingRequest).accessibilityIdentifier("musicMiniPrevious")
            MusicSymbolButton(symbol: store.nowPlaying?.playing == true ? "pause.fill" : "play.fill",
                              label: (store.nowPlaying?.playing == true ? "Pause" : "Play").tr, size: 21, busy: store.playingRequest) {
                audio.stop(); store.togglePlayback()
            }.disabled(store.playingRequest).accessibilityIdentifier("musicMiniPlayback")
            MusicSymbolButton(symbol: "forward.fill", label: "Next song".tr, size: 21) { audio.stop(); store.skipNext() }
                .disabled(!store.canSkipNext || store.playingRequest).accessibilityIdentifier("musicMiniNext")
        }
        .padding(8).padding(.trailing, 4).frame(maxWidth: 900)
        .modifier(GlassSurface(radius: 20))
        .modifier(MusicPageGestureRegion())
    }

    private var disconnectedContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "music.note").font(.system(size: 70, weight: .light)).padding(.top, 12).accessibilityHidden(true)
                connectionCard
                fileSection
            }.frame(maxWidth: 760).padding(.vertical, 24).frame(maxWidth: .infinity)
        }
    }

    private var connectionCard: some View {
        connectionDetails.frame(maxWidth: .infinity, alignment: .leading).padding(24).modifier(GlassSurface(radius: 28))
    }
    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apple Music").font(.title2.weight(.medium))
            if demo {
                Text("Leave demo mode to connect Apple Music.".tr).foregroundStyle(.secondary)
            } else {
                switch store.state {
                case .disconnected:
                    Text("Connect to browse your music library and play songs here.".tr).foregroundStyle(.secondary)
                    connectButton
                case .connecting:
                    ProgressView("Connecting to Apple Music…".tr)
                    Button("Cancel".tr) { store.disconnect() }.accessibilityIdentifier("cancelMusicConnection")
                case .denied:
                    Text("Music access is off. Allow Media & Apple Music in iPad Settings, then return here.".tr).foregroundStyle(.secondary)
                    Button("Open iPad Settings".tr) { openSettings() }.accessibilityIdentifier("musicSettings")
                    connectButton
                case .restricted:
                    Text("Music access is restricted by this iPad’s settings.".tr).foregroundStyle(.secondary)
                case .unavailable:
                    Text((store.message ?? "Apple Music is unavailable. Check your account and connection, then try again.").tr).foregroundStyle(.secondary)
                    Button("Try again".tr) { store.refresh() }.accessibilityIdentifier("retryMusicConnection")
                    Button("Open Music".tr) { openMusic() }
                case .ready:
                    Label("Apple Music connected".tr, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    if store.subscription?.canPlayCatalog == true {
                        Text("Apple Music subscription active".tr).foregroundStyle(.secondary)
                    } else {
                        Text("Catalog playback requires an Apple Music subscription. Available library songs and audio files can still be played.".tr).foregroundStyle(.secondary)
                        Button("Open Music".tr) { openMusic() }
                    }
                    HStack {
                        Button("Refresh library".tr) { store.refresh() }.accessibilityIdentifier("refreshMusicLibrary")
                        Spacer()
                        Button("Disconnect".tr, role: .destructive) { store.disconnect() }.accessibilityIdentifier("disconnectMusic")
                    }.buttonStyle(.plain)
                }
                if let detail = store.detail {
                    DisclosureGroup("Connection details".tr) { Text(detail).font(.footnote).textSelection(.enabled) }.font(.footnote)
                }
            }
            Text("Music permission is requested only when you connect. Song lists stay on this iPad; music requests and playback use Apple’s services.".tr)
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectButton: some View {
        Button("Connect Apple Music".tr) { store.connect() }
            .buttonStyle(.borderedProminent).accessibilityIdentifier("connectAppleMusic")
    }

    private var fileSection: some View { fileDetails.padding(24).modifier(GlassSurface(radius: 28)) }
    private var fileDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Audio files".tr, systemImage: "doc.badge.waveform").font(.headline)
                Spacer()
                Button("Choose audio file".tr) { importAudio = true }.buttonStyle(.bordered)
                    .disabled(demo).accessibilityIdentifier("chooseAudioFile")
            }
            if audio.hasFile {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(audio.title).font(.headline)
                        Text(audio.message.tr).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button((audio.playing ? "Pause" : "Play").tr) { store.pause(); audio.toggle() }
                        .buttonStyle(.bordered).accessibilityIdentifier("audioFilePlayback")
                }
            } else {
                Text("Play a downloaded audio file without connecting Apple Music.".tr).font(.subheadline).foregroundStyle(.secondary)
                if audio.message != "Choose an audio file, then select your HomePod with AirPlay." {
                    Text(audio.message.tr).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text("Choose a speaker with AirPlay. HomePad plays on this iPad and does not control a HomePod’s separate playback or Siri.".tr)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func returnToAlbumBrowser() {
        var source = store.playbackSource
        // Resolve a known native song only to focus an unambiguous album card.
        // This never opens detail/queue screens or requests additional data.
        switch source {
        case .album: break
        default:
            if let id = store.nowPlaying?.id,
               let song = store.library.first(where: { $0.id == id }), let name = song.albumTitle {
                let matches = store.albums.filter { $0.title == name && $0.artistName == song.artistName }
                if matches.count == 1 { source = .album(matches[0].id) }
            }
        }
        leaveCurrentScreen()
        withAnimation(transitionAnimation) {
            navigation.returnToAlbumBrowser(source, currentSongID: store.nowPlaying?.id)
        }
        restoreBrowsing()
    }

    private func leadingAction() {
        if screen == .player { returnToAlbumBrowser(); return }
        leaveCurrentScreen()
        withAnimation(transitionAnimation) { navigation.back() }
        restoreBrowsing()
    }
    private var transitionAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.25) }
    private var screenTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .offset(x: navigation.forward ? 36 : -36).combined(with: .opacity),
                           removal: .offset(x: navigation.forward ? -36 : 36).combined(with: .opacity))
    }
    private func leaveCurrentScreen() {
        pendingSongID = nil; pendingQueueID = nil; pendingCollection = false
        if screen == .playlistTracks { store.closePlaylist() }
        if screen == .tracks { store.closeAlbum() }
    }
    private func show(_ destination: Screen) {
        guard destination != screen else { return }
        leaveCurrentScreen()
        withAnimation(transitionAnimation) { navigation.show(destination) }
    }
    private func restoreBrowsing() {
        guard ready else { return }
        if !store.library.contains(where: { $0.id == navigation.songID }) { navigation.songID = store.library.first?.id }
        if !store.albums.contains(where: { $0.id == navigation.albumID }) {
            navigation.albumID = store.albums.first?.id
            if screen == .tracks { show(.albums) }
        }
        if screen == .tracks, store.selectedAlbum == nil, let album = currentAlbum { store.selectAlbum(album) }
        if !store.playlists.contains(where: { $0.id == navigation.playlistID }) {
            navigation.playlistID = nil
            if screen == .playlistTracks { show(.playlists) }
        }
        if screen == .playlistTracks, store.selectedPlaylist == nil,
           let playlist = store.playlists.first(where: { $0.id == navigation.playlistID }) { store.selectPlaylist(playlist) }
    }
    private func finishSelection() {
        guard !store.playingRequest else { return }
        if store.message != nil { pendingSongID = nil; pendingQueueID = nil; pendingCollection = false; return }
        let songReady = pendingSongID != nil && store.nowPlaying?.id == pendingSongID && (pendingSongIndex == nil || store.queue.firstIndex(where: \.isCurrent) == pendingSongIndex)
        let queueReady = pendingQueueID != nil && store.queue.first(where: \.isCurrent)?.id == pendingQueueID
        if songReady || queueReady || (pendingCollection && store.nowPlaying?.playing == true) {
            // Playback is independent of browsing. Only the mini player opens
            // the full player; a completed request never steals navigation.
            pendingSongID = nil; pendingSongIndex = nil; pendingQueueID = nil; pendingCollection = false
        }
    }
    private func startCollection(_ action: () -> Void) {
        pendingCollection = true; pendingSongID = nil; pendingQueueID = nil
        audio.stop(); action(); finishSelection()
    }
    private func openPlaylist(_ playlist: Playlist) {
        navigation.playlistID = playlist.id
        show(.playlistTracks)
        store.selectPlaylist(playlist)
    }
    private func openAlbum(_ album: Album) {
        navigation.albumID = album.id
        show(.tracks)
        store.selectAlbum(album)
    }
    private func browse(_ delta: Int) { moveToAlbum(min(max(0, albumIndex + delta), max(0, store.albums.count - 1))) }
    private func moveToAlbum(_ index: Int) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.36, bounce: 0.12)) {
            if store.albums.indices.contains(index) { navigation.albumID = store.albums[index].id }
            albumDrag = 0
        }
    }
    private func reportPresentation() { presentationChanged(options || importAudio || output) }
    private func swipePage(_ translation: CGSize) {
        guard !options, !output, !importAudio else { return }
        switch DashboardSwipe.classify(x: translation.width, y: translation.height) {
        case .left: changePage(true)
        case .right: changePage(false)
        default: break
        }
    }
    private func openSettings() { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
    private func openMusic() { if let url = URL(string: "https://music.apple.com/") { openURL(url) } }
}

struct MusicPageBackdrop: View {
    let artwork: Artwork?
    let trackID: MusicItemID?
    var fixture = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var loadedURL: URL?
    private var artworkURL: URL? { artwork?.url(width: 512, height: 512) }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.13, green: 0.10, blue: 0.15)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .blur(radius: 65).opacity(0.45)
                        .id(loadedURL).transition(.opacity)
                } else if fixture, trackID != nil {
                    // Original deterministic colors, only for visibly labeled
                    // TEST DATA. Never used as a missing real artwork fallback.
                    let tint = (trackID?.rawValue.utf8.reduce(0) { $0 + Int($1) } ?? 0) % 2 == 0
                    LinearGradient(colors: tint ? [.purple, .pink.opacity(0.7), .indigo] : [.teal, .blue.opacity(0.8), .purple],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .blur(radius: 55).opacity(0.55).id(trackID).transition(.opacity)
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: trackID)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: loadedURL)
        }.ignoresSafeArea().accessibilityHidden(true)
            .task(id: artworkURL) {
                guard let url = artworkURL else { image = nil; loadedURL = nil; return }
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                    let decoded = await Task.detached(priority: .utility) { Self.decode(data) }.value
                    guard !Task.isCancelled else { return }
                    image = decoded; loadedURL = url
                } catch {
                    guard !Task.isCancelled else { return }
                    image = nil; loadedURL = nil
                }
            }
    }
    nonisolated private static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: 512
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}

private struct MusicVolumeControl: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        view.tintColor = .white
        view.backgroundColor = .clear
        view.accessibilityLabel = "Volume".tr
        view.accessibilityIdentifier = "musicSystemVolumeControl"
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
