import Foundation

struct ProviderSnapshot: Hashable, Sendable, Codable {
    let providerID: String
    let displayName: String
    var plan: String?
    var lines: [MetricLine]
    /// Range details read with these lines, keyed by descriptor key. Older snapshots carry only lines.
    var usageBreakdowns: [String: UsageBreakdown]?
    /// Row titles this reading renames, keyed by line label. Older snapshots carry none.
    var lineTitles: [String: String]?
    /// Claude's last reset-grants answer, so each reset keeps its kind and Use at launch. Older snapshots
    /// carry none.
    var resetGrants: ClaudeResetGrantStatus?
    var notice: String?
    var refreshedAt: Date

    init(
        providerID: String,
        displayName: String,
        plan: String? = nil,
        lines: [MetricLine],
        notice: String? = nil,
        refreshedAt: Date = Date()
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.plan = plan
        self.lines = lines
        self.notice = notice
        self.refreshedAt = refreshedAt
    }

    func line(label: String) -> MetricLine? {
        lines.first { $0.label == label }
    }

    var staleAt: Date { refreshedAt.addingTimeInterval(RefreshSetting.stalenessThreshold) }

    func isStale(at date: Date) -> Bool { date >= staleAt }

    /// A limit window this reading shows has reset since, so its values belong to the window that ended.
    func hasResetWindow(at date: Date) -> Bool {
        lines.contains { line in
            guard case .progress(_, _, _, _, let resetsAt?, _) = line else { return false }
            return resetsAt > refreshedAt && resetsAt.addingTimeInterval(RefreshSetting.rolloverGrace) <= date
        }
    }

    init(provider: Provider, plan: String?, lines: [MetricLine], notice: String? = nil, refreshedAt: Date = Date()) {
        self.init(providerID: provider.id, displayName: provider.displayName, plan: plan, lines: lines, notice: notice,
                  refreshedAt: refreshedAt)
    }
}

struct RefreshFailure: Error, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case rateLimited(retryAfter: TimeInterval?)
        case unreachable
        /// No network path, which can pass within seconds. See `URLError.meansOffline`.
        case offline
        case refused
    }

    var message: String
    var kind: Kind
}

extension RefreshFailure {
    init(error: Error) {
        let kind: Kind = switch error {
        case ProviderError.rateLimited(let retryAfter): .rateLimited(retryAfter: retryAfter)
        case let error as URLError where error.meansOffline: .offline
        case ProviderError.unreachable(_, offline: true): .offline
        case is URLError, ProviderError.connectionFailed, ProviderError.unreachable: .unreachable
        default: .refused
        }
        self.init(message: error.localizedDescription, kind: kind)
    }
}
