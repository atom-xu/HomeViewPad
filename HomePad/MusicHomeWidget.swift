import SwiftUI
import MusicKit

/// Decorative playback artwork never replaces the independent photo wall or
/// the Overview's opaque black composition, and never changes saved wallpaper.
enum MusicArtworkBackdropPolicy {
    static func shows(on page: DashboardPage, enabled: Bool, playing: Bool, hasArtwork: Bool, localFileSelected: Bool) -> Bool {
        enabled && playing && hasArtwork && !localFileSelected && (page == .home || page == .clock)
    }
}

/// The Home card observes the Dashboard's single MusicStore. It never requests
/// permission, creates a player, or fills an unavailable account with examples.
struct MusicHomeWidget: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: MusicStore
    @ObservedObject var audio: AudioStore
    let demo: Bool
    let width: CGFloat
    let height: CGFloat
    var airPlayPresentationChanged: (Bool) -> Void = { _ in }
    let open: () -> Void
    @AppStorage("musicArtworkBackground") private var musicArtworkBackground = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var artworkVisible: Bool {
        MusicArtworkBackdropPolicy.shows(on: .home, enabled: musicArtworkBackground && !demo,
                                         playing: store.nowPlaying?.playing == true,
                                         hasArtwork: store.nowPlaying?.artwork != nil || (store.isValidationFixture && store.nowPlaying != nil),
                                         localFileSelected: fileSelected)
    }
    private var fileSelected: Bool { !demo && audio.hasFile }
    private var hasPlayback: Bool { !demo && (store.nowPlaying != nil || fileSelected) }
    private var playing: Bool { fileSelected ? audio.playing : store.nowPlaying?.playing == true }
    private var title: String {
        if demo { return "No music is connected".tr }
        if fileSelected { return audio.title }
        return store.nowPlaying?.title ?? "Choose your music".tr
    }
    private var subtitle: String {
        if demo { return "DEMO".tr }
        if fileSelected { return "Audio files".tr }
        return store.nowPlaying?.artist ?? store.statusTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Button(action: open) {
                    HStack(spacing: 12) {
                        MusicArtwork(artwork: demo || fileSelected ? nil : store.nowPlaying?.artwork, side: 62, radius: 11)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(dynamicTypeSize.isAccessibilitySize ? .title3.weight(.medium) : .system(size: 20, weight: .medium))
                                .lineLimit(1).accessibilityIdentifier("homeMusicTitle")
                            Text(subtitle)
                                .font(dynamicTypeSize.isAccessibilitySize ? .caption : .system(size: 13))
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open music player".tr)
                .accessibilityValue([title, subtitle].joined(separator: ", "))
                .accessibilityIdentifier("homeMusicOpen")
                AirPlayPicker(lightControls: true, presentationChanged: airPlayPresentationChanged).frame(width: 44, height: 44).accessibilityIdentifier("homeMusicAirPlay")
            }
            Spacer(minLength: 8)
            if !demo && !fileSelected, let value = store.nowPlaying {
                MusicPlaybackProgress(store: store, value: value, compact: true, identifier: "homeMusicSeek")
            } else {
                Capsule().fill(.primary.opacity(0.18)).frame(height: 3).accessibilityHidden(true)
                Text(demo ? "Leave demo mode to connect Apple Music.".tr : fileSelected ? "Audio files".tr : store.statusTitle)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
            }
            Spacer(minLength: 3)
            HStack(spacing: 12) {
                MusicSymbolButton(symbol: "shuffle", label: "Shuffle queue".tr, size: 19, target: 44) {
                    audio.stop(); store.shuffleQueue()
                }.disabled(demo || fileSelected || !store.canShuffleQueue).accessibilityIdentifier("homeMusicShuffle")
                MusicSymbolButton(symbol: "backward.fill", label: "Previous song".tr, size: 25) {
                    audio.stop(); store.skipPrevious()
                }
                .disabled(demo || fileSelected || !store.canSkipPrevious || store.playingRequest)
                .accessibilityIdentifier("homeMusicPrevious")
                MusicSymbolButton(symbol: playing ? "pause.fill" : "play.fill", label: (playing ? "Pause" : "Play").tr, size: 29, target: 48, busy: store.playingRequest) {
                    if fileSelected { store.pause(); audio.toggle() }
                    else { audio.stop(); store.togglePlayback() }
                }
                .disabled(!hasPlayback || store.playingRequest)
                .accessibilityIdentifier("homeMusicPlayback")
                MusicSymbolButton(symbol: "forward.fill", label: "Next song".tr, size: 25) {
                    audio.stop(); store.skipNext()
                }
                .disabled(demo || fileSelected || !store.canSkipNext || store.playingRequest)
                .accessibilityIdentifier("homeMusicNext")
            }
            .frame(maxWidth: .infinity)
            MusicValidationLabel().padding(.top, 2)
        }
        .padding(18)
        .frame(width: width, height: height)
        .background {
            if artworkVisible {
                MusicPageBackdrop(artwork: store.nowPlaying?.artwork, trackID: store.nowPlaying?.id, fixture: store.isValidationFixture)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: artworkVisible)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .modifier(GlassSurface(radius: 26))
        .environment(\.colorScheme, artworkVisible ? .dark : colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeMusicWidget")
    }
}

struct MusicArtwork: View {
    let artwork: Artwork?
    let side: CGFloat
    var radius: CGFloat = 16
    var body: some View {
        Group {
            if let artwork {
                ArtworkImage(artwork, width: side, height: side)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: radius).fill(.primary.opacity(0.08))
                    Image(systemName: "music.note").font(.system(size: max(20, side * 0.22), weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct MusicSymbolButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 20
    var target: CGFloat = 44
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                if busy { ProgressView().accessibilityLabel("Loading songs…".tr) }
                else { Image(systemName: symbol).font(.system(size: size, weight: .regular)) }
            }
                .frame(width: target, height: target)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct MusicPlaybackProgress: View {
    @ObservedObject var store: MusicStore
    @ObservedObject private var playhead: MusicPlaybackPosition
    let value: MusicNowPlaying
    var compact = false
    var identifier = "musicSeek"
    @State private var draft: Double?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    init(store: MusicStore, value: MusicNowPlaying, compact: Bool = false, identifier: String = "musicSeek") {
        self.store = store; self.value = value; self.compact = compact; self.identifier = identifier
        _playhead = ObservedObject(wrappedValue: store.playbackPosition)
    }
    private var duration: Double { max(0, value.duration ?? 0) }
    private var position: Double { min(max(0, draft ?? playhead.position), duration) }

    var body: some View {
        VStack(spacing: compact ? 0 : 2) {
            Slider(value: Binding(get: { position }, set: { draft = $0 }), in: 0...max(1, duration), onEditingChanged: { editing in
                if !editing, let target = draft { store.seek(to: target); draft = nil }
            })
            .tint(.white)
            .disabled(!store.canSeek || store.playingRequest)
            .accessibilityLabel("Playback position".tr)
            .accessibilityValue(duration > 0 ? "\(MusicTime.text(position)) / \(MusicTime.text(duration))" : "Duration unavailable".tr)
            .accessibilityIdentifier(identifier)
            HStack {
                Text(duration > 0 ? MusicTime.text(position) : "—:—")
                Spacer()
                Text(duration > 0 ? "−" + MusicTime.text(max(0, duration - position)) : "—:—")
            }
            .font(dynamicTypeSize.isAccessibilitySize ? .caption2 : .system(size: compact ? 11 : 12))
            .monospacedDigit().foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
        .onChange(of: value.id) { _, _ in draft = nil }
        .onChange(of: store.canSeek) { _, available in if !available { draft = nil } }
    }
}

enum MusicTime {
    static func text(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—:—" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Synthetic account fixtures are available only to the separate UI test run.
/// Shipping account data and the deterministic, disconnected demo never use them.
struct MusicValidationLabel: View {
    private var visible: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--uitesting") && args.contains("--music-fixture")
        #else
        return false
        #endif
    }
    var body: some View {
        if visible {
            Text("TEST DATA".tr).font(.caption2.bold()).padding(.horizontal, 7).padding(.vertical, 3)
                .background(.yellow.opacity(0.25), in: Capsule())
                .accessibilityIdentifier("musicValidationData")
        }
    }
}
