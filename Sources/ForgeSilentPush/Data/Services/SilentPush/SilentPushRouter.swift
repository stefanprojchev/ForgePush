import ForgeCore
import ForgeObservers
import OSLog
#if canImport(UIKit)
import UIKit
#endif

/// Routes silent push notifications to registered handlers concurrently and aggregates results.
///
/// Matches payloads against handlers, dispatches matches via `TaskGroup`,
/// and returns the most optimistic result (`.newData` > `.failed` > `.noData`).
public final class SilentPushRouter: Sendable {

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "core.push", category: "silent")
    private let handlers = LockedState<[any SilentPushHandler]>([])
    private let connectivity: ConnectivityObserving
    private let protectedData: ProtectedDataObserving

    // MARK: - Init

    /// - Parameters:
    ///   - connectivity: Observer for network status.
    ///   - protectedData: Observer for protected data availability.
    public init(
        connectivity: ConnectivityObserving,
        protectedData: ProtectedDataObserving
    ) {
        self.connectivity = connectivity
        self.protectedData = protectedData
    }

    // MARK: - Implementation

    /// Registers a handler for silent push notifications.
    public func addHandler(_ handler: any SilentPushHandler) {
        handlers.withLock {
            guard !$0.contains(where: { $0.id == handler.id }) else {
                logger.warning("Duplicate handler ID '\(handler.id)' — skipping")
                return
            }
            $0.append(handler)
            logger.debug("Added handler: \(handler.id)")
        }
    }

    /// Removes a handler by ID.
    public func removeHandler(_ id: String) {
        handlers.withLock {
            $0.removeAll { $0.id == id }
            logger.debug("Removed handler: \(id)")
        }
    }

    #if canImport(UIKit)
    /// Routes a silent push to matching handlers and calls the completion handler.
    ///
    /// - Parameters:
    ///   - payload: The push notification payload dictionary.
    ///   - completionHandler: The system completion handler. Called with the aggregated result.
    public func handlePush(
        payload: [AnyHashable: Any],
        completionHandler: @escaping @Sendable (UIKit.UIBackgroundFetchResult) -> Void
    ) {
        let matching = handlers.withLock {
            $0.filter { $0.matchesPayload(payload) }
        }

        guard !matching.isEmpty else {
            logger.debug("No handlers matched payload")
            completionHandler(.noData)
            return
        }

        logger.info("Push matched \(matching.count) handler(s): \(matching.map(\.id).joined(separator: ", "))")

        let context = SilentPushContext(
            connectivity: connectivity.status,
            protectedDataAvailable: protectedData.state == .available
        )

        // payload ([AnyHashable: Any]) is not Sendable but comes from UIKit and is safe to pass.
        nonisolated(unsafe) let unsafePayload = payload
        nonisolated(unsafe) let unsafeMatching = matching
        Task {
            let result = await dispatch(unsafeMatching, payload: unsafePayload, context: context)
            logger.info("Push complete — result: \(String(describing: result))")
            completionHandler(result.backgroundFetchResult)
        }
    }
    #endif

    /// Async variant — routes a silent push and returns the aggregated result.
    public func handlePush(payload: [AnyHashable: Any]) async -> SilentPushResult {
        let matching = handlers.withLock {
            $0.filter { $0.matchesPayload(payload) }
        }

        guard !matching.isEmpty else {
            logger.debug("No handlers matched payload")
            return .noData
        }

        logger.info("Push matched \(matching.count) handler(s)")

        let context = SilentPushContext(
            connectivity: connectivity.status,
            protectedDataAvailable: protectedData.state == .available
        )

        return await dispatch(matching, payload: payload, context: context)
    }

    /// IDs of all currently-registered handlers. Used by tests to verify registration state.
    internal var registeredHandlerIDs: [String] {
        handlers.withLock { $0.map(\.id) }
    }

    // MARK: - Private

    private func dispatch(
        _ matching: [any SilentPushHandler],
        payload: [AnyHashable: Any],
        context: SilentPushContext
    ) async -> SilentPushResult {
        // payload is not Sendable but safe to read concurrently.
        nonisolated(unsafe) let unsafePayload = payload
        return await withTaskGroup(of: SilentPushResult.self) { group in
            for handler in matching {
                group.addTask {
                    await handler.handle(unsafePayload, context: context)
                }
            }

            var results: [SilentPushResult] = []
            for await result in group {
                results.append(result)
            }
            return Self.aggregate(results)
        }
    }

    private static func aggregate(_ results: [SilentPushResult]) -> SilentPushResult {
        if results.contains(.newData) { return .newData }
        if results.contains(.failed) { return .failed }
        return .noData
    }
}
