# ForgePush

Push notification management for iOS — permissions, tokens, silent and visible push routing.

## Requirements

- iOS 16+
- Swift 6.0+

## Installation

### Swift Package Manager

Add ForgePush to your project via Xcode:

1. **File > Add Package Dependencies...**
2. Enter the repository URL
3. Select the version rule and add to your target

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stefanprojchev/ForgePush.git", from: "1.0.0")
]
```

Import everything with `ForgePush`, or pick individual modules:

```swift
import ForgePush          // all modules
import ForgePushPermission // just permission
import ForgePushToken      // just token management
import ForgeSilentPush     // just silent push routing
import ForgeVisiblePush    // just visible push routing
```

## Quick Start

```swift
import ForgePush

// Request permission
let permission = PushPermission()
let granted = try await permission.request()

// Register for remote notifications
let tokenManager = PushTokenManager()
await tokenManager.registerForRemoteNotifications()

// Route silent pushes
let silentRouter = SilentPushRouter(
    connectivity: connectivityObserver,
    protectedData: protectedDataObserver
)
silentRouter.addHandler(DataSyncHandler())

// Route tapped notifications
let visibleRouter = VisiblePushRouter(
    connectivity: connectivityObserver,
    protectedData: protectedDataObserver
)
visibleRouter.addHandler(DeepLinkHandler())
```

## ForgePushPermission

Wraps `UNUserNotificationCenter` for requesting and checking authorization:

```swift
let permission = PushPermission()

// Request (defaults to alert, badge, sound)
let granted = try await permission.request()
let granted = try await permission.request([.alert, .sound, .criticalAlert])

// Check current status
let status = await permission.status() // .authorized, .denied, .notDetermined, ...

// Open Settings.app notification page
await permission.openSettings()
```

## ForgePushToken

Manages the device push token lifecycle. Provides the current token as a hex string and an `AsyncStream` for changes:

```swift
let tokenManager = PushTokenManager()
await tokenManager.registerForRemoteNotifications()

// Current token
if let token = tokenManager.token {
    await sendToServer(token)
}

// Stream token changes
for await token in tokenManager.tokenStream {
    if let token {
        await sendToServer(token)
    }
}
```

Wire up the AppDelegate callbacks:

```swift
func application(_ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    tokenManager.didRegister(deviceToken: token)
}

func application(_ app: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    tokenManager.didFailToRegister(error: error)
}
```

## ForgeSilentPush

Routes silent push notifications to registered handlers concurrently. Each handler declares which payloads it matches and returns a `SilentPushResult` (`.newData`, `.noData`, `.failed`). The router aggregates results — most optimistic wins.

```swift
struct DataSyncHandler: SilentPushHandler {
    let id = "sync.data"

    func matchesPayload(_ payload: [AnyHashable: Any]) -> Bool {
        payload["type"] as? String == "sync"
    }

    func handle(_ payload: [AnyHashable: Any], context: SilentPushContext) async -> SilentPushResult {
        guard context.connectivity.isConnected else { return .failed }
        await performSync()
        return .newData
    }
}

// In AppDelegate
func application(_ app: UIApplication, didReceiveRemoteNotification payload: [AnyHashable: Any],
                 fetchCompletionHandler handler: @escaping (UIBackgroundFetchResult) -> Void) {
    silentRouter.handlePush(payload: payload, completionHandler: handler)
}
```

## ForgeVisiblePush

Routes tapped push notifications to registered handlers concurrently:

```swift
struct DeepLinkHandler: VisiblePushHandler {
    let id = "deeplink"

    func matches(_ response: UNNotificationResponse) -> Bool {
        response.notification.request.content.userInfo["deeplink"] != nil
    }

    func handle(_ response: UNNotificationResponse, context: VisiblePushContext) async {
        let link = response.notification.request.content.userInfo["deeplink"] as! String
        await navigate(to: link)
    }
}

// In UNUserNotificationCenterDelegate
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                            withCompletionHandler handler: @escaping () -> Void) {
    visibleRouter.handleResponse(response, completionHandler: handler)
}
```

## Thread Safety

All types are `Sendable`. `PushTokenManager` protects state with `LockedState`. `SilentPushRouter` and `VisiblePushRouter` protect handler lists with `LockedState` and dispatch work via `TaskGroup`. `PushPermission` is a stateless struct.

## Forge Ecosystem

ForgePush is part of the **Forge** family of Swift packages for iOS:

| Package | Description |
|---------|-------------|
| [ForgeCore](https://github.com/stefanprojchev/ForgeCore) | Thread-safe utilities — `LockedState` and `SendableFileManager` |
| [ForgeInject](https://github.com/stefanprojchev/ForgeInject) | Lightweight dependency injection with property wrapper |
| [ForgeObservers](https://github.com/stefanprojchev/ForgeObservers) | Reactive system observers (connectivity, lifecycle, keyboard, and more) |
| [ForgeStorage](https://github.com/stefanprojchev/ForgeStorage) | Type-safe persistence — key-value, file storage, and Keychain |
| [ForgeBackgroundTasks](https://github.com/stefanprojchev/ForgeBackgroundTasks) | BGTaskScheduler registration, scheduling, and dispatch |
| [ForgeLocation](https://github.com/stefanprojchev/ForgeLocation) | Location-based triggers — geofencing, significant changes, visits |
| **ForgePush** | Push notification management — permissions, tokens, silent and visible routing |
| [ForgeOrchestrator](https://github.com/stefanprojchev/ForgeOrchestrator) | Sequence, pipeline, and monitor orchestrators for iOS app flows |

## License

MIT License. See [LICENSE](LICENSE) for details.
