import ForgeObservers

/// Runtime context provided to visible push handlers.
public struct VisiblePushContext: Sendable {

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
