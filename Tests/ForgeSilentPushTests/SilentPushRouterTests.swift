import Testing
import Foundation
import Synchronization
import ForgeObservers
@testable import ForgeSilentPush

/// Tests `SilentPushRouter` registration, dispatch routing, and result aggregation.
///
/// We use the public `handlePush(payload:) async -> SilentPushResult` method throughout —
/// it takes a plain dictionary and returns the aggregated result, so no UIKit mocking is needed.
@Suite("SilentPushRouter")
struct SilentPushRouterTests {

    // MARK: - Registration

    @Test("Adding a handler stores it in the router")
    func addsHandler() {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(RecordingSilentHandler(id: "h1"))

        #expect(router.registeredHandlerIDs == ["h1"])
    }

    @Test("Duplicate handler ID is rejected")
    func rejectsDuplicates() {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(RecordingSilentHandler(id: "h1"))
        router.addHandler(RecordingSilentHandler(id: "h1"))

        #expect(router.registeredHandlerIDs.count == 1)
    }

    @Test("Removing a handler takes it out of the router")
    func removesHandler() {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(RecordingSilentHandler(id: "h1"))
        router.addHandler(RecordingSilentHandler(id: "h2"))
        router.removeHandler("h1")

        #expect(router.registeredHandlerIDs == ["h2"])
    }

    // MARK: - Dispatch

    @Test("handlePush returns noData when no handlers registered")
    func noHandlers() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )

        let result = await router.handlePush(payload: ["kind": "refresh"])
        #expect(result == .noData)
    }

    @Test("handlePush returns noData when no handlers match the payload")
    func noMatchingHandlers() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(RecordingSilentHandler(id: "refresher", matchKind: "refresh", result: .newData))

        let result = await router.handlePush(payload: ["kind": "other"])
        #expect(result == .noData)
    }

    @Test("handlePush dispatches to matching handler and returns its result")
    func singleMatchingHandler() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        let handler = RecordingSilentHandler(id: "refresher", matchKind: "refresh", result: .newData)
        router.addHandler(handler)

        let result = await router.handlePush(payload: ["kind": "refresh"])

        #expect(result == .newData)
        #expect(handler.invocationCount == 1)
    }

    @Test("handlePush dispatches to all matching handlers concurrently")
    func multipleMatchingHandlers() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        let a = RecordingSilentHandler(id: "a", matchKind: "sync", result: .newData)
        let b = RecordingSilentHandler(id: "b", matchKind: "sync", result: .noData)
        let c = RecordingSilentHandler(id: "c", matchKind: "other", result: .newData)
        router.addHandler(a)
        router.addHandler(b)
        router.addHandler(c)

        let result = await router.handlePush(payload: ["kind": "sync"])

        #expect(a.invocationCount == 1)
        #expect(b.invocationCount == 1)
        #expect(c.invocationCount == 0) // didn't match
        // a returned .newData, b returned .noData → most-optimistic aggregation wins
        #expect(result == .newData)
    }

    // MARK: - Result Aggregation

    @Test("Aggregation: newData beats failed and noData")
    func aggregationNewDataWins() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(RecordingSilentHandler(id: "a", matchKind: "x", result: .failed))
        router.addHandler(RecordingSilentHandler(id: "b", matchKind: "x", result: .noData))
        router.addHandler(RecordingSilentHandler(id: "c", matchKind: "x", result: .newData))

        let result = await router.handlePush(payload: ["kind": "x"])
        #expect(result == .newData)
    }

    @Test("Aggregation: failed beats noData when no newData present")
    func aggregationFailedOverNoData() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(RecordingSilentHandler(id: "a", matchKind: "x", result: .failed))
        router.addHandler(RecordingSilentHandler(id: "b", matchKind: "x", result: .noData))

        let result = await router.handlePush(payload: ["kind": "x"])
        #expect(result == .failed)
    }

    @Test("Aggregation: all noData yields noData")
    func aggregationAllNoData() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(),
            protectedData: StubProtectedData()
        )
        router.addHandler(RecordingSilentHandler(id: "a", matchKind: "x", result: .noData))
        router.addHandler(RecordingSilentHandler(id: "b", matchKind: "x", result: .noData))

        let result = await router.handlePush(payload: ["kind": "x"])
        #expect(result == .noData)
    }

    // MARK: - Context Propagation

    @Test("Handler receives context reflecting connectivity and protected data state")
    func contextReflectsState() async {
        let router = SilentPushRouter(
            connectivity: StubConnectivity(connected: true),
            protectedData: StubProtectedData(available: true)
        )
        let handler = RecordingSilentHandler(id: "ctx", matchKind: "x", result: .newData)
        router.addHandler(handler)

        _ = await router.handlePush(payload: ["kind": "x"])

        let context = handler.lastContext
        #expect(context?.connectivity.isConnected == true)
        #expect(context?.protectedDataAvailable == true)
    }
}

// MARK: - Mocks

/// Test handler implemented as a `@unchecked Sendable` final class so it can accept the
/// non-Sendable `[AnyHashable: Any]` payload that the protocol requires. Thread-safe via `Mutex`.
private final class RecordingSilentHandler: SilentPushHandler, @unchecked Sendable {
    let id: String
    let matchKind: String?
    let result: SilentPushResult

    private struct State {
        var invocationCount: Int = 0
        var lastContext: SilentPushContext?
    }
    private let state = Mutex<State>(State())

    init(id: String, matchKind: String? = nil, result: SilentPushResult = .noData) {
        self.id = id
        self.matchKind = matchKind
        self.result = result
    }

    var invocationCount: Int {
        state.withLock { $0.invocationCount }
    }

    var lastContext: SilentPushContext? {
        state.withLock { $0.lastContext }
    }

    func matchesPayload(_ payload: [AnyHashable: Any]) -> Bool {
        guard let matchKind else { return true }
        return (payload["kind"] as? String) == matchKind
    }

    func handle(_ payload: [AnyHashable: Any], context: SilentPushContext) async -> SilentPushResult {
        state.withLock { state in
            state.invocationCount += 1
            state.lastContext = context
        }
        return result
    }
}

private struct StubConnectivity: ConnectivityObserving {
    let connected: Bool
    init(connected: Bool = false) { self.connected = connected }

    var status: ConnectivityStatus {
        ConnectivityStatus(
            isConnected: connected,
            interface: connected ? .wifi : .none,
            isExpensive: false,
            isConstrained: false
        )
    }
    var statusStream: AsyncStream<ConnectivityStatus> {
        AsyncStream { continuation in continuation.finish() }
    }
}

private struct StubProtectedData: ProtectedDataObserving {
    let available: Bool
    init(available: Bool = false) { self.available = available }

    var state: ProtectedDataState { available ? .available : .unavailable }
    var stateStream: AsyncStream<ProtectedDataState> {
        AsyncStream { continuation in continuation.finish() }
    }
    func waitUntilAvailable() async {}
}
