# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Monorepo for two related products, in priority order:

1. **NotifiableKit** — a Swift Package (iOS / macOS / visionOS) that other
   apps consume via SwiftPM. Two top-level facades:
   - `NotifiableRemote` — wraps the NotifiableRemote Rails server's
     `/api/v1/*` device-write endpoints (register / update / delete device,
     register / end Live Activity). Auto-fills `app_version` + `locale`,
     persists `device_secret` + `device_id` to the keychain, and detects the
     APNs environment from the embedded provisioning profile.
   - `NotifiableDecide` — on-device agentic decisioning over user
     preferences via Apple Foundation Models. `Engine.decide` pulls prefs +
     recent alerts, assembles a structured XML context block, calls the LLM,
     validates the decoded result, and records the alert.
2. **NotifiableRemote** (TestApp) — a SwiftUI iOS-only harness that exercises
   every kit endpoint through three tabs (Settings / Candidates / Log). Used
   for manual testing during kit development; not for shipping.

The Rails server lives in a sibling repo at `../Notifiable-Rails`. Server
contract changes land there first; the iOS side is updated to match in a
follow-up commit (recent examples: `apns_environment` required on register,
`content_state` dropped from Live Activity register).

- Xcode project: `NotifiableRemote.xcodeproj` (consumes the local package at
  `./NotifiableKit` via `XCLocalSwiftPackageReference`).
- Package manifest: `NotifiableKit/Package.swift`. Floor: iOS 18 (the Decide
  types require it). Foundation Models guided generation requires iOS 26 at
  runtime — older OSes throw `.foundationModelUnavailable`.
- App deployment target: iOS 26.2. App is `iphoneos iphonesimulator` only;
  the package itself still supports iOS / macOS / visionOS for SDK consumers.
- Swift 6 strict concurrency throughout.
- Test framework: Swift Testing (`import Testing`, `@Test`, `@Suite`).
- No linter, formatter, or CI configured.

## NotifiableKit API surface

### `NotifiableRemote` facade (push registration)

Mirrors `app/controllers/api/v1/*` in the Rails repo:

- `NotifiableRemote.configure(baseURL:apiKey:storage:session:bundle:)` — call once
  at app startup. `baseURL` defaults to `NotifiableRemote.defaultBaseURL` (the
  production server). `storage` defaults to `KeychainStorage`; supply a
  custom `NotifiableRemoteStorage` (e.g. `InMemoryStorage` for tests) to swap it.
- `NotifiableRemote.register / update / unregister` — auto-fill `app_version` +
  `locale`, persist `device_secret` + `device_id` to storage, and forward
  `NotifiableRemote.apnsEnvironment` to the server's `apns_environment` field
  (required on iOS since Rails commit f630152).
- `NotifiableRemote.registerLiveActivity / endLiveActivity` — same auth model.
  Server does **not** accept content state at register time (ActivityKit sets
  it locally; updates flow server→device via APNs).
- `NotifiableRemote.apnsEnvironment` — `.development` / `.production` / `.unknown`,
  parsed from `embedded.mobileprovision` at runtime. Drives correct routing
  server-side; surface it on debug screens so dev/prod build confusion is
  visible.
- Errors: `NotifiableRemoteError` (`.missingAPIKey`, `.http(status:message:)`,
  `.decoding`, `.invalidResponse`, `.notConfigured`, `.deviceNotRegistered`).

Lower-level `NotifiableRemoteClient` is also public for runtime config switching
(multi-environment debug tools, the TestApp itself).

### `NotifiableDecide` facade (on-device decisioning)

- `NotifiableDecide.Engine.decide(domain:candidates:schema:options:)` —
  pull preferences + recent alerts for the domain, assemble a structured XML
  context, call the on-device LLM, validate the decoded result, enforce a
  120s hard suppression rail keyed on `(domain, subject)`, and record the
  alert on positive non-suppressed decisions.
- Supporting types: `CandidateEvent` (+ `AttributeValue`), `AlertDecision`,
  `Preference` (+ `PreferenceValue`, `Confidence`), `RecordedAlert`,
  `PreferenceStore` (+ `InMemoryPreferenceStore` and
  `SwiftDataPreferenceStore`), `ModelAdapter` (+ `FoundationModelAdapter`),
  `DecideOptions`.
- Errors: `NotifiableDecideError` (`.foundationModelUnavailable`,
  `.decisionValidationFailed`, `.tokenBudgetExceeded`, `.storeUnavailable`).
- Internal: `ContextAssembler` (snapshot-testable, pure given inputs),
  `XMLEscaper` (escapes user strings + strips C0 controls), `Tokenizer`
  (`chars / 4`), `SystemPrompts`. `OSLog` subsystem
  `com.futureworkshops.notifiable.decide`, category `decide`.
- **JSON schema hint**: `Engine.decide` appends a `<response_shape>` block
  describing the expected JSON keys when `Schema is AlertDecision.Type`.
  Without this the model invents its own key names and decoding fails — the
  schema isn't introspectable from a plain `Codable`. Kept out of the
  `ContextAssembler` so its snapshot tests stay deterministic.
- **JSON decoder tolerance**: `FoundationModelAdapter.decodeJSON` strips
  markdown fences and narrows to the outermost `{…}` block before decoding,
  so model preambles / postscripts don't cause `.decisionValidationFailed`.

## Layout quirks

- The app target uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so
  adding/removing Swift files in `NotifiableRemote/` does not require pbxproj
  edits.
- **`NotifiableRemote-Info.plist` lives at the repo root, NOT inside `NotifiableRemote/`.**
  Putting it in the synchronized group caused Xcode to double-process it as
  both `INFOPLIST_FILE` and a copied resource. Keep new resource files inside
  the synchronized group; keep the Info.plist out.
- App icons live in `Assets.xcassets/AppIcon.appiconset/`; the asset catalog
  references PNGs by filename and `INFOPLIST_KEY_CFBundleIconName` is set via
  the Info.plist (top-level, not nested under `CFBundleIcons` — App Store
  Connect requires both, ITMS-90713).
- Entitlements at `NotifiableRemote/NotifiableRemote.entitlements` request
  `aps-environment = production`. Apple Development provisioning profiles
  downgrade this to `development` at sign time for local installs; archives
  for TestFlight / App Store ship with `production`.

## Commands

```sh
# Kit: build/test
cd NotifiableKit && swift build && swift test
swift test --filter SuppressionTests              # one suite
swift test --filter contextBlockContainsCandidateId  # one test

# TestApp: build for iOS Simulator (any available device)
xcodebuild -project NotifiableRemote.xcodeproj -scheme NotifiableRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# TestApp: run unit + UI tests
xcodebuild -project NotifiableRemote.xcodeproj -scheme NotifiableRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# TestApp: one test by name
xcodebuild ... test -only-testing:NotifiableRemoteTests/NotifiableRemoteTests/pushTokenFormatterProducesLowerHex

# TestApp: build & install on the physical device "Matt iPhone 16 Pro Max II"
xcodebuild -project NotifiableRemote.xcodeproj -scheme NotifiableRemote \
  -destination 'platform=iOS,id=00008140-00046C481813C01C' \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008140-00046C481813C01C \
  ~/Library/Developer/Xcode/DerivedData/NotifiableRemote-*/Build/Products/Debug-iphoneos/NotifiableRemote.app
```

If the iPhone is unreachable the device build will hang on the destination
lookup — fall back to the simulator build, report, and continue.
