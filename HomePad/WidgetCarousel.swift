import SwiftUI

/// A bounded window keeps large homes from filling a tile with hundreds of dots.
enum CarouselPosition {
    static func visibleIndices(selection: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let width = min(5, count)
        let selected = min(max(0, selection), count - 1)
        let start = min(max(0, selected - width / 2), count - width)
        return Array(start..<(start + width))
    }
}

struct WidgetCarousel<Item: Hashable, Content: View>: View {
    let items: [Item]
    @Binding var selection: Int
    let size: CGFloat
    var height: CGFloat? = nil
    var allowsVerticalSwipe = true
    let radius: CGFloat
    let slot: Int
    let showNavigation: () -> Void
    @ViewBuilder let content: (Item) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var forward = true
    @State private var indicatorVisible = false
    @State private var indicatorRevision = 0
    @GestureState private var draggingVertically = false
    private var index: Int { selection % max(1, items.count) }
    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .bottom : .top).combined(with: .opacity),
                           removal: .move(edge: forward ? .top : .bottom).combined(with: .opacity))
    }
    var body: some View {
        ZStack {
            if !items.isEmpty {
                content(items[index]).frame(width: size, height: height ?? size)
                    .id(items[index]).transition(transition)
            }
        }.frame(width: size, height: height ?? size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(alignment: .trailing) {
                if items.count > 1 && (indicatorVisible || draggingVertically) {
                    VStack(spacing: 5) {
                        ForEach(CarouselPosition.visibleIndices(selection: index, count: items.count), id: \.self) { position in
                            Capsule().fill(.white.opacity(position == index ? 1 : 0.38))
                                .frame(width: 4, height: position == index ? 12 : 4)
                        }
                    }.padding(.vertical, 8).padding(.horizontal, 5)
                        .background(.black.opacity(0.12), in: Capsule())
                        .padding(.trailing, max(7, size * 0.025))
                        .allowsHitTesting(false)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Widget position".tr)
                        .accessibilityValue(L10n.format("%lld of %lld", index + 1, items.count))
                        .accessibilityIdentifier("widgetPosition-\(slot)")
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .animation(.easeOut(duration: 0.18), value: indicatorVisible || draggingVertically)
            .task(id: indicatorRevision) {
                guard indicatorVisible else { return }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                indicatorVisible = false
            }
            .highPriorityGesture(DragGesture(minimumDistance: 30).updating($draggingVertically) { value, state, _ in
                guard allowsVerticalSwipe, !dynamicTypeSize.isAccessibilitySize else { return }
                let direction = DashboardSwipe.classify(x: value.translation.width, y: value.translation.height)
                state = direction == .up || direction == .down
            }.onEnded { value in
                guard allowsVerticalSwipe, !dynamicTypeSize.isAccessibilitySize else { return }
                switch DashboardSwipe.classify(x: value.translation.width, y: value.translation.height) {
                case .up: advance(forward: true)
                case .down: advance(forward: false)
                default: break
                }
            }, including: !allowsVerticalSwipe || dynamicTypeSize.isAccessibilitySize ? .subviews : .all)
            .accessibilityAction(named: "Next widget".tr) { advance(forward: true) }
            .accessibilityAction(named: "Previous widget".tr) { advance(forward: false) }
            .accessibilityAction(named: "Show navigation".tr, showNavigation)
    }
    private func advance(forward: Bool) {
        guard items.count > 1 else { return }
        self.forward = forward
        indicatorVisible = true; indicatorRevision += 1
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.44, bounce: 0.06)) {
            selection = (index + (forward ? 1 : items.count - 1)) % items.count
        }
    }
}
