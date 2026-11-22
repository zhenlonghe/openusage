import Foundation

enum MenuBarStyle: String, Hashable, Sendable, CaseIterable {
    case stacked
    case priority

    var label: String {
        switch self {
        case .stacked: "Stacked"
        case .priority: "Priority"
        }
    }
}
