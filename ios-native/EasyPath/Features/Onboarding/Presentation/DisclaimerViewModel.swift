import Foundation

@Observable
@MainActor
final class DisclaimerViewModel {
    private(set) var hasAcknowledged: Bool
    private let store: DisclaimerAcknowledging

    init(store: DisclaimerAcknowledging) {
        self.store = store
        hasAcknowledged = store.hasAcknowledged()
    }

    func acknowledge() {
        store.acknowledge()
        hasAcknowledged = true
    }
}
