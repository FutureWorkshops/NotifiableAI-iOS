import SwiftUI

@main
struct NotifiableAIApp: App {
    @StateObject private var harness = TestHarness()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(harness)
        }
    }
}
