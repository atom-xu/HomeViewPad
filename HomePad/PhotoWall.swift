import SwiftUI

/// The image identity changes only when decoding completes, never at the start of a request.
struct PhotoFrame: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct FadingPhoto: View {
    let frame: PhotoFrame?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let frame {
                    Image(uiImage: frame.image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().id(frame.id).transition(.opacity)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .animation(frame == nil ? nil : .easeInOut(duration: reduceMotion ? 0.15 : 0.85), value: frame?.id)
                // Revoked/deleted photos disappear immediately, even inside a parent page animation.
                .transaction { if frame == nil { $0.animation = nil; $0.disablesAnimations = true } }
        }.clipped().accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct PhotoWall: View {
    @ObservedObject var photos: PhotoLibraryStore
    let demoDate: Date?
    let navigationVisible: Bool
    let chooseAlbum: () -> Void
    let showNavigation: () -> Void
    var standby = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let portrait = geometry.size.height >= geometry.size.width
            ZStack(alignment: .bottomLeading) {
                Color(white: 0.10)
                PhotoWallComposition(frames: photos.wallFrames.isEmpty ? photos.frame.map { [$0] } ?? [] : photos.wallFrames)
                LinearGradient(stops: [.init(color: .clear, location: 0.32), .init(color: .black.opacity(0.2), location: 0.64), .init(color: .black.opacity(0.65), location: 1)], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                if photos.image == nil {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 54, weight: .ultraLight))
                        Text((photos.message ?? "Your favorite moments, on display.").tr).font(.title3).multilineTextAlignment(.center)
                        if !standby {
                            Button("Choose album".tr, action: chooseAlbum)
                                .buttonStyle(.borderedProminent).tint(.white.opacity(0.18))
                                .accessibilityIdentifier("chooseWallAlbum")
                        } else {
                            Text("Choose photos on the Photos page first.".tr).font(.callout)
                        }
                        if photos.loading { ProgressView().tint(.white) }
                    }.padding(32).frame(maxWidth: 460)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let date = demoDate ?? context.date
                    let time = date.formatted(.dateTime.locale(L10n.locale).hour(.defaultDigits(amPM: .omitted)).minute())
                    VStack(alignment: .leading, spacing: -side * 0.008) {
                        Text(date.formatted(.dateTime.locale(L10n.locale).weekday(.wide).month(.wide).day()).uppercased())
                            .font(.system(size: max(16, side * 0.026), weight: .semibold)).tracking(1.6)
                        Text(time).font(.system(size: side * (standby ? 0.08 : 0.14), weight: .medium, design: .rounded))
                            .tracking(standby ? 0 : -side * 0.002).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: time)
                            .accessibilityIdentifier("photoWallClock")
                        if standby {
                            Text("Tap anywhere to wake".tr).font(.footnote)
                        }
                    }.shadow(color: .black.opacity(0.18), radius: 12, y: 3)
                }.padding(.horizontal, side * 0.065)
                    .padding(.bottom, side * 0.045 + (portrait && navigationVisible ? 150 : 0))
                    .allowsHitTesting(false)
                    .animation(reduceMotion ? nil : .spring(duration: 0.4), value: navigationVisible)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .contentShape(Rectangle()).onTapGesture(perform: showNavigation)
                .accessibilityElement(children: .contain).accessibilityIdentifier("photoWall")
                .accessibilityValue(photos.image == nil ? "No photo".tr : L10n.format("Photo %d of %d", photos.position + 1, max(1, photos.photoCount)))
                .accessibilityAction(named: (standby ? "Tap anywhere to wake" : "Choose album").tr) { if standby { showNavigation() } else { chooseAlbum() } }
                .accessibilityAction(named: "Next photo".tr) { photos.next() }
                .accessibilityAction(named: "Show navigation".tr, showNavigation)
                .overlay(alignment: .topLeading) {
                    if demoDate != nil {
                        Text("DEMO".tr).font(.system(size: 11, weight: .semibold)).tracking(1)
                            .padding(.horizontal, 8).padding(.vertical, 5).background(.black.opacity(0.2), in: Capsule())
                            .padding(20).accessibilityIdentifier("demoBadge")
                    }
                }
        }.foregroundStyle(.white)
    }
}

/// Edge-to-edge composition uses each photo once. The first photo remains the
/// same image shared by Overview; wider and portrait pairs get suitable space.
private struct PhotoWallComposition: View {
    let frames: [PhotoFrame]
    private let gap: CGFloat = 8
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            switch frames.count {
            case 0: Color.clear
            case 1: FadingPhoto(frame: frames[0])
            case 2:
                let ratios = frames.map { max(0.25, min(4, $0.image.size.width / max(1, $0.image.size.height))) }
                let fraction = max(0.3, min(0.7, ratios[0] / (ratios[0] + ratios[1])))
                let firstWidth = (size.width - gap) * fraction
                HStack(spacing: gap) {
                    FadingPhoto(frame: frames[0]).frame(width: firstWidth)
                    FadingPhoto(frame: frames[1])
                }
            case 3:
                let portraitHero = frames[0].image.size.width < frames[0].image.size.height
                HStack(spacing: gap) {
                    FadingPhoto(frame: frames[0]).frame(width: (size.width - gap) * (portraitHero ? 0.4 : 0.62))
                    VStack(spacing: gap) {
                        FadingPhoto(frame: frames[1])
                        FadingPhoto(frame: frames[2])
                    }
                }
            default:
                HStack(spacing: gap) {
                    VStack(spacing: gap) {
                        FadingPhoto(frame: frames[0])
                        FadingPhoto(frame: frames[1])
                    }
                    VStack(spacing: gap) {
                        FadingPhoto(frame: frames[2])
                        FadingPhoto(frame: frames[3])
                    }
                }
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Photo wall".tr)
            .accessibilityValue(L10n.format("%d photos", frames.count))
            .accessibilityIdentifier("photoWallComposition")
    }
}
