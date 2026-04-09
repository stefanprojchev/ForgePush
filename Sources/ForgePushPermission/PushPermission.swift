#if canImport(UIKit)
import UIKit
import UserNotifications

/// Standalone push notification permission management.
///
/// Wraps `UNUserNotificationCenter` for requesting and checking authorization.
/// No observation — use ForgeObservers for status tracking.
public struct PushPermission: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Implementation

    /// Requests push notification authorization.
    /// - Parameter options: Authorization options. Defaults to alert, badge, and sound.
    /// - Returns: Whether the user granted permission.
    @discardableResult
    public func request(
        _ options: UNAuthorizationOptions = [.alert, .badge, .sound]
    ) async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: options)
    }

    /// Returns the current authorization status.
    public func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
    }

    /// Opens the app's notification settings in Settings.app.
    @MainActor
    public func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
