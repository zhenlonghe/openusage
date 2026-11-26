import Foundation

enum RefreshSetting {
    static let interval: TimeInterval = 5 * 60

    /// A forced refresh lets the next pass skip an account, so working refreshes can leave its values
    /// about two intervals old.
    static let stalenessThreshold = interval * 2

    static let failureBackoffBase = interval
    static let failureBackoffCap: TimeInterval = 60 * 60
    /// The waits before each retry of a refresh that found no network path, about a minute in all. Right after
    /// launch, macOS refuses a hub on the local network for a moment before it lets OpenUsage in, and the next
    /// pass would be 5 minutes away. The account isn't flagged until the last retry fails.
    static let offlineRetryDelays: [TimeInterval] = [2, 4, 8, 16, 32]

    /// A limit window that resets is read again this long after, once the provider has started the new one.
    static let rolloverGrace: TimeInterval = 30
    /// How often the app looks for a window that has reset. Looking reads nothing; only a reset window is read.
    static let rolloverCheckInterval: TimeInterval = 30
    /// Opening the panel reads the accounts whose values are at least this old.
    static let panelOpenMaxAge: TimeInterval = 2 * 60

    static let secondaryReadInterval: TimeInterval = 60 * 60
    static let forcedResetGrantsMinimumAge: TimeInterval = 15 * 60
}
