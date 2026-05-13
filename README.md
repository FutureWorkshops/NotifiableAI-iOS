# NotifiableAI iOS

Swift client SDK and reference demo app for the [NotifiableAI](https://github.com/futureworkshops/notifiable-rails) push notification server.

This repository contains two products:

- **NotifiableKit** — a small Swift Package that wraps the NotifiableAI server's
  device-write API (device registration, live activities) and adds an
  on-device decisioning layer via Apple Foundation Models. Distributable via
  Swift Package Manager.
- **NotifiableAI** (TestApp) — a SwiftUI iOS app that exercises every endpoint
  of the kit. Manual test harness during SDK development; worked example for
  integrators.

> **Note on the Xcode sidebar:** opening this repo as an Xcode workspace shows
> the demo target's files under "NotifiableKit local" in the Package
> Dependencies sidebar. That's how Xcode displays the package's containing
> directory — only files under `NotifiableKit/Sources/NotifiableKit/` are
> actually compiled into the SDK. SwiftPM consumers get the kit only; the
> demo app code never reaches their build.

## Requirements

- Xcode 16.3+
- iOS 18+ (kit) / iOS 26.2 (demo app)
- Foundation Models guided generation requires iOS 26 at runtime
- Swift 6.0 toolchain

## Installation

Add NotifiableKit as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/FutureWorkshops/NotifiableAI-iOS.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "NotifiableKit", package: "NotifiableAI-iOS")
        ]
    )
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repo URL.

## Usage

The kit ships two top-level facades:

| Facade | Purpose |
|---|---|
| `NotifiableRemote` | Register the device with the NotifiableAI server, send updates, register Live Activities. |
| `NotifiableDecide` | Decide on-device whether a candidate alert is worth showing the user and how it should read. |

### NotifiableRemote (push registration)

```swift
import NotifiableKit

// 1. Configure once at app startup. baseURL defaults to
//    https://notifiableai.fws.io — pass a custom URL for self-hosted
//    or staging servers.
NotifiableRemote.configure(apiKey: "nfk_your_device_write_key")

// 2. Register from didRegisterForRemoteNotificationsWithDeviceToken.
func application(_ app: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    let hex = token.map { String(format: "%02x", $0) }.joined()
    Task { try? await NotifiableRemote.register(pushToken: hex) }
}

// Later — update / unregister automatically reuse the stored device_secret.
try await NotifiableRemote.update(pushToken: hex)
try await NotifiableRemote.unregister(pushToken: hex)
```

`NotifiableRemote.deviceSecret` and `NotifiableRemote.deviceId` give read
access to the persisted state. Pass a custom `NotifiableRemoteStorage` to
`configure(... storage:)` to swap the keychain for something else.

`NotifiableRemote.apnsEnvironment` returns `.development` / `.production` /
`.unknown` based on the embedded provisioning profile, so you can route the
push token to the matching APNs gateway server-side or surface it for
debugging. The `register` call sends this value in the `apns_environment`
field automatically — the server rejects mismatched (or missing) values
with a 422 to surface dev/prod build confusion at register time rather than
silently failing on the next push.

For runtime configuration switching (multi-environment debug tools, the
bundled demo app, etc.) drop down to `NotifiableRemoteClient`:

```swift
let client = NotifiableRemoteClient(
    baseURL: URL(string: "https://staging.notifiable.example")!,
    deviceWriteKey: "nfk_..."
)
let device = try await client.registerDevice(pushToken: hex)
// Caller is responsible for persisting device.deviceSecret.
```

The kit only exposes device-write endpoints (the API key kind that's safe to
ship in a client). Server-trigger operations such as **sending notifications**
are intentionally out of scope — those belong in your backend, calling the
NotifiableAI server directly with a `server_trigger` key.

### NotifiableDecide (on-device decisioning)

Runs on-device agentic decisions over the user's preferences via Apple's
Foundation Models framework. Where `NotifiableRemote` decides _how_ a
notification reaches the device, `NotifiableDecide` decides _whether_ a
candidate alert is worth showing the user and how it should read.

```swift
import NotifiableKit

let engine = NotifiableDecide.Engine(
    store: NotifiableDecide.InMemoryPreferenceStore(),
    adapter: NotifiableDecide.FoundationModelAdapter()
)

let decision = try await engine.decide(
    domain: "demo.alerts",
    candidates: candidateEvents,
    schema: NotifiableDecide.AlertDecision.self
)

if decision.shouldAlert {
    // Surface the alert via your local notification path.
}
```

The demo app's Candidates tab exercises this flow end-to-end: author a
candidate event + a handful of preferences, tap Decide, and see the decoded
`AlertDecision` appear on the Log tab.

## API surface

| Method | Endpoint | Auth |
|---|---|---|
| `registerDevice` | `POST /api/v1/devices` | `device_write` |
| `updateDevice` | `PATCH /api/v1/devices/:push_token` | `device_write` + `X-Device-Secret` |
| `deleteDevice` | `DELETE /api/v1/devices/:push_token` | `device_write` + `X-Device-Secret` |
| `registerLiveActivity` | `POST /api/v1/live_activities` | `device_write` |
| `endLiveActivity` | `DELETE /api/v1/live_activities/:activity_id` | `device_write` + `X-Device-Secret` |

> Live Activities: ActivityKit sets the initial `ContentState` locally on the
> device. The server only stores the activity's metadata so it can be targeted
> for pushes — content updates are sent server→device via APNs.

Errors surface as `NotifiableRemoteError` (push) and
`NotifiableDecideError` (decisioning):

- `.missingAPIKey(String)` — no key was provided
- `.http(status: Int, message: String?)` — non-2xx response
- `.decoding(Error)` — response body could not be decoded
- `.invalidResponse` — non-`HTTPURLResponse` reply
- `.notConfigured` — `NotifiableRemote.configure(...)` not called
- `.deviceNotRegistered` — `update` / `unregister` called without a prior `register`
- `.foundationModelUnavailable` — Decide attempted on a device without Apple Intelligence
- `.decisionValidationFailed(reason:)` — model output didn't match the schema

## Running the demo app

```sh
git clone https://github.com/FutureWorkshops/NotifiableAI-iOS.git
cd NotifiableAI-iOS
open NotifiableAI.xcodeproj
```

Pick the **NotifiableAI** scheme and run on a real device (push registration
won't work in the simulator). On first launch you'll get the iOS notification
permission prompt; once granted, the **Push Token** field on the Settings tab
is populated automatically.

Set the **Base URL** to your server, paste a `device_write` key, then tap
**Register**. The Log tab shows the full request/response trail.

## Building

```sh
# Kit only
swift build && swift test

# Demo app for iOS Simulator (replace the destination as available)
xcodebuild -project NotifiableAI.xcodeproj -scheme NotifiableAI \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Repository layout

```
NotifiableAI-iOS/
├── Package.swift               SwiftPM manifest (kit only)
├── NotifiableKit/              Source root for the package
│   ├── Sources/NotifiableKit/
│   │   ├── Remote/             NotifiableRemote* push facade
│   │   └── Decide/             NotifiableDecide on-device decisioning
│   └── Tests/NotifiableKitTests/
├── NotifiableAI/               Demo app target (SwiftUI)
├── NotifiableAITests/
├── NotifiableAIUITests/
└── NotifiableAI.xcodeproj/
```

## Contributing

Issues and pull requests welcome. Run `swift test` and the Xcode test suite
for the app target before submitting.

## License

[MIT](LICENSE) © 2026 Future Workshops
