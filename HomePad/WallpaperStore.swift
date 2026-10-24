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

    @discardableResult func importPhoto(_ item: PhotosPickerItem) async -> Bool {
        await importImage { try await item.loadTransferable(type: Data.self) }
    }

    // Loading is injectable so late responses, cancellation and file errors can
    // be checked without granting a test access to the user's photo library.
    @discardableResult func importImage(loadData: () async throws -> Data?) async -> Bool {
        let token = UUID(); generation = token; loading = true; message = nil
        do {
            guard let data = try await loadData() else { throw CocoaError(.fileReadCorruptFile) }
            try Task.checkCancellation()
            let decoded = await Task.detached(priority: .userInitiated) {
                guard let image = Self.decode(data), let jpeg = image.jpegData(compressionQuality: 0.9) else { return nil as Decoded? }
                return Decoded(image: image, jpeg: jpeg)
            }.value
            try Task.checkCancellation()
            guard generation == token else { return false }
            guard let decoded else { throw CocoaError(.fileReadCorruptFile) }
            try decoded.jpeg.write(to: fileURL, options: .atomic)
            image = decoded.image; imageID = Self.identifier(decoded.jpeg); loading = false
            return true
        } catch {
            guard generation == token else { return false }
            loading = false
            if !Task.isCancelled { message = "This wallpaper could not be loaded or saved. Your previous background is unchanged. Please try another photo." }
            return false
        }
    }

    /// A newer background choice abandons an import without deleting the saved photo.
    func cancelImport() {
        guard loading else { return }
        generation = UUID(); loading = false; message = nil
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

