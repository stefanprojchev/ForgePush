import ForgeCore
import Foundation
import OSLog

/// Manages the device push notification token lifecycle.
///
/// Call `didRegister(deviceToken:)` and `didFailToRegister(error:)` from the
/// corresponding AppDelegate methods.
public final class PushTokenManager: Sendable {

    // MARK: - Properties

    private let logger = Logger(subsystem: "core.push", category: "token")

    private struct State: Sendable {
        var token: String?
        var continuations: [UUID: AsyncStream<String?>.Continuation] = [:]
    }

    private let state = LockedState(State())

    // MARK: - Initialization

    public init() {}

    // MARK: - Implementation

    /// The current device token as a hex string, or `nil` if not registered.
    public var token: String? {
        state.withLock { $0.token }
    }

    /// Stream of token changes. Emits current token on subscription.
    public var tokenStream: AsyncStream<String?> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { _ = $0.continuations.removeValue(forKey: id) }
            }

            let current = self.state.withLock { state -> String? in
                state.continuations[id] = continuation
                return state.token
            }
            continuation.yield(current)
        }
    }

    /// Call from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    public func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        logger.info("Device token registered: \(hex.prefix(8))...")

        let continuations = state.withLock { state -> [AsyncStream<String?>.Continuation] in
            state.token = hex
            return Array(state.continuations.values)
        }
        for continuation in continuations {
            continuation.yield(hex)
        }
    }

    /// Call from `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.
    public func didFailToRegister(error: Error) {
        logger.error("Failed to register for remote notifications: \(error.localizedDescription)")

        let continuations = state.withLock { state -> [AsyncStream<String?>.Continuation] in
            guard state.token != nil else { return [] }
            state.token = nil
            return Array(state.continuations.values)
        }
        for continuation in continuations {
            continuation.yield(nil)
        }
    }
}
