import SwiftData
import SwiftUI

@main
struct EasyPathApp: App {
    private let modelContainer: ModelContainer
    private let container: AppContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: TrackedPlaceEntity.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        container = AppContainer(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
