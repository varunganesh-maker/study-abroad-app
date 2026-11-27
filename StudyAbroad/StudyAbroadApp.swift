import SwiftUI

@main
struct StudyAbroadApp: App {
    @State private var store = MemoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
