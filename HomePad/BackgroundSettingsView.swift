import SwiftUI
import AVFoundation

struct AerialWallpaperView: View {
    @ObservedObject var aerial: AerialStore
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = aerial.poster {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                if let player = aerial.player { AerialPlayerLayer(player: player) }
                Color.black.opacity(0.12)
                if aerial.isValidationFixture {
                    VStack { Spacer(); Text("TEST DATA · AERIAL".tr).font(.caption.bold()).padding(10)
                        .background(.black.opacity(0.7), in: Capsule()).padding(20) }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Apple Aerial".tr)
        .accessibilityValue((aerial.currentClip?.name.tr ?? "") + " · " + aerial.playbackState.tr)
        .accessibilityIdentifier("aerialWallpaper")
        .allowsHitTesting(false)
    }
}

private struct AerialPlayerLayer: UIViewRepresentable {
    let player: AVQueuePlayer
    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    func makeUIView(context: Context) -> Surface {
        let view = Surface(); view.isUserInteractionEnabled = false
        view.videoLayer.videoGravity = .resizeAspectFill
        view.videoLayer.player = player
        return view
    }
    func updateUIView(_ view: Surface, context: Context) { view.videoLayer.player = player }
    static func dismantleUIView(_ view: Surface, coordinator: ()) { view.videoLayer.player = nil }
}

/// A dedicated, Mac-style gallery: compact preview and fixed-ratio grouped tiles.
struct BackgroundSettingsView: View {
    @ObservedObject var wallpaper: WallpaperStore
    @ObservedObject var aerial: AerialStore
    @Binding var teal: Bool
    @Binding var photoPickerPresented: Bool
    var previewStandby: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 280 : 180,
                            maximum: typeSize.isAccessibilitySize ? 360 : 250), spacing: 20, alignment: .top)]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    currentBackground
                    photoGallery
                    colorGallery
                    aerialGallery
                }.padding(typeSize.isAccessibilitySize ? 24 : 32)
                    .frame(maxWidth: 1_440, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)
            }.accessibilityIdentifier("wallpaperGalleryScroll")
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityElement(children: .contain).accessibilityIdentifier("settingsWallpaperPage")
    }

    @ViewBuilder private var currentBackground: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 24) { preview.frame(maxWidth: 360); currentInformation }
        } else {
            HStack(alignment: .center, spacing: 28) {
                preview.frame(width: 320)
                currentInformation
                Spacer(minLength: 0)
            }
        }
    }

    private var preview: some View {
        GeometryReader { geometry in
            ZStack {
                if aerial.enabled, let image = aerial.poster {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else if let image = wallpaper.image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else { AmbientWallpaper(teal: teal) }
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 4) {
                    Text("10:09").font(.system(size: 44, weight: .ultraLight, design: .rounded)).monospacedDigit()
                    Text("Preview".tr).font(.caption)
                }.foregroundStyle(.white).accessibilityHidden(true)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.aspectRatio(16 / 10, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.08), lineWidth: 1) }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore).accessibilityLabel("Background preview".tr)
            .accessibilityValue(currentTitle).accessibilityIdentifier("backgroundPreview")
    }

    private var currentInformation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(currentTitle).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("backgroundCurrentTitle")
            Text("Home · Clock · Standby".tr).font(.subheadline).foregroundStyle(.secondary)
            Button(action: previewStandby) { Label("Preview screen saver".tr, systemImage: "play.rectangle") }
                .buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("standbyPreview")
            if aerial.isValidationFixture && aerial.enabled {
                Text("TEST DATA · AERIAL".tr).font(.caption.bold()).foregroundStyle(.orange)
            }
            if reducedMotion && aerial.enabled {
                Text("Reduce Motion is on. Aerials use a still image.".tr).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var currentTitle: String {
        if aerial.enabled {
            return (aerial.shuffling ? "Shuffle aerials".tr + " · " : "") + (aerial.currentClip?.name.tr ?? "Apple Aerial".tr)
        }
        return wallpaper.image != nil ? "Your photo".tr : (teal ? "Teal".tr : "Warm gray".tr)
    }

    private var photoGallery: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your photos".tr).font(.title3.weight(.semibold))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                Button { photoPickerPresented = true } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.07))
                            .aspectRatio(16 / 10, contentMode: .fit)
                            .overlay { Image(systemName: "plus.circle.fill").font(.system(size: 32)).foregroundStyle(Color.accentColor) }
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.15), lineWidth: 1) }
                        Text("Choose a background photo".tr).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("chooseWallpaper")
                if let image = wallpaper.image { savedPhoto(image) }
            }.accessibilityElement(children: .contain)
            if wallpaper.loading { ProgressView("Loading wallpaper…".tr).accessibilityIdentifier("wallpaperLoading") }
            if let message = wallpaper.message { Text(message.tr).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("wallpaperError") }
            HStack(alignment: .firstTextBaseline) {
                Text((aerial.enabled ? "Choose a photo to replace the aerial background." : wallpaper.image == nil ? "Using a default background color" : "Using your background photo").tr)
                    .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("wallpaperStatus")
                Spacer(minLength: 12)
                if wallpaper.image != nil || wallpaper.loading {
                    Button(role: .destructive) { wallpaper.clear() } label: { Label("Remove background photo".tr, systemImage: "trash") }
                        .buttonStyle(.bordered).accessibilityIdentifier("removeWallpaper")
                }
            }
        }
    }

    private func savedPhoto(_ image: UIImage) -> some View {
        let selected = !aerial.enabled
        return Button { wallpaper.cancelImport(); aerial.useStaticBackground() } label: {
            VStack(alignment: .leading, spacing: 9) {
                GeometryReader { geometry in
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }.aspectRatio(16 / 10, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay { selectedBorder(selected) }
                Text("Your photo".tr).font(.subheadline.weight(.medium))
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Your photo".tr).accessibilityValue(wallpaper.accessibilityValue)
            .accessibilityAddTraits(selected ? .isSelected : []).accessibilityRemoveTraits(selected ? [] : .isSelected)
            .accessibilityIdentifier("wallpaperPhotoSaved")
    }

    private var colorGallery: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colors".tr).font(.title3.weight(.semibold))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                colorChoice(false, title: "Warm gray", id: "wallpaperDefault-warmGray")
                colorChoice(true, title: "Teal", id: "wallpaperDefault-teal")
            }.accessibilityElement(children: .contain).accessibilityIdentifier("tealWallpaper")
        }
    }

    private func colorChoice(_ value: Bool, title: String, id: String) -> some View {
        let selected = !aerial.enabled && wallpaper.image == nil && teal == value
        return Button {
            teal = value; wallpaper.clear(); aerial.useStaticBackground()
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                AmbientWallpaper(teal: value).aspectRatio(16 / 10, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay { selectedBorder(selected) }
                Text(title.tr).font(.subheadline.weight(.medium))
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(selected ? "Selected".tr : "")
            .accessibilityAddTraits(selected ? .isSelected : []).accessibilityRemoveTraits(selected ? [] : .isSelected).accessibilityIdentifier(id)
    }

    private var aerialGallery: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Apple Aerial".tr).font(.title3.weight(.semibold))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { shuffleButton; if aerial.shuffling { intervalMenu } }
                    VStack(alignment: .leading, spacing: 12) { shuffleButton; if aerial.shuffling { intervalMenu } }
                }
                Text(L10n.format("%d downloaded", aerial.downloaded.count)).font(.footnote).foregroundStyle(.secondary)
            }
            if aerial.isValidationFixture { Text("TEST DATA · AERIAL".tr).font(.caption.bold()).foregroundStyle(.orange) }
            if let id = aerial.downloadingID { downloadProgress(id) }
            if let message = aerial.message { Text(message.tr).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("aerialError") }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                ForEach(aerial.clips) { clip in aerialTile(clip) }
            }.accessibilityElement(children: .contain)
            Text("Apple's original Aerial videos download over Wi-Fi when selected, then play offline without sound. Shuffle uses only downloaded aerials. Touch the idle clock once to return.".tr)
                .font(.footnote).foregroundStyle(.secondary)
            Text("Downloaded storage".tr + ": " + ByteCountFormatter.string(fromByteCount: aerial.cacheBytes, countStyle: .file))
                .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("aerialCacheSize")
            Text("Fills Home and Clock and may crop the edges. A copy stays on this iPad. The independent Photos page and photo wall keep their own selection. This does not change or follow iPad's system wallpaper.".tr)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var shuffleButton: some View {
        Button { wallpaper.cancelImport(); aerial.chooseShuffle() } label: {
            Label("Shuffle downloaded aerials".tr, systemImage: "shuffle").fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(.bordered).controlSize(.large).disabled(aerial.downloaded.isEmpty)
            .tint(aerial.shuffling ? .accentColor : .secondary)
            .accessibilityAddTraits(aerial.shuffling ? .isSelected : []).accessibilityRemoveTraits(aerial.shuffling ? [] : .isSelected)
            .accessibilityIdentifier("aerialShuffle")
    }

    private var intervalMenu: some View {
        Menu {
            Button("1 minute".tr) { aerial.setShuffleInterval(60) }
            Button("5 minutes".tr) { aerial.setShuffleInterval(300) }
            Button("15 minutes".tr) { aerial.setShuffleInterval(900) }
        } label: { Label(intervalTitle, systemImage: "clock.arrow.2.circlepath").padding(.horizontal, 8).frame(minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(.bordered).accessibilityLabel("Change aerial every".tr)
            .accessibilityValue(intervalTitle).accessibilityIdentifier("aerialShuffleInterval")
    }
    private var intervalTitle: String { (aerial.shuffleInterval == 60 ? "1 minute" : aerial.shuffleInterval == 900 ? "15 minutes" : "5 minutes").tr }

    private func downloadProgress(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text((aerial.clips.first { $0.id == id }?.name ?? "Apple Aerial").tr).font(.subheadline.weight(.medium))
            if let progress = aerial.progress { ProgressView(value: progress).frame(maxWidth: 360) } else { ProgressView() }
            Button("Cancel download".tr) { aerial.cancelDownload() }
                .buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("aerialCancelDownload")
        }.padding(16).frame(maxWidth: 520, alignment: .leading)
            .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain).accessibilityIdentifier("aerialDownloadProgress")
    }

    private func aerialTile(_ clip: AerialClip) -> some View {
        let selected = aerial.enabled && !aerial.shuffling && aerial.currentID == clip.id
        return Button { wallpaper.cancelImport(); aerial.choose(clip) } label: {
            VStack(alignment: .leading, spacing: 9) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = aerial.thumbnail(clip.id) { Image(uiImage: image).resizable().scaledToFill() }
                            else if aerial.isValidationFixture { AmbientWallpaper(teal: clip.id != aerial.clips.first?.id) }
                            else {
                                AsyncImage(url: clip.previewURL) { image in image.resizable().scaledToFill() } placeholder: {
                                    Color(white: 0.15).overlay { Image(systemName: "mountain.2").foregroundStyle(.white.opacity(0.5)) }
                                }
                            }
                        }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        if selected || !aerial.downloaded.contains(clip.id) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                .font(.title3).symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.5)).padding(8)
                        }
                    }
                }.aspectRatio(16 / 10, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay { selectedBorder(selected) }
                Text(clip.name.tr).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Text((aerial.downloaded.contains(clip.id) ? "Downloaded" : "Download & use").tr).font(.caption).foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(clip.name.tr)
            .accessibilityValue((selected ? "Selected" : aerial.downloaded.contains(clip.id) ? "Downloaded" : "Download & use").tr)
            .accessibilityAddTraits(selected ? .isSelected : []).accessibilityRemoveTraits(selected ? [] : .isSelected)
            .accessibilityIdentifier("aerial-\(clip.id)")
            .contextMenu {
                if aerial.downloaded.contains(clip.id) { Button("Remove download".tr, role: .destructive) { aerial.remove(clip) } }
            }
    }

    private func selectedBorder(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.accentColor : .primary.opacity(0.08), lineWidth: selected ? 3 : 1)
    }
}
