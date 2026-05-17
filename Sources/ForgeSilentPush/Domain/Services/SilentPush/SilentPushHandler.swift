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
