import Testing
import Foundation
import UserNotifications
import ForgeObservers
@testable import ForgeVisiblePush

/// Tests `VisiblePushRouter` registration and removal.
///
/// Note: Dispatch-routing tests are omitted because `UNNotificationResponse` cannot be safely
/// constructed in a unit-test environment — it has no public init and archiver hacks are fragile.
/// The registration/removal tests and the "no handlers" path don't require a real response.
@Suite("VisiblePushRouter")
struct VisiblePushRouterTests {

    // MARK: - Registration

    @Test("Adding a handler stores it in the router")
    func addsHandler() {
        let router = VisiblePushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(StubVisibleHandler(id: "h1"))

        #expect(router.registeredHandlerIDs == ["h1"])
    }

    @Test("Duplicate handler ID is rejected")
    func rejectsDuplicates() {
        let router = VisiblePushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(StubVisibleHandler(id: "h1"))
        router.addHandler(StubVisibleHandler(id: "h1"))

        #expect(router.registeredHandlerIDs.count == 1)
    }

    @Test("Adding multiple distinct handlers preserves insertion order")
    func preservesOrder() {
        let router = VisiblePushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(StubVisibleHandler(id: "first"))
        router.addHandler(StubVisibleHandler(id: "second"))
        router.addHandler(StubVisibleHandler(id: "third"))

        #expect(router.registeredHandlerIDs == ["first", "second", "third"])
    }

    @Test("Removing a handler takes it out of the router")
    func removesHandler() {
        let router = VisiblePushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(StubVisibleHandler(id: "h1"))
        router.addHandler(StubVisibleHandler(id: "h2"))
        router.removeHandler("h1")

        #expect(router.registeredHandlerIDs == ["h2"])
    }

    @Test("Removing a non-existent handler is a no-op")
    func removesMissing() {
        let router = VisiblePushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(StubVisibleHandler(id: "h1"))
        router.removeHandler("nonexistent")

        #expect(router.registeredHandlerIDs == ["h1"])
    }

    // MARK: - Concurrency

    @Test("Concurrent additions preserve all unique handlers")
    func concurrentAdditions() async {
        let router = VisiblePushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    router.addHandler(StubVisibleHandler(id: "handler-\(i)"))
                }
            }
        }

        #expect(router.registeredHandlerIDs.count == 100)
    }

    @Test("Concurrent duplicate additions converge to a single entry")
    func concurrentDuplicates() async {
        let router = VisiblePushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    router.addHandler(StubVisibleHandler(id: "shared"))
                }
            }
        }

        #expect(router.registeredHandlerIDs.count == 1)
    }
}

// MARK: - Mocks

private struct StubVisibleHandler: VisiblePushHandler {
    let id: String

    func matches(_ response: UNNotificationResponse) -> Bool { true }

    func handle(_ response: UNNotificationResponse, context: VisiblePushContext) async {
        // No-op
    }
}

private struct StubConnectivity: ConnectivityObserving {
    var status: ConnectivityStatus {
        ConnectivityStatus(isConnected: false, interface: .none, isExpensive: false, isConstrained: false)
    }
    var statusStream: AsyncStream<ConnectivityStatus> {
        AsyncStream { continuation in continuation.finish() }
    }
}

private struct StubProtectedData: ProtectedDataObserving {
    var state: ProtectedDataState { .unavailable }
    var stateStream: AsyncStream<ProtectedDataState> {
        AsyncStream { continuation in continuation.finish() }
    }
    func waitUntilAvailable() async {}
}
