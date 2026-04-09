# ForgePush

Push notification management for iOS — permissions, tokens, and routing.

![Swift 6.3+](https://img.shields.io/badge/Swift-6.3+-orange.svg)
![iOS 18+](https://img.shields.io/badge/iOS-18+-blue.svg)
![macOS 15+](https://img.shields.io/badge/macOS-15+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)
[![Release](https://img.shields.io/github/v/release/stefanprojchev/ForgePush)](https://github.com/stefanprojchev/ForgePush/releases)

📖 **[Full documentation →](https://stefanprojchev.github.io/ForgePush/)**

---

ForgePush splits push notification handling into four focused libraries you can adopt individually. Drop in the ones you need, skip the ones you don't.

## Libraries

| Library | Purpose |
|---|---|
| **ForgePushPermission** | Request, check, and observe `UNUserNotificationCenter` authorization. |
| **ForgePushToken** | `PushTokenManager` bridges APNs delegate callbacks into an async token stream. |
| **ForgeSilentPush** | `SilentPushRouter` dispatches background pushes to handlers via `TaskGroup`. |
| **ForgeVisiblePush** | `VisiblePushRouter` dispatches tapped notifications to matching handlers. |
| **ForgePush** | Umbrella that re-exports all four. |

## Features

- **Handler-based routing** — define small, focused handlers; the router dispatches matching pushes to them concurrently
- **Result aggregation** — `SilentPushRouter` aggregates handler results using the most-optimistic policy (`.newData > .failed > .noData`)
- **Async token stream** — subscribe to `tokenStream` for the latest device token, no delegate callback wiring
- **Dependency-injected observers** — routers take `ConnectivityObserving` and `ProtectedDataObserving` as dependencies, so you can wire [ForgeObservers](https://github.com/stefanprojchev/ForgeObservers) or provide your own
- **Thread-safe** — `PushTokenManager` state is backed by `LockedState`; continuation lifecycle is deterministic

## Requirements

- **iOS** 18+
- **macOS** 15+
- **Swift** 6.3+ (Xcode 26 or later)

## Installation

### Xcode

1. **File → Add Package Dependencies…**
2. Paste `https://github.com/stefanprojchev/ForgePush.git`
3. Set rule to **Up to Next Major** from `1.0.0`

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/stefanprojchev/ForgePush.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            // All four libraries
            "ForgePushPermission",
            "ForgePushToken",
            "ForgeSilentPush",
            "ForgeVisiblePush",
            // — or only what you need —
        ]
    )
]
```

## Quick Start

### Request permission

```swift
import ForgePushPermission

let permission = PushPermission()
let granted = try await permission.request()
if granted {
    await UIApplication.shared.registerForRemoteNotifications()
}
```

### Observe the APNs token

```swift
import ForgePushToken

let tokenManager = PushTokenManager()

// In AppDelegate:
func application(_ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    tokenManager.didRegister(deviceToken: token)
}

// Anywhere:
Task {
    for await token in tokenManager.tokenStream {
        guard let token else { continue }
        await uploadTokenToServer(token)
    }
}
```

### Route silent pushes

```swift
import ForgeSilentPush

struct SyncHandler: SilentPushHandler {
    let id = "sync"

    func matchesPayload(_ payload: [AnyHashable: Any]) -> Bool {
        (payload["kind"] as? String) == "sync"
    }

    func handle(_ payload: [AnyHashable: Any], context: SilentPushContext) async -> SilentPushResult {
        guard context.connectivity.isConnected else { return .noData }
        let newItems = try? await syncService.fetchNew()
        return (newItems?.isEmpty == false) ? .newData : .noData
    }
}

let router = SilentPushRouter(
    connectivity: ConnectivityObserver(),
    protectedData: ProtectedDataObserver()
)
router.addHandler(SyncHandler())

// In AppDelegate:
func application(
    _ app: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    router.handlePush(payload: userInfo, completionHandler: completionHandler)
}
```

### Route tapped notifications

```swift
import ForgeVisiblePush

struct DeepLinkHandler: VisiblePushHandler {
    let id = "deep-link"

    func matches(_ response: UNNotificationResponse) -> Bool {
        response.notification.request.content.userInfo["link"] != nil
    }

    func handle(_ response: UNNotificationResponse, context: VisiblePushContext) async {
        if let url = response.notification.request.content.userInfo["link"] as? String {
            await Router.shared.open(url)
        }
    }
}

let router = VisiblePushRouter(
    connectivity: ConnectivityObserver(),
    protectedData: ProtectedDataObserver()
)
router.addHandler(DeepLinkHandler())

// In UNUserNotificationCenterDelegate:
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    router.handleResponse(response, completionHandler: completionHandler)
}
```

## Documentation

- **[Getting Started](https://stefanprojchev.github.io/ForgePush/docs/getting-started/)**
- **[Permission](https://stefanprojchev.github.io/ForgePush/docs/permission/)** · **[Token](https://stefanprojchev.github.io/ForgePush/docs/token/)** · **[Silent Push](https://stefanprojchev.github.io/ForgePush/docs/silent-push/)** · **[Visible Push](https://stefanprojchev.github.io/ForgePush/docs/visible-push/)**

## The Forge Family

ForgePush is part of the **Forge** family of Swift packages for iOS.

| Package | Description |
|---|---|
| [ForgeCore](https://github.com/stefanprojchev/ForgeCore) | Thread-safe primitives for iOS Swift packages. |
| [ForgeInject](https://github.com/stefanprojchev/ForgeInject) | Dependency injection with constructor and property wrapper support. |
| [ForgeObservers](https://github.com/stefanprojchev/ForgeObservers) | Reactive system observers — connectivity, lifecycle, keyboard, and more. |
| [ForgeStorage](https://github.com/stefanprojchev/ForgeStorage) | Type-safe key-value, file, and Keychain storage. |
| [ForgeOrchestrator](https://github.com/stefanprojchev/ForgeOrchestrator) | Orchestrate app flows — startup gates, data pipelines, and continuous monitors. |
| **ForgePush** | Push notification management — permissions, tokens, and routing. |
| [ForgeLocation](https://github.com/stefanprojchev/ForgeLocation) | Location triggers — geofencing, significant changes, and visits. |
| [ForgeBackgroundTasks](https://github.com/stefanprojchev/ForgeBackgroundTasks) | Background task scheduling and dispatch. |

## License

ForgePush is released under the MIT License. See [LICENSE](LICENSE).
