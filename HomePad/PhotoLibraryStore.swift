import SwiftUI
import Photos
import PhotosUI
import ImageIO

struct PhotoAlbum: Identifiable, Equatable {
    let id: String
    let title: String
    let count: Int
}

enum PhotoWallStyle: String, CaseIterable, Identifiable {
    case wall, single
    var id: String { rawValue }
    var title: String { (self == .wall ? "Photo wall" : "One photo").tr }
}

/// PhotoKit reads only. Library access is requested by an explicit user action.
/// Picker copies are independent of PhotoKit authorization and of the wallpaper.
@MainActor final class PhotoLibraryStore: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorization = PHAuthorizationStatus.notDetermined
    @Published private(set) var albums: [PhotoAlbum] = []
    @Published private(set) var frame: PhotoFrame?
    @Published private(set) var wallFrames: [PhotoFrame] = []
    var image: UIImage? { frame?.image }
    @Published private(set) var selectedAlbumID: String?
    @Published private(set) var albumTitle = "Photos"
    var displayAlbumTitle: String {
        if selectedAlbumID == Self.allPhotosID { return (authorization == .limited ? "Allowed photos" : "All photos").tr }
        if selectedAlbumID == Self.favoritesID { return "Favorites".tr }
        if selectedAlbumID == nil { return (image == nil ? "Photos" : "Selected photos").tr }
        return albumTitle
    }
    @Published private(set) var photoCount = 0
    @Published private(set) var position = 0
    @Published private(set) var loading = false
    @Published var message: String?
    @Published var slideshow: Bool { didSet { defaults.set(slideshow, forKey: "photoSlideshow") } }
    @Published var wallStyle: PhotoWallStyle {
        didSet {
            defaults.set(wallStyle.rawValue, forKey: "photoWallStyle")
            if active { loadCurrentPhoto(retainingCurrent: true) }
        }
    }
    private let defaults: UserDefaults
    private let fileURL: URL
    private var selectionDirectory: URL { fileURL.deletingLastPathComponent().appending(path: "ambient-photos", directoryHint: .isDirectory) }
    private var manifestURL: URL { selectionDirectory.appending(path: "selection.json") }
    private var localFiles: [URL] = []
    private let imageManager = PHImageManager()
    private var assets: PHFetchResult<PHAsset>?
    private var requestIDs: [PHImageRequestID] = []
    private var requestTimeout: Task<Void, Never>?
    private var generation = UUID()
    private var observing = false
    private var active = true
    private var currentAssetID: String?
    static let allPhotosID = "homepad.allPhotos"
    static let favoritesID = "homepad.favorites"
    nonisolated static let selectionLimit = 24

    init(defaults: UserDefaults = .standard, fileURL: URL = URL.documentsDirectory.appending(path: "ambient-photo.jpg")) {
        self.defaults = defaults; self.fileURL = fileURL
        selectedAlbumID = defaults.string(forKey: "photoAlbumID")
        slideshow = defaults.object(forKey: "photoSlideshow") as? Bool ?? true
        wallStyle = PhotoWallStyle(rawValue: defaults.string(forKey: "photoWallStyle") ?? "") ?? .wall
        super.init()
    }
    var authorized: Bool { Self.canRead(authorization) }
    static func canRead(_ status: PHAuthorizationStatus) -> Bool { status == .authorized || status == .limited }
    static func nextPosition(_ position: Int, count: Int) -> Int { count > 0 ? (position + 1) % count : 0 }
    /// Never repeat a photo to fill empty wall slots, including a one-photo album.
    static func wallPositions(start: Int, count: Int, style: PhotoWallStyle) -> [Int] {
        guard count > 0 else { return [] }
        return (0..<min(count, style == .wall ? 4 : 1)).map { (max(0, start) + $0) % count }
    }

    func restore() {
        if selectedAlbumID != nil { refresh(); return }
        if let data = try? Data(contentsOf: manifestURL), let manifest = try? JSONDecoder().decode(SelectionManifest.self, from: data), manifest.valid {
            localFiles = manifest.photos.map { selectionDirectory.appending(path: $0) }
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            // Preserve the existing single-photo selection without rewriting it.
            localFiles = [fileURL]
        }
        photoCount = localFiles.count
        if photoCount > 0 { loadCurrentPhoto() }
    }
    func connect() async {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard active, !Task.isCancelled else { return }
        refresh()
    }
    func refresh() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authorized else {
            albums = []; assets = nil
            if selectedAlbumID != nil {
                photoCount = 0; currentAssetID = nil; invalidateImage()
                message = "Photo access is off. Allow access in Settings or choose photos."
            }
            if observing { PHPhotoLibrary.shared().unregisterChangeObserver(self); observing = false }
            return
        }
        if !observing { PHPhotoLibrary.shared().register(self); observing = true }
        let all = PHAsset.fetchAssets(with: .image, options: fetchOptions())
        var available = [PhotoAlbum(id: Self.allPhotosID, title: authorization == .limited ? "Allowed photos" : "All photos", count: all.count)]
        // Limited access exposes allowed assets, but not the user's album collections.
        if authorization == .authorized {
            if let favorites = favoritesCollection() {
                available.append(PhotoAlbum(id: Self.favoritesID, title: "Favorites", count: PHAsset.fetchAssets(in: favorites, options: fetchOptions()).count))
            }
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            var named: [PhotoAlbum] = []
            collections.enumerateObjects { collection, _, _ in
                let count = PHAsset.fetchAssets(in: collection, options: self.fetchOptions()).count
                named.append(PhotoAlbum(id: collection.localIdentifier, title: collection.localizedTitle ?? "Untitled album", count: count))
            }
            available += named.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
        albums = available
        guard let selectedAlbumID else { return }
        guard let album = albums.first(where: { $0.id == selectedAlbumID }) else {
            assets = nil; photoCount = 0; currentAssetID = nil; invalidateImage()
            message = "This album is no longer available. Choose an available album below."
            return
        }
        albumTitle = album.title
        if album.id == Self.allPhotosID { assets = all }
        else if let collection = album.id == Self.favoritesID ? favoritesCollection() : PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [album.id], options: nil).firstObject {
            assets = PHAsset.fetchAssets(in: collection, options: fetchOptions())
        } else { assets = nil }
        photoCount = assets?.count ?? 0
        var retainedPosition: Int?
        if let currentAssetID { assets?.enumerateObjects { asset, index, stop in
            if asset.localIdentifier == currentAssetID { retainedPosition = index; stop.pointee = true }
        } }
        position = retainedPosition ?? 0
        // Refreshes may follow deletions or limited-access changes. Clear all
        // previously displayed library images before constructing the new wall.
        loadCurrentPhoto(retainingCurrent: false)
    }
    private func favoritesCollection() -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil).firstObject
    }
    private func fetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        return options
    }
    func select(_ album: PhotoAlbum) {
        guard active, albums.contains(where: { $0.id == album.id }) else { return }
        invalidateImage(); currentAssetID = nil; position = 0
        selectedAlbumID = album.id; defaults.set(album.id, forKey: "photoAlbumID")
        removeLocalCopies(); localFiles = []
        refresh()
    }
    func next() {
        guard active, !loading, photoCount > 1 else { return }
        loadCurrentPhoto(at: Self.nextPosition(position, count: photoCount), retainingCurrent: true)
    }
    func setActive(_ value: Bool) {
        active = value
        if value {
            // The system permission sheet can finish while the scene is still
            // inactive. Re-read its result on return even without an album yet.
            refresh()
            if selectedAlbumID == nil, !localFiles.isEmpty, frame == nil { loadCurrentPhoto() }
        } else { cancelPendingImport() }
    }
    func cancelPendingImport() { cancelRequest(); loading = false }
    private func cancelRequest() {
        generation = UUID()
        requestTimeout?.cancel(); requestTimeout = nil
        requestIDs.forEach { imageManager.cancelImageRequest($0) }
        requestIDs = []
    }
    private func invalidateImage() { cancelRequest(); frame = nil; wallFrames = []; loading = false }
    private func loadCurrentPhoto(at requestedPosition: Int? = nil, retainingCurrent: Bool = false) {
        if retainingCurrent { cancelRequest(); loading = false } else { invalidateImage() }
        message = nil
        let target = requestedPosition ?? position
        let positions = Self.wallPositions(start: target, count: photoCount, style: wallStyle)
        guard active, !positions.isEmpty else {
            if photoCount == 0 { message = "No photos in this album or in your allowed selection." }
            return
        }
        if selectedAlbumID == nil {
            let loaded = positions.compactMap { index -> PhotoFrame? in
                guard index < localFiles.count, let data = try? Data(contentsOf: localFiles[index]), let image = Self.downsample(data) else { return nil }
                return PhotoFrame(image: image)
            }
            // A missing local copy cannot silently become an unrelated photo.
            guard loaded.count == positions.count else {
                message = "Saved photos could not be opened. Choose them again."
                return
            }
            frame = loaded.first; wallFrames = loaded; position = target
            return
        }
        guard let assets, target < assets.count else { return }
        let token = generation; loading = true
        var completed: [Int: UIImage] = [:]
        var pending = Set(positions)
        var failed = false
        for index in positions {
            let asset = assets.object(at: index)
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat; options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            let requestID = imageManager.requestImage(for: asset, targetSize: CGSize(width: 2048, height: 2048), contentMode: .aspectFit, options: options) { [weak self] image, info in
                let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                Task { @MainActor in
                    guard let self, self.active, self.generation == token, !cancelled, !degraded, pending.contains(index) else { return }
                    // No cached library frame survives permission loss.
                    guard Self.canRead(PHPhotoLibrary.authorizationStatus(for: .readWrite)) else { self.refresh(); return }
                    pending.remove(index)
                    if let image { completed[index] = image } else { failed = true }
                    guard pending.isEmpty else { return }
                    self.requestIDs = []; self.requestTimeout?.cancel(); self.requestTimeout = nil; self.loading = false
                    guard !failed, completed[target] != nil else {
                        self.message = "This photo could not be loaded. Check iCloud and your connection, then retry."
                        return
                    }
                    let frames = positions.compactMap { completed[$0].map { PhotoFrame(image: $0) } }
                    self.frame = frames.first; self.wallFrames = frames
                    self.position = target; self.currentAssetID = assets.object(at: target).localIdentifier
                }
            }
            requestIDs.append(requestID)
        }
        requestTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(90)) } catch { return }
            guard let self, self.generation == token, self.loading else { return }
            self.cancelRequest(); self.loading = false
            self.message = "This photo could not be loaded. Check iCloud and your connection, then retry."
        }
    }
    func importPhoto(_ item: PhotosPickerItem) async { await importPhotos([item]) }
    func importPhotos(_ items: [PhotosPickerItem]) async {
        await importImages(items.prefix(Self.selectionLimit).map { item in { try await item.loadTransferable(type: Data.self) } })
    }
    /// The whole selection is committed together. Failed/cancelled iCloud loads
    /// keep the last selection; late callbacks after clear/background cannot save.
    func importImages(_ loaders: [() async throws -> Data?]) async {
        guard active, !loaders.isEmpty else { return }
        cancelRequest(); let token = generation; loading = true; message = nil
        var newFiles: [URL] = []
        do {
            try FileManager.default.createDirectory(at: selectionDirectory, withIntermediateDirectories: true)
            for loader in loaders.prefix(Self.selectionLimit) {
                guard let data = try await loader() else { throw CocoaError(.fileReadCorruptFile) }
                try Task.checkCancellation()
                guard active, generation == token else { throw CancellationError() }
                let jpeg = await Task.detached(priority: .userInitiated) {
                    Self.downsample(data)?.jpegData(compressionQuality: 0.85)
                }.value
                try Task.checkCancellation()
                guard active, generation == token else { throw CancellationError() }
                guard let jpeg else { throw CocoaError(.fileReadCorruptFile) }
                let destination = selectionDirectory.appending(path: "\(UUID().uuidString).jpg")
                try jpeg.write(to: destination, options: .atomic)
                newFiles.append(destination)
            }
            try Task.checkCancellation()
            guard active, generation == token else { throw CancellationError() }
            let manifest = SelectionManifest(version: 1, photos: newFiles.map(\.lastPathComponent))
            try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
            let previous = localFiles
            localFiles = newFiles; selectedAlbumID = nil; defaults.removeObject(forKey: "photoAlbumID")
            assets = nil; photoCount = newFiles.count; position = 0; currentAssetID = nil; albumTitle = "Selected photos"
            loading = false
            loadCurrentPhoto()
            previous.filter { !newFiles.contains($0) }.forEach { try? FileManager.default.removeItem(at: $0) }
            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            newFiles.forEach { try? FileManager.default.removeItem(at: $0) }
            guard generation == token else { return }
            loading = false
            if !Task.isCancelled, !(error is CancellationError) {
                message = "Photos could not be loaded or saved. Your previous selection is unchanged. Check iCloud and try again."
            }
        }
    }
    nonisolated static func downsample(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true, kCGImageSourceThumbnailMaxPixelSize: 2048] as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    private func removeLocalCopies() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: selectionDirectory)
    }
    func clear() {
        cancelPendingImport()
        do {
            for url in [fileURL, selectionDirectory] where FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            message = "Saved photos could not be removed. Please try again."
            return
        }
        invalidateImage(); assets = nil; selectedAlbumID = nil; currentAssetID = nil; localFiles = []
        photoCount = 0; position = 0; albumTitle = "Photos"; message = nil; albums = []
        defaults.removeObject(forKey: "photoAlbumID")
        if observing { PHPhotoLibrary.shared().unregisterChangeObserver(self); observing = false }
    }
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in guard let self, self.active else { return }; self.refresh() }
    }
    private struct SelectionManifest: Codable {
        let version: Int
        let photos: [String]
        var valid: Bool {
            version == 1 && !photos.isEmpty && photos.count <= PhotoLibraryStore.selectionLimit && Set(photos).count == photos.count && photos.allSatisfy {
                $0 == URL(fileURLWithPath: $0).lastPathComponent && $0.hasSuffix(".jpg") && UUID(uuidString: String($0.dropLast(4))) != nil
            }
        }
    }
}

struct PhotosPanel: View {
    @ObservedObject var photos: PhotoLibraryStore
    @State private var items: [PhotosPickerItem] = []
    @State private var pickerPresented = false
    @State private var showLimitedPicker = false
    var body: some View {
        List {
            Section("Your photos".tr) {
                if let image = photos.image {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).frame(maxWidth: .infinity).accessibilityIdentifier("photoPreview")
                    Text(L10n.format("%d photos", photos.photoCount)).foregroundStyle(.secondary).accessibilityIdentifier("selectedPhotoCount")
                }
                Button { pickerPresented = true } label: {
                    Label("Choose photos".tr, systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Color.accentColor).accessibilityIdentifier("singlePhotoPicker")
                if photos.loading {
                    ProgressView("Loading photos…".tr)
                    Button("Cancel photo loading".tr) { photos.cancelPendingImport() }
                }
                if let message = photos.message { Text(message.tr).foregroundStyle(.secondary).accessibilityIdentifier("photoMessage") }
                Text("Choose up to 24 photos for a wall or slideshow. HomePad saves copies on this iPad; your originals stay unchanged.".tr).font(.footnote)
            }
            Section("Display".tr) {
                Picker("Photo layout".tr, selection: $photos.wallStyle) {
                    ForEach(PhotoWallStyle.allCases) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("photoWallStyle")
                Toggle("Rotate every 30 seconds".tr, isOn: $photos.slideshow)
                if photos.photoCount > 0 { Text(L10n.format("Photo %d of %d", photos.position + 1, photos.photoCount)).accessibilityIdentifier("photoPosition") }
                Button("Next photo".tr) { photos.next() }.disabled(photos.photoCount < 2 || photos.loading).accessibilityIdentifier("nextPhoto")
            }
            Section("iPad albums".tr) {
                if photos.authorized {
                    if photos.authorization == .limited {
                        Text("Limited access · only photos you allow are available. Album names require full access.".tr).font(.footnote)
                        Button("Manage allowed photos".tr) { showLimitedPicker = true }
                    }
                    ForEach(photos.albums) { album in
                        Button { photos.select(album) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(album.id == PhotoLibraryStore.allPhotosID || album.id == PhotoLibraryStore.favoritesID ? album.title.tr : album.title)
                                    Text(L10n.format("%d photos", album.count)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if photos.selectedAlbumID == album.id { Image(systemName: "checkmark") }
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier(album.id == PhotoLibraryStore.allPhotosID ? "album-all" : album.id == PhotoLibraryStore.favoritesID ? "album-favorites" : "album-\(album.id)")
                    }
                    Button("Refresh photos".tr) { photos.refresh() }
                } else if photos.authorization == .denied || photos.authorization == .restricted {
                    Text("Photo library access is off. You can still choose photos.".tr).accessibilityIdentifier("photosDenied")
                } else {
                    Button("Connect iPad photo library".tr) { Task { await photos.connect() } }.accessibilityIdentifier("connectPhotos")
                }
                Button("Photo permission settings".tr) { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                Text("Albums stay in Photos and update as you add or remove pictures. iCloud photos download as needed.".tr).font(.footnote)
            }
            Section("iPhone photos".tr) {
                Text("Use the same Apple Account and turn on iCloud Photos on both devices. Photos synced to this iPad can then be selected here.".tr).font(.footnote)
                Text("Favorites is available with full photo access. Apple's Featured Photos and Memories are not available as a live source; choose photos or an album instead.".tr).font(.footnote)
            }
            Section {
                Button("Remove displayed photos".tr, role: .destructive) { items = []; photos.clear() }.accessibilityIdentifier("clearPhotos")
                Text("Only HomePad's copies and selection are removed. The photo library and wallpaper stay unchanged.".tr).font(.footnote)
            }
        }.task { photos.refresh() }
            // Stable presenter: a virtualized List row does not own the picker.
            .photosPicker(isPresented: $pickerPresented, selection: $items, maxSelectionCount: PhotoLibraryStore.selectionLimit, selectionBehavior: .ordered, matching: .images)
            .task(id: items) { if !items.isEmpty { await photos.importPhotos(items) } }
            .sheet(isPresented: $showLimitedPicker, onDismiss: { photos.refresh() }) { LimitedPhotosPicker() }
    }
}

private struct LimitedPhotosPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> LimitedPickerController {
        let controller = LimitedPickerController(); controller.finished = { dismiss() }; return controller
    }
    func updateUIViewController(_ uiViewController: LimitedPickerController, context: Context) {}
}
private final class LimitedPickerController: UIViewController {
    var finished: (() -> Void)?
    private var presented = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !presented else { return }; presented = true
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else { finished?(); return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self) { [weak self] _ in self?.finished?() }
    }
}
