# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

This repo contains two related products in a monorepo:

1. **NotifiableAIKit** — a Swift Package (iOS / macOS / visionOS) that wraps the
   NotifiableAI Rails server's `/api/v1/*` endpoints. Distributable via SwiftPM.
2. **NotifiableAI** — a SwiftUI iOS-only "TestApp" that depends on
   NotifiableAIKit via a local SwiftPM reference and exposes every server endpoint
   through buttons / text fields with a scrolling log.

The Rails server lives in a sibling repo at `../Notifiable-Rails`.

- Xcode project: `NotifiableAI.xcodeproj` (consumes the local package at `./NotifiableAIKit`).
- Package manifest: `NotifiableAIKit/Package.swift`.
- Deployment target: iOS 26.2 / iOS 17 (package), Swift 5.0 (app), 6.0 (package).
- App supported platforms: `iphoneos iphonesimulator`; device family `1,2`. The package still supports iOS / macOS / visionOS for SDK consumers.
- Test framework: Swift Testing (`import Testing`, `@Test`).

## Layout

```
NotifiableAI-iOS/
├── NotifiableAIKit/                       # SwiftPM package (the framework)
│   ├── Package.swift
│   ├── Sources/NotifiableAIKit/
│   │   ├── NotifiableAIClient.swift       # async/await API client
│   │   └── Models.swift                 # DTOs, errors, audience/options
│   └── Tests/NotifiableAIKitTests/
├── NotifiableAI/                        # TestApp (SwiftUI)
│   ├── NotifiableAIApp.swift
│   ├── ContentView.swift                # Form-based UI for every endpoint
│   └── TestHarness.swift                # @MainActor ObservableObject driving requests + log
├── NotifiableAITests/
├── NotifiableAIUITests/
└── NotifiableAI.xcodeproj/
```

The app target uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so
adding/removing Swift files in `NotifiableAI/` does not require pbxproj edits.
The local package is wired via `XCLocalSwiftPackageReference` →
`relativePath = NotifiableAIKit` and `XCSwiftPackageProductDependency` linked into
the app target's Frameworks build phase.

## NotifiableAIKit API surface

Mirrors `app/controllers/api/v1/*` in the Rails repo:

- `NotifiableAIClient.registerDevice / updateDevice / deleteDevice`
  — `device_write` API key + `X-Device-Secret` header on update/delete.
- `NotifiableAIClient.registerLiveActivity / endLiveActivity`
  — same auth model. `registerDevice` and `registerLiveActivity` return a one-time
  `device_secret` that the caller must persist. Live Activity register does
  NOT accept content state — ActivityKit sets that locally.

All errors surface as `NotifiableAIError` (`.missingAPIKey`, `.http(status:message:)`,
`.decoding`, `.invalidResponse`).

### NotifiableIntelligence (on-device decisioning)

Second top-level facade, parallel to `NotifiableAI`:

- `NotifiableIntelligence.Engine.decide(domain:candidates:schema:options:)` —
  pull preferences + recent alert history for the domain, assemble a
  structured XML context block, call the on-device Foundation Models LLM,
  validate against the supplied schema, enforce a 120s hard suppression rail,
  and (on positive decision) record the alert.
- Supporting nested types: `CandidateEvent`, `AlertDecision`, `Preference`,
  `RecordedAlert`, `PreferenceStore` (+ `InMemoryPreferenceStore` and
  `SwiftDataPreferenceStore`), `ModelAdapter` (+ `FoundationModelAdapter`),
  `DecideOptions`.
- Errors are `NotifiableIntelligenceError` (`.foundationModelUnavailable`,
  `.decisionValidationFailed`, `.tokenBudgetExceeded`, `.storeUnavailable`).
- Internal: `ContextAssembler`, `XMLEscaper`, `Tokenizer`, `SystemPrompts`.
  `OSLog` subsystem `com.futureworkshops.notifiable-ai.intelligence`,
  category `decide`.

Package floor is iOS 18 to support the Intelligence types; Foundation Models
guided generation requires iOS 26 at runtime.

## Commands

```sh
# Build/test the package directly
cd NotifiableAIKit && swift build && swift test

# Build the TestApp for an iOS simulator (replace device as available)
xcodebuild -project NotifiableAI.xcodeproj -scheme NotifiableAI \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run app-level tests
xcodebuild -project NotifiableAI.xcodeproj -scheme NotifiableAI \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

There is no linter, formatter, or CI configured in this repo.
