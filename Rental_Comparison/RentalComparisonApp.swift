import SwiftUI

@main
struct RentalComparisonApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, store.preferences.language.locale)
                .tint(.blue)
        }
    }
}
