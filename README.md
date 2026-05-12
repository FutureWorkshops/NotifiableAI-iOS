# NotifiableAI iOS

Swift client SDK and reference test app for the [NotifiableAI](https://github.com/futureworkshops/notifiable-rails) push notification server.

This repository contains two products:

- **NotifiableAIKit** — a small Swift Package that wraps the NotifiableAI server's device-write API (device registration, live activities). Distributable via Swift Package Manager.
- **NotifiableAI** — a SwiftUI multiplatform app (iOS / macOS / visionOS) that exercises every endpoint of the kit. Useful as a manual test harness during server development and as a worked example of the SDK in use.

## Requirements

- Xcode 16.3+
- iOS 17 / macOS 14 / visionOS 1 or later (package); iOS 26.2 (TestApp)
- Swift 6.0 toolchain

## Installation

Add NotifiableAIKit as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/futureworkshops/NotifiableAI-iOS.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "NotifiableAIKit", package: "NotifiableAI-iOS")
        ]
    )
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repo URL.

## Usage

The kit ships two surfaces. Most apps want the high-level `NotifiableAI`
namespace, which auto-fills `app_version` / `locale` from the bundle and
persists the returned `device_secret` to the keychain so you don't have to
think about it.

```swift
import NotifiableAIKit

// 1. Configure once at app startup. baseURL defaults to
//    https://notifiableai.fws.io — pass a custom URL for self-hosted
//    or staging servers.
NotifiableAI.configure(apiKey: "nfk_your_device_write_key")

// 2. Register from didRegisterForRemoteNotificationsWithDeviceToken.
func application(_ app: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    let hex = token.map { String(format: "%02x", $0) }.joined()
    Task { try? await NotifiableAI.register(pushToken: hex) }
}

// Later — update / unregister automatically reuse the stored device_secret.
try await NotifiableAI.update(pushToken: hex)
try await NotifiableAI.unregister(pushToken: hex)
```

`NotifiableAI.deviceSecret` and `NotifiableAI.deviceId` give read access to the
persisted state if you need it. Pass a custom `NotifiableAIStorage` to
`configure(... storage:)` to swap the keychain for something else.

`NotifiableAI.apnsEnvironment` returns `.development` / `.production` /
`.unknown` based on the embedded provisioning profile, so you can route
the push token to the matching APNs gateway server-side or surface it for
debugging. The `register` call sends this value in the `apns_environment`
field automatically — the server rejects mismatched (or missing) values
with a 422 to surface dev/prod build confusion at register time rather
than silently failing on the next push.

For runtime configuration switching (multi-environment debug tools, the bundled
TestApp, etc.) drop down to `NotifiableAIClient`:

```swift
let client = NotifiableAIClient(
    baseURL: URL(string: "https://staging.notifiable.example")!,
    deviceWriteKey: "nfk_..."
)
let device = try await client.registerDevice(pushToken: hex)
// Caller is responsible for persisting device.deviceSecret.
```

The kit only exposes device-write endpoints (the API key kind that's safe to
ship in a client). Server-trigger operations such as **sending notifications**
are intentionally out of scope — those belong in your backend, calling
NotifiableAI directly with a `server_trigger` key.

## Intelligence (on-device decisioning)

The kit ships a second top-level facade, `NotifiableIntelligence`, that runs
on-device agentic decisions over the user's preferences via Apple's Foundation
Models framework. Where the `NotifiableAI` facade decides _how_ a notification
reaches the device, `NotifiableIntelligence` decides _whether_ a candidate
alert is worth showing the user and how it should read.

```swift
import NotifiableAIKit

let engine = NotifiableIntelligence.Engine(
    store: NotifiableIntelligence.InMemoryPreferenceStore(),
    adapter: NotifiableIntelligence.FoundationModelAdapter()
)

let decision = try await engine.decide(
    domain: "demo.alerts",
    candidates: candidateEvents,
    schema: NotifiableIntelligence.AlertDecision.self
)

if decision.shouldAlert {
    // Surface the alert via your local notification path.
}
```

The Intelligence types require **iOS 18+**. Apple Foundation Models guided
generation requires **iOS 26+** at runtime; older OSes throw
`.foundationModelUnavailable`.

The bundled TestApp's Candidates tab exercises this flow end-to-end: author a
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

> Live Activities: ActivityKit sets the initial `ContentState` locally on the device. The server only stores the activity's metadata so it can be targeted for pushes — content updates are sent server→device via APNs.

Errors surface as `NotifiableAIError`:

- `.missingAPIKey(String)` — no key was provided
- `.http(status: Int, message: String?)` — non-2xx response
- `.decoding(Error)` — response body could not be decoded
- `.invalidResponse` — non-`HTTPURLResponse` reply

## Running the TestApp

```sh
git clone https://github.com/futureworkshops/NotifiableAI-iOS.git
cd NotifiableAI-iOS
open NotifiableAI.xcodeproj
```

Pick the **NotifiableAI** scheme and run on a real device (push registration won't work in the simulator). On first launch you'll get the iOS notification permission prompt; once granted, the **Push Token** field on the Settings tab is populated automatically.

Set the **Base URL** to your server, paste a `device_write` key, then tap **Register**. The Log tab shows the full request/response trail.

## Building

```sh
# Package only
cd NotifiableAIKit && swift build && swift test

# TestApp (replace the destination with one available on your machine)
xcodebuild -project NotifiableAI.xcodeproj -scheme NotifiableAI \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Repository layout

```
NotifiableAI-iOS/
├── NotifiableAIKit/           SwiftPM package (the SDK)
│   ├── Package.swift
│   ├── Sources/NotifiableAIKit/
│   └── Tests/NotifiableAIKitTests/
├── NotifiableAI/              TestApp (SwiftUI)
├── NotifiableAITests/
├── NotifiableAIUITests/
└── NotifiableAI.xcodeproj/
```

## Contributing

Issues and pull requests welcome. Run `swift test` in `NotifiableAIKit/` and the Xcode test suite for the app target before submitting.

## License

[MIT](LICENSE) © 2026 Future Workshops
