import Foundation

enum MenuBarLimit: String, Hashable, Sendable, CaseIterable {
    case iconOnly
    case upToOne
    case upToTwo
    case upToThree
    case upToFour
    case upToFive
    case all

    var count: Int {
        switch self {
        case .iconOnly: 0
        case .upToOne: 1
        case .upToTwo: 2
        case .upToThree: 3
        case .upToFour: 4
        case .upToFive: 5
        case .all: .max
        }
    }

    var label: String {
        switch self {
        case .iconOnly: "App Icon Only"
        case .all: "All"
        default: "Up to \(count)"
        }
    }
}
