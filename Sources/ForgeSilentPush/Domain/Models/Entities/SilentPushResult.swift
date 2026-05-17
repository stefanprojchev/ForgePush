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
