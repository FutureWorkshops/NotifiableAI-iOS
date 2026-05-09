import SwiftUI

@main
struct NotifiableAIApp: App {
    @StateObject private var harness = TestHarness()

    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(harness)
        }
    }
}
