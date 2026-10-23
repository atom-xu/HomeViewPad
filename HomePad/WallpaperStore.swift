import SwiftUI
import PhotosUI
import ImageIO
import CryptoKit

/// A single, explicitly selected image, separate from the photo wall and albums.
@MainActor final class WallpaperStore: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var imageID = ""
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    private let fileURL: URL
    private var generation = UUID()
    // Tests compare image identity without making VoiceOver read a checksum.
    var accessibilityValue: String {
        ProcessInfo.processInfo.arguments.contains("--uitesting") ? imageID : "Photo wallpaper".tr
    }

    init(fileURL: URL = URL.documentsDirectory.appending(path: "background-wallpaper.jpg")) {
        self.fileURL = fileURL
    }

    func restore() async {
        let token = generation
        let url = fileURL
        let restored = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url), let image = Self.decode(data) else { return nil as Decoded? }
            return Decoded(image: image, jpeg: data)
        }.value
        guard generation == token, !Task.isCancelled, let restored else { return }
        image = restored.image
        imageID = Self.identifier(restored.jpeg)
    }

    func importPhoto(_ item: PhotosPickerItem) async {
        await importImage { try await item.loadTransferable(type: Data.self) }
    }

    // Loading is injectable so late responses, cancellation and file errors can
    // be checked without granting a test access to the user's photo library.
    func importImage(loadData: () async throws -> Data?) async {
        let token = UUID(); generation = token; loading = true; message = nil
        do {
            guard let data = try await loadData() else { throw CocoaError(.fileReadCorruptFile) }
            try Task.checkCancellation()
            let decoded = await Task.detached(priority: .userInitiated) {
                guard let image = Self.decode(data), let jpeg = image.jpegData(compressionQuality: 0.9) else { return nil as Decoded? }
                return Decoded(image: image, jpeg: jpeg)
            }.value
            try Task.checkCancellation()
            guard generation == token else { return }
            guard let decoded else { throw CocoaError(.fileReadCorruptFile) }
            try decoded.jpeg.write(to: fileURL, options: .atomic)
            image = decoded.image; imageID = Self.identifier(decoded.jpeg); loading = false
        } catch {
            guard generation == token else { return }
            loading = false
            if !Task.isCancelled { message = "This wallpaper could not be loaded or saved. Your previous background is unchanged. Please try another photo." }
        }
    }

    func clear() {
        generation = UUID(); loading = false; message = nil
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            image = nil; imageID = ""
        } catch {
            message = "This wallpaper could not be removed. Please try again."
        }
    }

    private struct Decoded {
        let image: UIImage
        let jpeg: Data
    }
    nonisolated private static func identifier(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    nonisolated private static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: 3072
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}

struct WallpaperSettings: View {
    @ObservedObject var wallpaper: WallpaperStore
    @Binding var isPresented: Bool
    var body: some View {
        Section("Home & Clock background photo".tr) {
            if let image = wallpaper.image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(height: 100).frame(maxWidth: .infinity).clipped()
                    .accessibilityLabel("Selected wallpaper".tr)
                    .accessibilityValue(wallpaper.accessibilityValue).accessibilityIdentifier("wallpaperPreview")
            }
            Text((wallpaper.image == nil ? "Using a default background color" : "Using your background photo").tr)
                .foregroundStyle(.secondary).accessibilityIdentifier("wallpaperStatus")
            Button { isPresented = true } label: {
                Label("Choose a background photo".tr, systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Color.accentColor).accessibilityIdentifier("chooseWallpaper")
            if wallpaper.loading { ProgressView("Loading wallpaper…".tr).accessibilityIdentifier("wallpaperLoading") }
            if let message = wallpaper.message { Text(message.tr).foregroundStyle(.secondary).accessibilityIdentifier("wallpaperError") }
            if wallpaper.image != nil || wallpaper.loading {
                Button(role: .destructive) { wallpaper.clear() } label: {
                    Text("Remove background photo".tr).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(.red).accessibilityIdentifier("removeWallpaper")
            }
            Text("Fills Home and Clock and may crop the edges. A copy stays on this iPad. The independent Photos page and photo wall keep their own selection. This does not change or follow iPad's system wallpaper.".tr)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
