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
