import SwiftUI

@main
struct RentalComparisonApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.blue)
        }
    }
}
