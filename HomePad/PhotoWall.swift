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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let portrait = geometry.size.height >= geometry.size.width
            ZStack(alignment: .bottomLeading) {
                Color(white: 0.10)
                FadingPhoto(frame: photos.frame)
                LinearGradient(stops: [.init(color: .clear, location: 0.32), .init(color: .black.opacity(0.2), location: 0.64), .init(color: .black.opacity(0.65), location: 1)], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                if photos.image == nil {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 54, weight: .ultraLight))
                        Text(photos.message ?? "Your favorite moments, on display.").font(.title3).multilineTextAlignment(.center)
                        Button("Choose album", action: chooseAlbum)
                            .buttonStyle(.borderedProminent).tint(.white.opacity(0.18))
                            .accessibilityIdentifier("chooseWallAlbum")
                        if photos.loading { ProgressView().tint(.white) }
                    }.padding(32).frame(maxWidth: 460)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let date = demoDate ?? context.date
                    let time = date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    VStack(alignment: .leading, spacing: -side * 0.008) {
                        Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                            .font(.system(size: max(16, side * 0.026), weight: .semibold)).tracking(1.6)
                        Text(time).font(.system(size: side * 0.235, weight: .medium, design: .rounded))
                            .tracking(-side * 0.012).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: time)
                            .accessibilityIdentifier("photoWallClock")
                    }.shadow(color: .black.opacity(0.18), radius: 12, y: 3)
                }.padding(.horizontal, side * 0.065)
                    .padding(.bottom, side * 0.045 + (portrait && navigationVisible ? 150 : 0))
                    .allowsHitTesting(false)
                    .animation(reduceMotion ? nil : .spring(duration: 0.4), value: navigationVisible)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .contentShape(Rectangle()).onTapGesture(perform: showNavigation)
                .accessibilityElement(children: .contain).accessibilityIdentifier("photoWall")
                .accessibilityValue(photos.image == nil ? "No photo" : "Photo \(photos.position + 1) of \(max(1, photos.photoCount))")
                .accessibilityAction(named: "Choose album", chooseAlbum)
                .accessibilityAction(named: "Next photo") { photos.next() }
                .accessibilityAction(named: "Show navigation", showNavigation)
                .overlay(alignment: .topLeading) {
                    if demoDate != nil {
                        Text("DEMO").font(.system(size: 11, weight: .semibold)).tracking(1)
                            .padding(.horizontal, 8).padding(.vertical, 5).background(.black.opacity(0.2), in: Capsule())
                            .padding(20).accessibilityIdentifier("demoBadge")
                    }
                }
        }.foregroundStyle(.white)
    }
}
