import ForgeCore
import ForgeObservers
import OSLog
import UserNotifications

/// Routes tapped push notifications to registered handlers concurrently.
public final class VisiblePushRouter: Sendable {

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "core.push", category: "visible")
    private let handlers = LockedState<[any VisiblePushHandler]>([])
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

    /// Registers a handler for visible push notifications.
    public func addHandler(_ handler: any VisiblePushHandler) {
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

    /// Routes a notification response to matching handlers and calls the completion handler.
    ///
    /// Call from `userNotificationCenter(_:didReceive:completionHandler:)`.
    public func handleResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        let matching = handlers.withLock {
            $0.filter { $0.matches(response) }
        }

        guard !matching.isEmpty else {
            logger.debug("No handlers matched response")
            completionHandler()
            return
        }

        logger.info("Response matched \(matching.count) handler(s): \(matching.map(\.id).joined(separator: ", "))")

        let context = VisiblePushContext(
            connectivity: connectivity.status,
            protectedDataAvailable: protectedData.state == .available
        )

        // UNNotificationResponse is not Sendable but safe to pass across tasks.
        nonisolated(unsafe) let unsafeResponse = response
        nonisolated(unsafe) let unsafeMatching = matching
        Task {
            await dispatch(unsafeMatching, response: unsafeResponse, context: context)
            completionHandler()
        }
    }

    /// Async variant of `handleResponse(_:completionHandler:)`.
    public func handleResponse(_ response: UNNotificationResponse) async {
        let matching = handlers.withLock {
            $0.filter { $0.matches(response) }
        }

        guard !matching.isEmpty else {
            logger.debug("No handlers matched response")
            return
        }

        logger.info("Response matched \(matching.count) handler(s)")

        let context = VisiblePushContext(
            connectivity: connectivity.status,
            protectedDataAvailable: protectedData.state == .available
        )

        await dispatch(matching, response: response, context: context)
    }

    /// IDs of all currently-registered handlers. Used by tests to verify registration state.
    internal var registeredHandlerIDs: [String] {
        handlers.withLock { $0.map(\.id) }
    }

    // MARK: - Private

    private func dispatch(
        _ matching: [any VisiblePushHandler],
        response: UNNotificationResponse,
        context: VisiblePushContext
    ) async {
        nonisolated(unsafe) let unsafeResponse = response
        await withTaskGroup(of: Void.self) { group in
            for handler in matching {
                group.addTask {
                    await handler.handle(unsafeResponse, context: context)
                }
            }
        }
    }
}
