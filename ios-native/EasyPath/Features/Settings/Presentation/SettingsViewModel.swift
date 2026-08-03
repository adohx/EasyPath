import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var settings: AppSettings {
        didSet { store.save(settings) }
    }

    private let store: AppSettingsStoring

    init(store: AppSettingsStoring) {
        self.store = store
        settings = store.load()
    }
}
