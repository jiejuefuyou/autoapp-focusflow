import SwiftUI

@main
struct FocusFlowApp: App {
    @State private var iap = IAPManager()
    @State private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(iap)
                .environment(store)
                .task { await iap.refresh() }
        }
    }
}
