#if canImport(UIKit)
import UIKit

extension PushTokenManager {
    /// Triggers `UIApplication.shared.registerForRemoteNotifications()`.
    @MainActor
    public func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
#endif
