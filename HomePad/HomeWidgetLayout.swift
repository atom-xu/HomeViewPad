import Foundation

/// Saved only on this iPad and namespaced by the selected HomeKit home.
enum HomeWidgetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: "Small".tr
        case .medium: "Medium".tr
        case .large: "Large".tr
        }
    }
    var columns: Int { self == .small ? 1 : 2 }
    var rows: Int { self == .large ? 2 : 1 }
}

enum HomeWidgetKind: String, Codable { case stack, accessory, scene, camera, clock, agenda }

struct HomeWidgetConfiguration: Codable, Identifiable, Equatable {
    var id: String
    var kind: HomeWidgetKind
    var target: String?
    var size: HomeWidgetSize
    static let defaults: [HomeWidgetConfiguration] = (0..<6).map {
        HomeWidgetConfiguration(id: "slot-\($0)", kind: .stack, target: String($0), size: $0 == 0 ? .large : .small)
    }
}

struct HomeWidgetPlacement: Equatable {
    let id: String
    let column: Int
    let row: Int
    let columns: Int
    let rows: Int
}

enum HomeWidgetPacking {
    /// First-fit placement preserves the user's sequence and never overlaps cards.
    static func place(_ widgets: [HomeWidgetConfiguration], columns: Int) -> [HomeWidgetPlacement] {
        let columnCount = max(1, columns)
        var occupied = Set<Int>()
        var result: [HomeWidgetPlacement] = []
        for widget in widgets {
            let width = min(columnCount, widget.size.columns)
            let height = widget.size.rows
            var candidate = 0
            while true {
                let column = candidate % columnCount
                let row = candidate / columnCount
                if column + width <= columnCount {
                    let positions = (row..<(row + height)).flatMap { r in (column..<(column + width)).map { r * columnCount + $0 } }
                    if positions.allSatisfy({ !occupied.contains($0) }) {
                        occupied.formUnion(positions)
                        result.append(HomeWidgetPlacement(id: widget.id, column: column, row: row, columns: width, rows: height))
                        break
                    }
                }
                candidate += 1
            }
        }
        return result
    }
}

/// A missing or failed reading must never become an Off badge.
enum HomePowerState: String, Equatable {
    case on = "On", off = "Off", unavailable = "Unavailable", offline = "Offline"
    static func resolve(value: String, reachable: Bool) -> HomePowerState {
        guard reachable else { return .offline }
        switch value {
        case "On": return .on
        case "Off": return .off
        default: return .unavailable
        }
    }
    var title: String { rawValue.tr }
}
