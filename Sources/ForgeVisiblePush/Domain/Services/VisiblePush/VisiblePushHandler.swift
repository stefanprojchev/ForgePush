import Foundation
import UserNotifications

/// A handler for tapped/actioned push notifications.
///
/// The router matches notification responses via `matches`, dispatches
/// matching handlers concurrently via `TaskGroup`.
public protocol VisiblePushHandler: Sendable {
    /// Unique identifier for this handler. Used for logging and deduplication.
    var id: String { get }

    /// Returns `true` if this handler should process the notification response.
    func matches(_ response: UNNotificationResponse) -> Bool

    /// Handles the tapped notification.
    /// - Parameters:
    ///   - response: The notification response from the user interaction.
    ///   - context: Runtime context with connectivity and protected data status.
    func handle(_ response: UNNotificationResponse, context: VisiblePushContext) async
}
