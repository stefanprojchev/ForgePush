import ForgeObservers
import Foundation

/// A handler for a specific type of silent push notification.
///
/// The router matches payloads via `matchesPayload`, dispatches matching handlers
/// concurrently, and aggregates results. Handlers share a ~30 second budget.
public protocol SilentPushHandler: Sendable {
    /// Unique identifier for this handler. Used for logging and deduplication.
    var id: String { get }

    /// Returns `true` if this handler should process the given push payload.
    func matchesPayload(_ payload: [AnyHashable: Any]) -> Bool

    /// Processes the push payload and returns the result.
    /// - Parameters:
    ///   - payload: The full push notification payload dictionary.
    ///   - context: Runtime context with connectivity and protected data status.
    func handle(_ payload: [AnyHashable: Any], context: SilentPushContext) async -> SilentPushResult
}

/// Runtime context provided to silent push handlers.
public struct SilentPushContext: Sendable {

    // MARK: - Properties

    /// Current network connectivity status.
    public let connectivity: ConnectivityStatus

    /// Whether protected data (Keychain, CoreData) is accessible.
    public let protectedDataAvailable: Bool

    // MARK: - Initialization

    /// - Parameters:
    ///   - connectivity: Current network connectivity status.
    ///   - protectedDataAvailable: Whether protected data is accessible.
    public init(connectivity: ConnectivityStatus, protectedDataAvailable: Bool) {
        self.connectivity = connectivity
        self.protectedDataAvailable = protectedDataAvailable
    }
}

/// The result of processing a silent push. Maps to `UIBackgroundFetchResult`.
public enum SilentPushResult: Sendable {

    // MARK: - Cases

    /// New data was fetched/processed successfully.
    case newData

    /// No new data was available.
    case noData

    /// The operation failed.
    case failed
}

// MARK: - UIBackgroundFetchResult mapping

#if canImport(UIKit)
import UIKit

extension SilentPushResult {
    /// Converts to `UIBackgroundFetchResult` for the system completion handler.
    public var backgroundFetchResult: UIBackgroundFetchResult {
        switch self {
        case .newData: .newData
        case .noData: .noData
        case .failed: .failed
        }
    }
}
#endif
