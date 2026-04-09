import Testing
import Foundation
import ForgePushToken

@Suite("PushTokenManager")
struct PushTokenManagerTests {

    // MARK: - Token Registration

    @Suite("Token Registration")
    struct TokenRegistration {

        @Test("Token is nil initially")
        func initiallyNil() {
            let manager = PushTokenManager()
            #expect(manager.token == nil)
        }

        @Test("Stores token as hex string after registration")
        func storesHexToken() {
            let manager = PushTokenManager()
            let tokenData = Data([0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89])

            manager.didRegister(deviceToken: tokenData)

            #expect(manager.token == "abcdef0123456789")
        }

        @Test("Updates token on subsequent registrations")
        func updatesToken() {
            let manager = PushTokenManager()
            let first = Data([0x01, 0x02])
            let second = Data([0x03, 0x04])

            manager.didRegister(deviceToken: first)
            #expect(manager.token == "0102")

            manager.didRegister(deviceToken: second)
            #expect(manager.token == "0304")
        }

        @Test("Clears token on failure")
        func clearsOnFailure() {
            let manager = PushTokenManager()
            manager.didRegister(deviceToken: Data([0xAA, 0xBB]))
            #expect(manager.token != nil)

            manager.didFailToRegister(error: TestError.failed)
            #expect(manager.token == nil)
        }

        @Test("Failure when already nil does not crash")
        func failureWhenAlreadyNil() {
            let manager = PushTokenManager()
            manager.didFailToRegister(error: TestError.failed)
            #expect(manager.token == nil)
        }

        @Test("Handles empty token data")
        func emptyTokenData() {
            let manager = PushTokenManager()
            manager.didRegister(deviceToken: Data())
            #expect(manager.token == "")
        }
    }

    // MARK: - Token Stream

    @Suite("Token Stream")
    struct TokenStream {

        @Test("Emits nil on subscription when no token")
        func emitsNilInitially() async {
            let manager = PushTokenManager()
            var iterator = manager.tokenStream.makeAsyncIterator()
            let first = await iterator.next()
            #expect(first == Optional<String>.none)
        }

        @Test("Emits current token on subscription")
        func emitsCurrentToken() async {
            let manager = PushTokenManager()
            manager.didRegister(deviceToken: Data([0xAA, 0xBB]))

            var iterator = manager.tokenStream.makeAsyncIterator()
            let first = await iterator.next()
            #expect(first == "aabb")
        }

        @Test("Emits new token after registration")
        func emitsOnRegistration() async {
            let manager = PushTokenManager()
            let collector = StreamCollector<String?>()

            let task = Task {
                for await value in manager.tokenStream {
                    await collector.append(value)
                    if await collector.count >= 2 { break }
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
            manager.didRegister(deviceToken: Data([0x01, 0x02]))
            try? await Task.sleep(for: .milliseconds(50))

            await task.value

            let values = await collector.values
            #expect(values == [nil, "0102"])
        }

        @Test("Emits nil on failure after having a token")
        func emitsNilOnFailure() async {
            let manager = PushTokenManager()
            manager.didRegister(deviceToken: Data([0xAA]))

            let collector = StreamCollector<String?>()

            let task = Task {
                for await value in manager.tokenStream {
                    await collector.append(value)
                    if await collector.count >= 2 { break }
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
            manager.didFailToRegister(error: TestError.failed)
            try? await Task.sleep(for: .milliseconds(50))

            await task.value

            let values = await collector.values
            #expect(values == ["aa", nil])
        }

        @Test("Does not emit on failure when token is already nil")
        func noEmitOnRedundantFailure() async {
            let manager = PushTokenManager()
            let collector = StreamCollector<String?>()

            let task = Task {
                for await value in manager.tokenStream {
                    await collector.append(value)
                    if await collector.count >= 1 {
                        // Give time for a potential redundant emission
                        try? await Task.sleep(for: .milliseconds(100))
                        break
                    }
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
            manager.didFailToRegister(error: TestError.failed)
            try? await Task.sleep(for: .milliseconds(50))

            await task.value

            let values = await collector.values
            // Only the initial nil from subscription, no redundant nil from failure
            #expect(values == [nil])
        }

        @Test("Multiple streams receive the same updates")
        func multipleStreams() async {
            let manager = PushTokenManager()
            let collector1 = StreamCollector<String?>()
            let collector2 = StreamCollector<String?>()

            let task1 = Task {
                for await value in manager.tokenStream {
                    await collector1.append(value)
                    if await collector1.count >= 2 { break }
                }
            }

            let task2 = Task {
                for await value in manager.tokenStream {
                    await collector2.append(value)
                    if await collector2.count >= 2 { break }
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
            manager.didRegister(deviceToken: Data([0xFF]))
            try? await Task.sleep(for: .milliseconds(50))

            await task1.value
            await task2.value

            let values1 = await collector1.values
            let values2 = await collector2.values
            #expect(values1 == [nil, "ff"])
            #expect(values2 == [nil, "ff"])
        }
    }

    // MARK: - Thread Safety

    @Suite("Thread Safety")
    struct ThreadSafety {

        @Test("Concurrent registrations do not crash")
        func concurrentRegistrations() async {
            let manager = PushTokenManager()

            await withTaskGroup(of: Void.self) { group in
                for i in 0..<100 {
                    group.addTask {
                        manager.didRegister(deviceToken: Data([UInt8(i % 256)]))
                    }
                }
            }

            #expect(manager.token != nil)
        }

        @Test("Concurrent stream subscriptions do not crash")
        func concurrentStreams() async {
            let manager = PushTokenManager()

            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<50 {
                    group.addTask {
                        var iterator = manager.tokenStream.makeAsyncIterator()
                        _ = await iterator.next()
                    }
                }
                for i in 0..<50 {
                    group.addTask {
                        manager.didRegister(deviceToken: Data([UInt8(i % 256)]))
                    }
                }
            }
        }

        @Test("Rapid subscribe/cancel churn does not accumulate continuations")
        func rapidSubscribeCancelChurn() async {
            let manager = PushTokenManager()

            // Churn: subscribe then immediately cancel, hundreds of times.
            // If continuations aren't cleaned up on termination, the internal map grows.
            // After all churn, a final subscriber should still receive updates normally.
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<300 {
                    group.addTask {
                        let task = Task {
                            var iterator = manager.tokenStream.makeAsyncIterator()
                            _ = await iterator.next()
                        }
                        task.cancel()
                        _ = await task.value
                    }
                }
            }

            // After churn, verify the manager is still fully functional.
            let collector = StreamCollector<String?>()
            let finalTask = Task {
                for await value in manager.tokenStream {
                    await collector.append(value)
                    if await collector.count >= 2 { break }
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
            manager.didRegister(deviceToken: Data([0x42]))
            try? await Task.sleep(for: .milliseconds(50))

            await finalTask.value
            let values = await collector.values
            #expect(values == [nil, "42"])
        }

        @Test("Cancellation while token is being updated does not deadlock")
        func cancelDuringTokenUpdate() async {
            let manager = PushTokenManager()

            await withTaskGroup(of: Void.self) { group in
                // Writer: continuously updates the token
                group.addTask {
                    for i in 0..<200 {
                        manager.didRegister(deviceToken: Data([UInt8(i % 256)]))
                    }
                }
                // Subscribers: subscribe and immediately cancel mid-flight
                for _ in 0..<100 {
                    group.addTask {
                        let task = Task {
                            for await _ in manager.tokenStream {
                                try? await Task.sleep(for: .milliseconds(1))
                            }
                        }
                        try? await Task.sleep(for: .milliseconds(5))
                        task.cancel()
                        _ = await task.value
                    }
                }
            }

            // Manager should still be usable post-churn.
            #expect(manager.token != nil)
        }
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case failed
}

private actor StreamCollector<T: Sendable> {
    private(set) var values: [T] = []

    var count: Int { values.count }

    func append(_ value: T) {
        values.append(value)
    }
}
