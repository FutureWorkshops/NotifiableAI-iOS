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

```swift
import NotifiableAIKit

let client = NotifiableAIClient(
    baseURL: URL(string: "https://your-notifiable-server.example.com")!,
    deviceWriteKey: "nfk_your_device_write_api_key"
)

// Register the device for push.
let device = try await client.registerDevice(
    pushToken: apnsTokenHex,
    pushType: .alert,
    appVersion: "1.0.0",
    locale: Locale.current.identifier
)

// Persist `device.deviceSecret` — it is required for subsequent update/delete
// calls and is only returned on the initial register response.

// Update later.
_ = try await client.updateDevice(
    pushToken: apnsTokenHex,
    deviceSecret: storedDeviceSecret,
    appVersion: "1.0.1"
)

// Tear down.
try await client.deleteDevice(pushToken: apnsTokenHex, deviceSecret: storedDeviceSecret)
```

The kit only exposes device-write endpoints (the API key kind that's safe to ship in a client). Server-trigger operations such as **sending notifications** are intentionally out of scope — those belong in your backend, calling NotifiableAI directly with a `server_trigger` key.

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
