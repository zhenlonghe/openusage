import Foundation

struct MenuBarContent: Equatable {
    struct Item: Equatable, Identifiable {
        let id: String
        let provider: Provider
        let label: String
        let shortLabel: String
        let value: String
    }

    struct Group: Equatable, Identifiable {
        struct Metric: Equatable, Identifiable {
            let id: String
            let label: String
            let value: String
        }

        let id: String
        let provider: Provider
        let metrics: [Metric]
    }

    let items: [Item]
    var groups: [Group] = []
    var overflow = 0
    var updateAvailable = false

    var isEmpty: Bool { items.isEmpty && groups.isEmpty }

    var accessibilityText: String {
        let shown: [String] = if !groups.isEmpty {
            groups.map { group in
                let metrics = group.metrics.map { "\($0.label) \($0.value)" }.joined(separator: ", ")
                return "\(group.provider.fullName) \(metrics)"
            }
        } else {
            items.map { "\($0.provider.fullName) \($0.label) \($0.value)" }
        }
        let more = overflow > 0 ? ["\(overflow) more"] : []
        let update = updateAvailable ? ["Update available"] : []
        return (shown + more + update).joined(separator: "; ")
    }
}

@MainActor
enum MenuBarContentBuilder {
    private static let genericWords: Set<String> = ["models", "bot", "usage"]

    /// Classic stacked strip: one icon per account in dashboard order with up to two values stacked
    /// vertically (e.g., 5h on top, 7d on bottom).
    static func buildStacked(accounts: [DashboardAccount], limit: MenuBarLimit) -> MenuBarContent {
        guard limit != .iconOnly else { return MenuBarContent(items: []) }
        let resolvedGroups = accounts.compactMap { account -> MenuBarContent.Group? in
            let bounded = account.lines.filter { $0.data.hasData && $0.data.isBounded }
            let selected: [DashboardLine] = if !bounded.isEmpty {
                Array(bounded.prefix(2))
            } else if let first = account.lines.first(where: \.data.hasData) {
                [first]
            } else {
                []
            }
            guard !selected.isEmpty else { return nil }
            return MenuBarContent.Group(
                id: account.id,
                provider: account.provider,
                metrics: selected.map { line in
                    MenuBarContent.Group.Metric(
                        id: line.id,
                        label: line.data.title,
                        value: line.data.menuBarValue
                    )
                }
            )
        }
        let shown = Array(resolvedGroups.prefix(limit.count))
        return MenuBarContent(items: [], groups: shown, overflow: max(0, resolvedGroups.count - shown.count))
    }

    /// Only what's running out, or with `alwaysShows` every section of the Priority tab in its order, top to bottom.
    static func build(board: PriorityBoard, limit: MenuBarLimit, alwaysShows: Bool = false) -> MenuBarContent {
        guard limit != .iconOnly else { return MenuBarContent(items: []) }
        let counted = alwaysShows
            ? board.pinned.map { ($0.provider, $0.line) } + (board.attention + board.useItOrLoseIt).map { ($0.provider, $0.line) }
            : board.runningOut.map { ($0.provider, $0.line) }
        let usedUp = alwaysShows ? board.usedUp.map { ($0.provider, $0.line) } : []
        let shown = (counted + usedUp).prefix(limit.count).map { provider, line in
            let label = line.data.title
            return MenuBarContent.Item(
                id: line.id,
                provider: provider,
                label: label,
                shortLabel: shortLabel(label),
                value: line.data.menuBarValue
            )
        }
        return MenuBarContent(items: shown, overflow: max(0, counted.count - shown.count))
    }

    static func shortLabel(_ label: String) -> String {
        var words = label.split(separator: " ")
        guard words.count > 1, let last = words.last, genericWords.contains(last.lowercased()) else { return label }
        words.removeLast()
        return words.joined(separator: " ")
    }
}
