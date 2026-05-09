import SwiftUI

@main
struct NotifiableAIApp: App {
    @StateObject private var harness = TestHarness()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(harness)
        }
    }
}
