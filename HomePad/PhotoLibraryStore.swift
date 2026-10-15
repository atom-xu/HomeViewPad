import SwiftUI
import Photos
import PhotosUI
import ImageIO

struct PhotoAlbum: Identifiable, Equatable {
    let id: String
    let title: String
    let count: Int
}

/// PhotoKit reads only. Library access is requested by an explicit user action.
@MainActor final class PhotoLibraryStore: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorization = PHAuthorizationStatus.notDetermined
    @Published private(set) var albums: [PhotoAlbum] = []
    @Published private(set) var frame: PhotoFrame?
    var image: UIImage? { frame?.image }
    @Published private(set) var selectedAlbumID: String?
    @Published private(set) var albumTitle = "Photos"
    @Published private(set) var photoCount = 0
    @Published private(set) var position = 0
    @Published private(set) var loading = false
    @Published var message: String?
    @Published var slideshow: Bool { didSet { defaults.set(slideshow, forKey: "photoSlideshow") } }
    private let defaults: UserDefaults
    private let fileURL: URL
    private let imageManager = PHImageManager()
    private var assets: PHFetchResult<PHAsset>?
    private var requestID: PHImageRequestID?
    private var generation = UUID()
    private var observing = false
    private var active = true
    private var currentAssetID: String?
    static let allPhotosID = "homepad.allPhotos"

    init(defaults: UserDefaults = .standard, fileURL: URL = URL.documentsDirectory.appending(path: "ambient-photo.jpg")) {
        self.defaults = defaults; self.fileURL = fileURL
        selectedAlbumID = defaults.string(forKey: "photoAlbumID")
        slideshow = defaults.object(forKey: "photoSlideshow") as? Bool ?? true
        super.init()
    }
    var authorized: Bool { Self.canRead(authorization) }
    static func canRead(_ status: PHAuthorizationStatus) -> Bool { status == .authorized || status == .limited }
    static func nextPosition(_ position: Int, count: Int) -> Int { count > 0 ? (position + 1) % count : 0 }

    func restore() {
        if selectedAlbumID != nil { refresh() }
        else if let data = try? Data(contentsOf: fileURL) { frame = Self.downsample(data).map { PhotoFrame(image: $0) } }
    }
    func connect() async {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        refresh()
    }
    func refresh() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authorized else {
            albums = []; assets = nil; photoCount = 0
            if selectedAlbumID != nil { invalidateImage(); message = "Photo access is off. Allow access in Settings or choose a single photo." }
            if observing { PHPhotoLibrary.shared().unregisterChangeObserver(self); observing = false }
            return
        }
        if !observing { PHPhotoLibrary.shared().register(self); observing = true }
        let all = PHAsset.fetchAssets(with: .image, options: fetchOptions())
        var available = [PhotoAlbum(id: Self.allPhotosID, title: authorization == .limited ? "Allowed photos" : "All photos", count: all.count)]
        // Limited access exposes allowed assets, but not the user's album collections.
        if authorization == .authorized {
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            collections.enumerateObjects { collection, _, _ in
                let count = PHAsset.fetchAssets(in: collection, options: self.fetchOptions()).count
                available.append(PhotoAlbum(id: collection.localIdentifier, title: collection.localizedTitle ?? "Untitled album", count: count))
            }
        }
        albums = Array(available.prefix(1)) + available.dropFirst().sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        guard let selectedAlbumID else { return }
        guard let album = albums.first(where: { $0.id == selectedAlbumID }) else {
            assets = nil; photoCount = 0; invalidateImage()
            message = "This album is no longer available. Choose an available album below."
            return
        }
        albumTitle = album.title
        if album.id == Self.allPhotosID { assets = all }
        else if let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [album.id], options: nil).firstObject {
            assets = PHAsset.fetchAssets(in: collection, options: fetchOptions())
        } else { assets = nil }
        photoCount = assets?.count ?? 0
        var retainedPosition: Int?
        if let currentAssetID { assets?.enumerateObjects { asset, index, stop in
            if asset.localIdentifier == currentAssetID { retainedPosition = index; stop.pointee = true }
        } }
        position = retainedPosition ?? 0
        loadCurrentPhoto(retainingCurrent: retainedPosition != nil)
    }
    private func fetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        return options
    }
    func select(_ album: PhotoAlbum) {
        guard albums.contains(where: { $0.id == album.id }) else { return }
        invalidateImage(); currentAssetID = nil; position = 0
        selectedAlbumID = album.id; defaults.set(album.id, forKey: "photoAlbumID")
        try? FileManager.default.removeItem(at: fileURL)
        refresh()
    }
    func next() {
        guard active, !loading, selectedAlbumID != nil, photoCount > 1 else { return }
        loadCurrentPhoto(at: Self.nextPosition(position, count: photoCount), retainingCurrent: true)
    }
    func setActive(_ value: Bool) {
        active = value
        if value { if selectedAlbumID != nil || observing { refresh() } }
        else { cancelRequest(); loading = false }
    }
    private func cancelRequest() {
        generation = UUID()
        if let requestID { imageManager.cancelImageRequest(requestID) }
        requestID = nil
    }
    private func invalidateImage() { cancelRequest(); frame = nil; loading = false }
    private func loadCurrentPhoto(at requestedPosition: Int? = nil, retainingCurrent: Bool = false) {
        if retainingCurrent { cancelRequest() } else { invalidateImage() }
        message = nil
        let target = requestedPosition ?? position
        guard active, let assets, assets.count > 0, target < assets.count else {
            if photoCount == 0 { message = "No photos in this album or in your allowed selection." }
            return
        }
        let asset = assets.object(at: target)
        let token = generation; loading = true
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat; options.resizeMode = .fast
        options.isNetworkAccessAllowed = true // User selected this album; iCloud may download the displayed image.
        requestID = imageManager.requestImage(for: asset, targetSize: CGSize(width: 2048, height: 2048), contentMode: .aspectFit, options: options) { [weak self] image, info in
            let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
            let failure = info?[PHImageErrorKey] as? Error
            Task { @MainActor in
                guard let self, self.generation == token, !cancelled, !degraded else { return }
                self.requestID = nil; self.loading = false
                // A late callback must not reveal a photo after access was revoked.
                guard Self.canRead(PHPhotoLibrary.authorizationStatus(for: .readWrite)) else { self.refresh(); return }
                if let image {
                    self.frame = PhotoFrame(image: image)
                    self.position = target; self.currentAssetID = asset.localIdentifier
                }
                if image == nil { self.message = failure?.localizedDescription ?? "This photo could not be loaded. Check iCloud and your connection, then retry." }
            }
        }
    }
    func importPhoto(_ item: PhotosPickerItem) async {
        cancelRequest(); let token = generation; loading = true; message = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = Self.downsample(data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            guard generation == token else { return }
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
            try jpeg.write(to: fileURL, options: .atomic)
            selectedAlbumID = nil; defaults.removeObject(forKey: "photoAlbumID")
            assets = nil; photoCount = 0; position = 0; currentAssetID = nil; albumTitle = "Selected photo"
            self.frame = PhotoFrame(image: image); loading = false
        } catch {
            guard generation == token else { return }
            loading = false; message = error.localizedDescription
        }
    }
    static func downsample(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2048] as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    func clear() {
        invalidateImage(); assets = nil; selectedAlbumID = nil; currentAssetID = nil
        photoCount = 0; position = 0; albumTitle = "Photos"; message = nil; albums = []
        defaults.removeObject(forKey: "photoAlbumID")
        try? FileManager.default.removeItem(at: fileURL)
        if observing { PHPhotoLibrary.shared().unregisterChangeObserver(self); observing = false }
    }
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in guard let self, self.active else { return }; self.refresh() }
    }
}

struct PhotosPanel: View {
    @ObservedObject var photos: PhotoLibraryStore
    @State private var item: PhotosPickerItem?
    @State private var showLimitedPicker = false
    var body: some View {
        List {
            Section("Photo widget") {
                if let image = photos.image {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).frame(maxWidth: .infinity).accessibilityIdentifier("photoPreview")
                }
                if photos.loading { ProgressView("Loading photo…") }
                if let message = photos.message { Text(message).foregroundStyle(.secondary).accessibilityIdentifier("photoMessage") }
                PhotosPicker("Choose a single photo", selection: $item, matching: .images).accessibilityIdentifier("singlePhotoPicker")
                Text("A single photo is copied into HomeViewPad. Choosing an album below displays photos from your library without copying the album. Anyone looking at this iPad can see them.").font(.footnote)
            }
            Section("iPad albums") {
                if photos.authorized {
                    if photos.authorization == .limited {
                        Text("Limited access · only photos you allow are available. Album names require full access.").font(.footnote)
                        Button("Manage allowed photos") { showLimitedPicker = true }
                    }
                    ForEach(photos.albums) { album in
                        Button { photos.select(album) } label: {
                            HStack {
                                VStack(alignment: .leading) { Text(album.title); Text("\(album.count) photos").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if photos.selectedAlbumID == album.id { Image(systemName: "checkmark") }
                            }
                        }.accessibilityIdentifier(album.id == PhotoLibraryStore.allPhotosID ? "album-all" : "album-\(album.id)")
                    }
                    Button("Refresh photos") { photos.refresh() }
                } else if photos.authorization == .denied || photos.authorization == .restricted {
                    Text("Photo library access is off. You can still choose a single photo.").accessibilityIdentifier("photosDenied")
                } else {
                    Button("Connect iPad photo library") { Task { await photos.connect() } }.accessibilityIdentifier("connectPhotos")
                }
                Button("Photo permission settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
            }
            if photos.selectedAlbumID != nil {
                Section(photos.albumTitle) {
                    if photos.photoCount > 0 { Text("Photo \(photos.position + 1) of \(photos.photoCount)").accessibilityIdentifier("photoPosition") }
                    Toggle("Rotate every 30 seconds", isOn: $photos.slideshow)
                    Button("Next photo") { photos.next() }.disabled(photos.photoCount < 2 || photos.loading).accessibilityIdentifier("nextPhoto")
                    Text("Plays while Home, Overview or the Photos wall is visible. iCloud photos may download as needed.").font(.footnote)
                }
            }
            Section {
                Button("Remove displayed photos", role: .destructive) { item = nil; photos.clear() }.accessibilityIdentifier("clearPhotos")
                Text("This clears HomeViewPad's selection and its saved copy. Your iPad photo library is never changed.").font(.footnote)
            }
        }.task { photos.refresh() }
            .onChange(of: item) { _, value in if let value { Task { await photos.importPhoto(value) } } }
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
